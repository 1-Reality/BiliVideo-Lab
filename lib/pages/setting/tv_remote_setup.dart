import 'dart:async' show Timer, unawaited;

import 'package:PiliBro/common/widgets/dialog/export_import.dart';
import 'package:PiliBro/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliBro/pages/login/view.dart';
import 'package:PiliBro/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliBro/plugin/pl_player/models/orientation_mode.dart';
import 'package:PiliBro/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliBro/plugin/pl_player/utils/orientation_platform.dart';
import 'package:PiliBro/utils/orientation_policy.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent;
import 'package:flutter/widgets.dart' show FocusManager, KeyEventResult;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

abstract final class TvRemoteSetup {
  static Future<void> showStartupPrompt(BuildContext context) async {
    var starting = false;
    void start(BuildContext dialogContext) {
      if (starting) return;
      starting = true;
      Navigator.of(dialogContext).pop();
      unawaited(configureAndLogin(context));
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent) {
              start(dialogContext);
              return .handled;
            }
            return .ignored;
          },
          child: AlertDialog(
            insetPadding: const .all(24),
            title: const Text(
              '检测到横屏 Android 设备',
              style: TextStyle(fontSize: 26),
            ),
            content: const SizedBox(
              width: 560,
              child: Text(
                '如果这是电视或主要使用遥控器，可以应用遥控器配置并扫码登录。'
                '配置后会进行 10 秒方向校准。\n\n'
                '任意键盘或遥控器按键均视为确认。',
                style: TextStyle(fontSize: 18, height: 1.45),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await OrientationPolicy.applyStartup();
                },
                child: const Text('取消'),
              ),
              FilledButton(
                autofocus: true,
                onPressed: () => start(dialogContext),
                child: const Text('配置遥控器并登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> showMenu(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('电视机快速登录与遥控器配置'),
        content: const Text('这是一次性配置工具，只修改普通设置，不建立独立的电视运行模式。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(_showExportMenu(context));
            },
            child: const Text('导出设置'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(_openQrLogin());
            },
            child: const Text('仅登录'),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(configureAndLogin(context));
            },
            child: const Text('配置遥控器并登录'),
          ),
        ],
      ),
    );
  }

  static Future<void> configureAndLogin(BuildContext context) async {
    await _applyPreset();
    await lockedMode();
    if (!context.mounted) return;
    final initialBit =
        await OrientationPlatform.currentOrientationBit() ??
        OrientationMask.landscapeLeft;
    if (!context.mounted) return;
    final direction = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RemoteOrientationCalibration(initialBit: initialBit),
    );
    if (direction != null) {
      await GStorage.setting.put(
        SettingBoxKey.appInitialOrientation,
        (direction & OrientationMask.portrait != 0
                ? AppInitialOrientation.portrait
                : AppInitialOrientation.landscape)
            .index,
      );
      OrientationPolicy.setStartupDirection(direction);
      await OrientationPolicy.compile();
      await lockedMode();
    }
    if (context.mounted) await _openQrLogin();
  }

  static Future<void> _applyPreset() async {
    await GStorage.setting.putAll({
      SettingBoxKey.horizontalScreen: true,
      SettingBoxKey.keyboardControl: false,
      SettingBoxKey.appInitialOrientation: AppInitialOrientation.landscape.index,
      SettingBoxKey.appRotationMode: AppRotationMode.lockInitial.index,
      SettingBoxKey.fullScreenMode: FullScreenMode.none.index,
      SettingBoxKey.fullScreenRotationSource:
          FullScreenRotationSource.keepCurrent.index,
      SettingBoxKey.fullScreenAllowedOrientation:
          FullScreenAllowedOrientation.entryExact.index,
      SettingBoxKey.orientationFullscreenTrigger:
          OrientationFullscreenTrigger.off.index,
      SettingBoxKey.exitOrientationMode: ExitOrientationMode.restoreApp.index,
    });
    await OrientationPolicy.compile();
  }

  static Future<void> _openQrLogin() async {
    await Get.to<void>(() => const LoginPage(initialIndex: 2));
  }

  static Future<void> _showExportMenu(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('导出设置'),
        children: [
          DialogOption(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              exportToClipBoard(onExport: GStorage.exportPortableSettings);
            },
            child: const Text('导出至剪贴板'),
          ),
          DialogOption(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              exportToLocalFile(
                onExport: GStorage.exportPortableSettings,
                localFileName: () => 'setting_tv',
              );
            },
            child: const Text('导出文件至本地'),
          ),
        ],
      ),
    );
  }
}

class _RemoteOrientationCalibration extends StatefulWidget {
  const _RemoteOrientationCalibration({required this.initialBit});

  final int initialBit;

  @override
  State<_RemoteOrientationCalibration> createState() =>
      _RemoteOrientationCalibrationState();
}

class _RemoteOrientationCalibrationState
    extends State<_RemoteOrientationCalibration> {
  static const _directions = [
    OrientationMask.portraitUp,
    OrientationMask.landscapeLeft,
    OrientationMask.portraitDown,
    OrientationMask.landscapeRight,
  ];

  late int _index;
  int _seconds = 10;
  Timer? _timer;
  bool _finishing = false;

  int get _direction => _directions[_index];

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleKeyEvent);
    final index = _directions.indexOf(widget.initialBit);
    _index = index < 0 ? 1 : index;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_seconds <= 1) {
        _timer?.cancel();
        unawaited(_finish());
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKeyEvent);
    _timer?.cancel();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      _rotate();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _rotate() {
    if (_finishing) return;
    setState(() {
      _index = (_index + 1) & 3;
      _seconds = 10;
    });
    unawaited(_applyDirection(_direction));
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final actual =
        await OrientationPlatform.currentOrientationBit() ?? _direction;
    if (mounted) Navigator.of(context).pop(actual);
  }

  Future<void> _applyDirection(int direction) async {
    switch (direction) {
      case OrientationMask.portraitUp:
        await portraitUpMode();
      case OrientationMask.landscapeLeft:
        await landscapeLeftMode();
      case OrientationMask.portraitDown:
        await portraitDownMode();
      case OrientationMask.landscapeRight:
        await landscapeRightMode();
    }
  }

  String get _directionLabel => switch (_direction) {
    OrientationMask.portraitUp => '正竖屏',
    OrientationMask.landscapeLeft => '左横屏',
    OrientationMask.portraitDown => '倒竖屏',
    _ => '右横屏',
  };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      insetPadding: const .all(24),
      title: const Text('遥控器方向校准'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_seconds',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const Text('秒后完成'),
            const SizedBox(height: 24),
            const Text(
              '按任意键旋转屏幕',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 12),
            Text('当前：$_directionLabel'),
          ],
        ),
      ),
    ),
  );
}
