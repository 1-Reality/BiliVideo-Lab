import 'dart:async' show Timer, unawaited;

import 'package:PiliBro/common/widgets/dialog/export_import.dart';
import 'package:PiliBro/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliBro/pages/login/view.dart';
import 'package:PiliBro/plugin/pl_player/models/orientation_mode.dart';
import 'package:PiliBro/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliBro/plugin/pl_player/utils/orientation_platform.dart';
import 'package:PiliBro/utils/device_presets.dart';
import 'package:PiliBro/utils/orientation_policy.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show FocusManager, KeyEventResult;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

enum _TvRemoteMenuAction {
  configure,
  exportSettings,
  login,
  restoreDefaults,
}

abstract final class TvRemoteSetup {
  static bool isRemoteIntentKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape) {
      return false;
    }
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  static Future<void> showMenu(BuildContext context) async {
    BuildContext? dialogContext;
    var closing = false;

    void select(_TvRemoteMenuAction action) {
      final current = dialogContext;
      if (closing || current == null) return;
      closing = true;
      Navigator.of(current).pop(action);
    }

    KeyEventResult handleRemoteKey(KeyEvent event) {
      if (!isRemoteIntentKey(event)) return KeyEventResult.ignored;
      select(_TvRemoteMenuAction.configure);
      return KeyEventResult.handled;
    }

    FocusManager.instance.addEarlyKeyEventHandler(handleRemoteKey);
    final _TvRemoteMenuAction? action;
    try {
      action = await showDialog<_TvRemoteMenuAction>(
        context: context,
        builder: (current) {
          dialogContext = current;
          return AlertDialog(
            title: const Text('电视机快速登录与遥控器配置'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('这是一次性配置工具，只修改普通设置，不建立独立的电视运行模式。'),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () =>
                        select(_TvRemoteMenuAction.restoreDefaults),
                    icon: const Icon(Icons.restore),
                    label: const Text('恢复默认设置（平板预设）'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(current).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => select(_TvRemoteMenuAction.exportSettings),
                child: const Text('导出设置'),
              ),
              TextButton(
                onPressed: () => select(_TvRemoteMenuAction.login),
                child: const Text('仅登录'),
              ),
              FilledButton(
                onPressed: () => select(_TvRemoteMenuAction.configure),
                child: const Text('配置遥控器并登录'),
              ),
            ],
          );
        },
      );
    } finally {
      FocusManager.instance.removeEarlyKeyEventHandler(handleRemoteKey);
    }

    if (!context.mounted) return;
    switch (action) {
      case _TvRemoteMenuAction.configure:
        await configureAndLogin(context);
      case _TvRemoteMenuAction.exportSettings:
        await _showExportMenu(context);
      case _TvRemoteMenuAction.login:
        await _openQrLogin();
      case _TvRemoteMenuAction.restoreDefaults:
        await DevicePresets.restoreTabletDefaults();
      case null:
        return;
    }
  }

  static Future<bool> configureAndLogin(
    BuildContext context, {
    bool completeFirstRun = false,
  }) async {
    if (!await _confirmRemoteSetup(context) || !context.mounted) return false;

    await DevicePresets.applyTelevision();
    await lockedMode();
    if (!context.mounted) return false;

    final initialBit =
        await OrientationPlatform.currentOrientationBit() ??
        OrientationMask.landscapeLeft;
    if (!context.mounted) return false;

    final direction = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RemoteOrientationCalibration(initialBit: initialBit),
    );
    if (direction == null) return false;

    await GStorage.setting.put(
      SettingBoxKey.appInitialOrientation,
      switch (direction) {
        OrientationMask.portraitDown => AppInitialOrientation.portraitDown,
        OrientationMask.landscapeLeft => AppInitialOrientation.landscapeLeft,
        OrientationMask.landscapeRight => AppInitialOrientation.landscapeRight,
        _ => AppInitialOrientation.portraitUp,
      }.index,
    );
    OrientationPolicy.setStartupDirection(direction);
    await OrientationPolicy.compile();
    await lockedMode();

    if (completeFirstRun) {
      await GStorage.completeFirstRunDeviceSetup();
    }
    if (context.mounted) await _openQrLogin();
    return true;
  }

  static Future<bool> _confirmRemoteSetup(BuildContext context) async {
    BuildContext? dialogContext;
    var closing = false;

    void accept() {
      final current = dialogContext;
      if (closing || current == null) return;
      closing = true;
      Navigator.of(current).pop(true);
    }

    KeyEventResult handleRemoteKey(KeyEvent event) {
      if (!isRemoteIntentKey(event)) return KeyEventResult.ignored;
      accept();
      return KeyEventResult.handled;
    }

    FocusManager.instance.addEarlyKeyEventHandler(handleRemoteKey);
    try {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (current) {
              dialogContext = current;
              return AlertDialog(
                insetPadding: const EdgeInsets.all(24),
                title: const Text('确认配置遥控器'),
                content: SizedBox(
                  width: 600,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: '您确认当前设备是 '),
                            TextSpan(
                              text: '【电视 / 投影 / 大屏设备】',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: '，并主要使用遥控器操作吗？'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('确认后才会写入电视预设并进入遥控器方向校准；若不是，请返回。'),
                      const SizedBox(height: 14),
                      const Text('若确认无误，请按遥控器【OK】或除返回键外的任意键继续。'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(current).pop(false),
                    child: const Text('返回'),
                  ),
                  FilledButton(
                    onPressed: accept,
                    child: const Text('确定'),
                  ),
                ],
              );
            },
          ) ??
          false;
    } finally {
      FocusManager.instance.removeEarlyKeyEventHandler(handleRemoteKey);
    }
  }

  static Future<void> _openQrLogin() async {
    await Get.to(() => const LoginPage(initialIndex: 2));
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
              unawaited(
                exportToQrCode(
                  context,
                  onExport: GStorage.exportPortableSettings,
                ),
              );
            },
            child: const Text('导出为二维码'),
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
  late final KeyEventResult Function(KeyEvent) _keyHandler;

  int get _direction => _directions[_index];

  @override
  void initState() {
    super.initState();
    _keyHandler = _handleKeyEvent;
    FocusManager.instance.addEarlyKeyEventHandler(_keyHandler);
    final index = _directions.indexOf(widget.initialBit);
    _index = index < 0 ? 1 : index;
    _startTimer();
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_keyHandler);
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

  void _startTimer() {
    _timer?.cancel();
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

  void _rotate() {
    if (_finishing) return;
    setState(() {
      _index = (_index + 1) & 3;
      _seconds = 10;
    });
    _startTimer();
    unawaited(_applyDirection(_direction));
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final actual =
        await OrientationPlatform.currentOrientationBit() ?? _direction;
    if (mounted) Navigator.of(context).pop(actual);
  }

  Future<void> _applyDirection(int direction) =>
      OrientationPolicy.applyDirection(direction);

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
      insetPadding: const EdgeInsets.all(24),
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
