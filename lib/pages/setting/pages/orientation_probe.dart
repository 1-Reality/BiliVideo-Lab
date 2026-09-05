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
    if (_lines.length > 1200) {
      _lines.removeRange(0, _lines.length - 1200);
    }
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

  String _physicalQuadrant(dynamic value) => switch (value) {
    0 => '0°/自然正向',
    1 => '90°',
    2 => '180°',
    3 => '270°',
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
      'autoRotate=${raw['systemAutoRotate']} '
      'userRotation=${_rotation(raw['systemUserRotation'])} '
      'physical=${raw['physicalOrientationDegrees'] ?? '-'}°/'
      '${_physicalQuadrant(raw['physicalQuadrant'])} '
      'window=${raw['windowWidth']}x${raw['windowHeight']}',
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

  Future<void> _start() async {
    if (_running || !Platform.isAndroid) return;
    _lines.clear();
    _clock
      ..reset()
      ..start();
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    if (mounted) setState(() {});

    _log('TEST', 'probe started; Flutter window=${_windowAxis()}');

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

    await _snapshot('initialSnapshot');
  }

  Future<void> _setRequested(String name, int value) async {
    if (!_running) return;
    _log('COMMAND', '$name requestedOrientation=$value');
    await OrientationPlatform.setAndroidRequestedOrientation(value);
    await _snapshot('after_$name');
  }

  Future<void> _restore() async {
    if (!_running) return;
    _log('COMMAND', 'restoreApp');
    await OrientationPolicy.restoreApp();
    await _snapshot('after_restoreApp');
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

  Widget _modeButton(String label, int value) => OutlinedButton(
    onPressed: _running ? () => _setRequested(label, value) : null,
    child: Text(label),
  );

  void _mark(String value) => _log('MARK', value);

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
      appBar: AppBar(title: const Text('方向事件总探针')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '一个 APK 覆盖全部关键实验。开始探针本身不改变页面方向；之后可随时切换 Activity 的方向声明，并同时观察系统建议旋转、原生物理方向、现有插件方向、Display、Configuration、Flutter 窗口、系统旋转锁与 USER_ROTATION。所有监听都是事件驱动，仅在本页测试期间开启。',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _running ? null : _start,
                child: const Text('开始探针（不改方向）'),
              ),
              FilledButton.tonal(
                onPressed: _running ? () => _stop() : null,
                child: const Text('停止并恢复'),
              ),
              OutlinedButton(
                onPressed: _running ? () => _snapshot('manualSnapshot') : null,
                child: const Text('记录快照'),
              ),
              OutlinedButton(
                onPressed: _running ? _restore : null,
                child: const Text('恢复 APP 正常策略'),
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
          const SizedBox(height: 18),
          const Text('关键方向声明'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _modeButton('UNSPECIFIED 系统自然', -1),
              _modeButton('LANDSCAPE 强制横屏', 0),
              _modeButton('PORTRAIT 强制竖屏', 1),
              _modeButton('USER', 2),
              _modeButton('SENSOR', 4),
              _modeButton('NO_SENSOR', 5),
              _modeButton('SENSOR_LANDSCAPE', 6),
              _modeButton('SENSOR_PORTRAIT', 7),
              _modeButton('REVERSE_LANDSCAPE', 8),
              _modeButton('REVERSE_PORTRAIT', 9),
              _modeButton('FULL_SENSOR', 10),
              _modeButton('USER_LANDSCAPE', 11),
              _modeButton('USER_PORTRAIT', 12),
              _modeButton('FULL_USER', 13),
              _modeButton('LOCKED 锁当前', 14),
            ],
          ),
          const SizedBox(height: 18),
          const Text('人工时间标记'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _running ? () => _mark('开始静止') : null,
                child: const Text('标记：静止'),
              ),
              OutlinedButton(
                onPressed: _running ? () => _mark('准备物理转横') : null,
                child: const Text('标记：转横'),
              ),
              OutlinedButton(
                onPressed: _running ? () => _mark('准备物理转竖') : null,
                child: const Text('标记：转竖'),
              ),
              OutlinedButton(
                onPressed: _running ? () => _mark('刚切换系统旋转锁') : null,
                child: const Text('标记：旋转锁'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            '建议第一轮：开始探针 → UNSPECIFIED → 自然转横 → 打开系统旋转锁 → 静止 → 物理转竖 → 转横 → 再转竖。第二轮无需退出本页，直接点 LANDSCAPE 强制横屏，再重复同样动作。之后 USER / FULL_USER / FULL_SENSOR / LOCKED 等都可在同一轮日志里继续测试。',
          ),
          const SizedBox(height: 12),
          Text(_running ? '测试中，当前 Flutter 窗口：${_windowAxis()}' : '未运行。'),
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
