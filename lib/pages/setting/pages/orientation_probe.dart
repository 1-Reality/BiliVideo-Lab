import 'dart:async' show StreamSubscription, unawaited;
import 'dart:io' show Platform;

import 'package:PiliBro/plugin/pl_player/utils/orientation_platform.dart';
import 'package:PiliBro/utils/orientation_policy.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, EventChannel, MethodChannel;
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver;
import 'package:material_ui/material_ui.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class OrientationProbePage extends StatefulWidget {
  const OrientationProbePage({super.key});

  @override
  State<OrientationProbePage> createState() => _OrientationProbePageState();
}

class _OrientationProbePageState extends State<OrientationProbePage>
    with WidgetsBindingObserver {
  static const _nativeEvents = EventChannel('pilibro/orientation_probe');
  static const _orientationChannel = MethodChannel('pilibro/orientation');

  final Stopwatch _clock = Stopwatch();
  final List<String> _lines = <String>[];
  StreamSubscription<dynamic>? _nativeSubscription;
  StreamSubscription<OrientationParams>? _deviceSubscription;
  bool _running = false;

  String _ms() => '+${_clock.elapsedMilliseconds.toString().padLeft(6)}ms';

  void _log(String source, String value) {
    final line = '${_ms()} [$source] $value';
    _lines.add(line);
    if (mounted) setState(() {});
  }

  String _rotation(dynamic value) => switch (value) {
    0 => 'ROTATION_0',
    1 => 'ROTATION_90',
    2 => 'ROTATION_180',
    3 => 'ROTATION_270',
    null => '-',
    _ => value.toString(),
  };

  String _configuration(dynamic value) => switch (value) {
    1 => 'PORTRAIT',
    2 => 'LANDSCAPE',
    0 => 'UNDEFINED',
    null => '-',
    _ => value.toString(),
  };

  String _windowAxis() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 'no-view';
    final size = views.first.physicalSize;
    return '${size.width > size.height ? 'LANDSCAPE' : 'PORTRAIT'} '
        '${size.width.toInt()}x${size.height.toInt()}';
  }

  void _logNative(dynamic raw) {
    if (raw is! Map) {
      _log('NATIVE', raw.toString());
      return;
    }
    _log(
      'NATIVE/${raw['event']}',
      'proposed=${_rotation(raw['proposedRotation'])} '
      'display=${_rotation(raw['displayRotation'])} '
      'config=${_configuration(raw['configurationOrientation'])} '
      'requested=${raw['requestedOrientation']} '
      'autoRotate=${raw['systemAutoRotate']}',
    );
  }

  Future<void> _snapshot([String label = 'snapshot']) async {
    try {
      final raw = await _orientationChannel.invokeMethod<dynamic>(
        'orientationProbeSnapshot',
      );
      _logNative(
        raw is Map ? <dynamic, dynamic>{...raw, 'event': label} : raw,
      );
    } catch (e) {
      _log('SNAPSHOT/ERROR', e.toString());
    }
  }

  Future<void> _start({required bool forceLandscape}) async {
    if (_running || !Platform.isAndroid) return;
    _lines.clear();
    _clock
      ..reset()
      ..start();
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    if (mounted) setState(() {});

    _log(
      'TEST',
      'start mode=${forceLandscape ? 'APP_FORCE_LANDSCAPE' : 'SYSTEM_NATURAL'}; '
      'Flutter window=${_windowAxis()}',
    );

    _nativeSubscription = _nativeEvents.receiveBroadcastStream().listen(
      _logNative,
      onError: (Object error) => _log('NATIVE/ERROR', error.toString()),
    );

    _deviceSubscription = NativeDeviceOrientationPlatform.instance
        .onOrientationChanged(
          checkIsAutoRotate: false,
          angleDegrees: 30,
        )
        .listen(
          (event) => _log(
            'PLUGIN/deviceOrientation',
            event.orientation.toString(),
          ),
          onError: (Object error) => _log('PLUGIN/ERROR', error.toString()),
        );

    await _snapshot(forceLandscape ? 'beforeAppForceLandscape' : 'beforeSystemNatural');
    if (forceLandscape) {
      await OrientationPlatform.setAndroidRequestedOrientation(
        AndroidRequestedOrientation.landscape,
      );
      _log('COMMAND', 'requestedOrientation=LANDSCAPE(0)');
      await _snapshot('afterAppForceLandscape');
    } else {
      await OrientationPlatform.setAndroidRequestedOrientation(
        AndroidRequestedOrientation.unspecified,
      );
      _log('COMMAND', 'requestedOrientation=UNSPECIFIED(-1)');
      await _snapshot('afterSystemNatural');
    }
  }

  Future<void> _stop({bool restore = true}) async {
    if (!_running) return;
    _log('TEST', 'stop');
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
    await _deviceSubscription?.cancel();
    _deviceSubscription = null;
    if (restore) {
      await OrientationPolicy.restoreApp();
      _log('COMMAND', 'restoreApp');
    }
    _clock.stop();
    if (mounted) setState(() {});
  }

  @override
  void didChangeMetrics() {
    _log('FLUTTER/didChangeMetrics', 'window=${_windowAxis()}');
  }

  @override
  void dispose() {
    if (_running) {
      WidgetsBinding.instance.removeObserver(this);
      unawaited(_nativeSubscription?.cancel());
      unawaited(_deviceSubscription?.cancel());
      unawaited(OrientationPolicy.restoreApp());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('方向事件探针')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '纯诊断页，提供两种完全不同的实验。系统自然模式不会把页面声明成固定横屏，适合复现“先自然转横，再手动打开系统旋转锁”的 ChatGPT 场景；APP 强制横屏模式则测试 Activity 自己锁横时 Android 还会报告什么。两种模式都分别记录系统建议旋转、实际 Display、Configuration、Flutter 窗口变化和现有设备方向插件回调。',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _running ? null : () => _start(forceLandscape: false),
                child: const Text('开始：系统自然模式'),
              ),
              FilledButton(
                onPressed: _running ? null : () => _start(forceLandscape: true),
                child: const Text('开始：APP 强制横屏'),
              ),
              FilledButton.tonal(
                onPressed: _running ? () => _stop() : null,
                child: const Text('停止并恢复'),
              ),
              OutlinedButton(
                onPressed: _running ? () => _snapshot('manualSnapshot') : null,
                child: const Text('记录一次快照'),
              ),
              OutlinedButton(
                onPressed: _lines.isEmpty
                    ? null
                    : () => Clipboard.setData(
                        ClipboardData(text: _lines.join('\n')),
                      ),
                child: const Text('复制日志'),
              ),
              TextButton(
                onPressed: _lines.isEmpty
                    ? null
                    : () => setState(_lines.clear),
                child: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _running
                ? '测试中。系统自然模式建议：先让页面自然转成横屏，再手动打开系统旋转锁，然后做“竖→横→竖”；APP 强制横屏模式则无需开系统锁。'
                : '未运行。',
          ),
          const SizedBox(height: 12),
          SelectableText(
            _lines.isEmpty ? '暂无日志' : _lines.join('\n'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
