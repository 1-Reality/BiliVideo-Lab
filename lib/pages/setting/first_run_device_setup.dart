import 'package:PiliBro/pages/setting/tv_remote_setup.dart';
import 'package:PiliBro/utils/device_form_factor_platform.dart';
import 'package:PiliBro/utils/device_presets.dart';
import 'package:PiliBro/utils/device_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:flutter/services.dart' show KeyEvent, PlatformException;
import 'package:flutter/widgets.dart' show FocusManager, KeyEventResult;
import 'package:material_ui/material_ui.dart';

enum DeviceFormFactor {
  phone('手机'),
  foldable('折叠屏'),
  tablet('平板'),
  television('电视 / 遥控器设备');

  const DeviceFormFactor(this.label);
  final String label;
}

abstract final class FirstRunDeviceSetup {
  static Future<bool> prepare() async {
    if (await _shouldShowChooser()) return true;
    await DevicePresets.applyPhone(applyNow: false);
    await GStorage.completeFirstRunDeviceSetup();
    return false;
  }

  static Future<bool> _shouldShowChooser() async {
    try {
      final hints = await DeviceFormFactorPlatform.firstRunHints();
      final size = DeviceUtils.size;

      if (hints.television) return true;
      if (!hints.touchscreen) return true;
      if (hints.hingeAngle) return true;
      if (size.width > size.height) return true;
      if (size.width <= 0 || size.height / size.width < 1.5) return true;
      if (hints.phoneCapable) return false;
      return true;
    } on PlatformException {
      return true;
    }
  }

  static Future<void> show(BuildContext context) async {
    while (context.mounted) {
      final selected = await _choose(context);
      if (selected == null || !context.mounted) return;

      if (selected == DeviceFormFactor.phone) {
        await DevicePresets.applyPhone();
        await GStorage.completeFirstRunDeviceSetup();
        return;
      }

      if (!await _confirm(context, selected) || !context.mounted) continue;

      switch (selected) {
        case DeviceFormFactor.phone:
          return;
        case DeviceFormFactor.foldable:
          await DevicePresets.applyFoldable();
          await GStorage.completeFirstRunDeviceSetup();
          return;
        case DeviceFormFactor.tablet:
          await DevicePresets.applyTablet();
          await GStorage.completeFirstRunDeviceSetup();
          return;
        case DeviceFormFactor.television:
          await TvRemoteSetup.configureAndLogin(
            context,
            completeFirstRun: true,
          );
          return;
      }
    }
  }

  static Future<DeviceFormFactor?> _choose(BuildContext context) async {
    BuildContext? dialogContext;
    var closing = false;

    void select(DeviceFormFactor value) {
      final current = dialogContext;
      if (closing || current == null) return;
      closing = true;
      Navigator.of(current).pop(value);
    }

    KeyEventResult handleKey(KeyEvent event) {
      if (!TvRemoteSetup.isRemoteIntentKey(event)) {
        return KeyEventResult.ignored;
      }
      select(DeviceFormFactor.television);
      return KeyEventResult.handled;
    }

    FocusManager.instance.addEarlyKeyEventHandler(handleKey);
    try {
      return await showDialog<DeviceFormFactor>(
        context: context,
        barrierDismissible: false,
        builder: (current) {
          dialogContext = current;
          return AlertDialog(
            insetPadding: const EdgeInsets.all(24),
            title: const Text(
              '请问您正在使用什么设备？',
              style: TextStyle(fontSize: 26),
            ),
            content: SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('请选择最接近当前设备形态的一项。'),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('手机（点这里）'),
                    onTap: () => select(DeviceFormFactor.phone),
                  ),
                  ListTile(
                    title: const Text('折叠屏（点击）'),
                    onTap: () => select(DeviceFormFactor.foldable),
                  ),
                  ListTile(
                    title: const Text('平板（单击）'),
                    onTap: () => select(DeviceFormFactor.tablet),
                  ),
                  ListTile(
                    title: const Text('电视 / 遥控器设备（按 OK 进入）'),
                    onTap: () => select(DeviceFormFactor.television),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '按遥控器任意键，进入电视 / 投影 / 大屏设备设置！',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '使用触控、鼠标或键盘操作的设备，请直接选择正确选项。',
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      FocusManager.instance.removeEarlyKeyEventHandler(handleKey);
    }
  }

  static Future<bool> _confirm(
    BuildContext context,
    DeviceFormFactor form,
  ) async {
    BuildContext? dialogContext;
    var closing = false;

    void accept() {
      final current = dialogContext;
      if (closing || current == null) return;
      closing = true;
      Navigator.of(current).pop(true);
    }

    KeyEventResult handleTvKey(KeyEvent event) {
      if (form != DeviceFormFactor.television ||
          !TvRemoteSetup.isRemoteIntentKey(event)) {
        return KeyEventResult.ignored;
      }
      accept();
      return KeyEventResult.handled;
    }

    if (form == DeviceFormFactor.television) {
      FocusManager.instance.addEarlyKeyEventHandler(handleTvKey);
    }
    try {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (current) {
              dialogContext = current;
              final television = form == DeviceFormFactor.television;
              return AlertDialog(
                insetPadding: const EdgeInsets.all(24),
                title: Text(
                  television ? '确认电视 / 遥控器设备' : '确认设备形态',
                ),
                content: SizedBox(
                  width: 600,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: television
                                  ? '您确认当前设备是 '
                                  : '您确认当前设备形态是 ',
                            ),
                            TextSpan(
                              text: television
                                  ? '【电视 / 投影 / 大屏设备】'
                                  : '【${form.label}】',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: television
                                  ? '，并主要使用遥控器操作吗？'
                                  : ' 吗？',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '若不是，请立即返回。\n'
                        '若误入，请将该 APP 杀后台后重新打开。',
                      ),
                      if (television) ...[
                        const SizedBox(height: 14),
                        const Text(
                          '若确认无误，请按遥控器【OK】或除返回键外的任意键继续。',
                        ),
                      ],
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
      if (form == DeviceFormFactor.television) {
        FocusManager.instance.removeEarlyKeyEventHandler(handleTvKey);
      }
    }
  }
}
