import 'dart:io' show Platform;

import 'package:PiliBro/common/widgets/flutter/list_tile.dart';
import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/common/widgets/view_safe_area.dart';
import 'package:PiliBro/pages/setting/widgets/select_dialog.dart';
import 'package:PiliBro/pages/setting/widgets/slider_dialog.dart';
import 'package:PiliBro/pages/setting/widgets/switch_item.dart';
import 'package:PiliBro/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliBro/plugin/pl_player/models/orientation_mode.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class OrientationSettingsPage extends StatefulWidget {
  const OrientationSettingsPage({super.key});

  @override
  State<OrientationSettingsPage> createState() =>
      _OrientationSettingsPageState();
}

class _OrientationSettingsPageState extends State<OrientationSettingsPage> {
  Future<void> _select<T extends Enum>({
    required String title,
    required T value,
    required List<T> values,
    required String key,
    required String Function(T value) label,
  }) async {
    final res = await showDialog<T>(
      context: context,
      builder: (context) => SelectDialog<T>(
        title: title,
        value: value,
        values: values.map((e) => (e, label(e))).toList(),
      ),
    );
    if (res != null) {
      await GStorage.setting.put(key, res.index);
      if (mounted) setState(() {});
    }
  }

  Future<void> _showAngleDegreesDialog() async {
    final res = await showDialog<double>(
      context: context,
      builder: (context) => SliderDialog(
        title: const Text('倾斜角度阈值'),
        min: 10,
        max: 90,
        divisions: 80,
        precise: 0,
        value: Pref.angleDegrees.toDouble(),
        suffix: '°',
      ),
    );
    if (res != null) {
      await GStorage.setting.put(SettingBoxKey.angleDegrees, res.toInt());
      if (mounted) setState(() {});
    }
  }

  Future<void> _showFinalDirectionMaskDialog() async {
    var mask = Pref.finalDirectionMask;
    final res = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget item(String title, int bit) => CheckboxListTile(
            title: Text(title),
            value: mask & bit != 0,
            onChanged: (value) {
              setDialogState(() {
                if (value == true) {
                  mask |= bit;
                } else {
                  mask &= ~bit;
                }
              });
            },
          );
          return AlertDialog(
            title: const Text('最终方向许可'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  item('正竖屏', OrientationMask.portraitUp),
                  item('倒竖屏', OrientationMask.portraitDown),
                  item('左横屏', OrientationMask.landscapeLeft),
                  item('右横屏', OrientationMask.landscapeRight),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: Get.back, child: const Text('取消')),
              TextButton(
                onPressed: () => Get.back(result: mask),
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
    if (res != null) {
      await GStorage.setting.put(SettingBoxKey.finalDirectionMask, res);
      if (mounted) setState(() {});
    }
  }

  Widget _selectTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => ListTile(
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(title: const Text('方向（横竖屏）设置')),
      body: ViewSafeArea(
        child: ListView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
          ),
          children: [
            SetSwitchItem(
              title: '横屏时布局美化',
              subtitle: '横屏时使用宽屏布局',
              setKey: SettingBoxKey.horizontalScreen,
              defaultVal: Pref.horizontalScreen,
            ),
            if (PlatformUtils.isMobile) ...[
              _selectTile(
                title: 'APP 初始方向',
                subtitle: Pref.appInitialOrientation.desc,
                onTap: () => _select(
                  title: 'APP 初始方向',
                  value: Pref.appInitialOrientation,
                  values: AppInitialOrientation.values,
                  key: SettingBoxKey.appInitialOrientation,
                  label: (e) => e.desc,
                ),
              ),
              _selectTile(
                title: 'APP 运行期间方向变化',
                subtitle: Pref.appRotationMode.desc,
                onTap: () => _select(
                  title: 'APP 运行期间方向变化',
                  value: Pref.appRotationMode,
                  values: AppRotationMode.values,
                  key: SettingBoxKey.appRotationMode,
                  label: (e) => e.desc,
                ),
              ),
              _selectTile(
                title: '进入全屏时方向',
                subtitle: Pref.fullScreenMode.desc,
                onTap: () => _select(
                  title: '进入全屏时方向',
                  value: Pref.fullScreenMode,
                  values: FullScreenMode.values
                      .where((e) => e != FullScreenMode.gravity)
                      .toList(growable: false),
                  key: SettingBoxKey.fullScreenMode,
                  label: (e) => e.desc,
                ),
              ),
              _selectTile(
                title: '全屏期间方向来源',
                subtitle: Pref.fullScreenRotationSource.desc,
                onTap: () => _select(
                  title: '全屏期间方向来源',
                  value: Pref.fullScreenRotationSource,
                  values: FullScreenRotationSource.values,
                  key: SettingBoxKey.fullScreenRotationSource,
                  label: (e) => e.desc,
                ),
              ),
              _selectTile(
                title: '全屏期间允许方向',
                subtitle: Pref.fullScreenAllowedOrientation.desc,
                onTap: () => _select(
                  title: '全屏期间允许方向',
                  value: Pref.fullScreenAllowedOrientation,
                  values: FullScreenAllowedOrientation.values,
                  key: SettingBoxKey.fullScreenAllowedOrientation,
                  label: (e) => e.desc,
                ),
              ),
              SetSwitchItem(
                title: 'APP 重力遵循系统方向锁定',
                setKey: SettingBoxKey.gravityFollowSystemLock,
                defaultVal: Pref.gravityFollowSystemLock,
              ),
              _selectTile(
                title: '方向触发全屏',
                subtitle: Pref.orientationFullscreenTrigger.desc,
                onTap: () => _select(
                  title: '方向触发全屏',
                  value: Pref.orientationFullscreenTrigger,
                  values: OrientationFullscreenTrigger.values,
                  key: SettingBoxKey.orientationFullscreenTrigger,
                  label: (e) => e.desc,
                ),
              ),
              _selectTile(
                title: '方向触发依据',
                subtitle: Pref.orientationTriggerSource.desc,
                onTap: () => _select(
                  title: '方向触发依据',
                  value: Pref.orientationTriggerSource,
                  values: OrientationTriggerSource.values,
                  key: SettingBoxKey.orientationTriggerSource,
                  label: (e) => e.desc,
                ),
              ),
              if (Platform.isAndroid)
                _selectTile(
                  title: '倾斜角度阈值',
                  subtitle: '当前：${Pref.angleDegrees}°',
                  onTap: _showAngleDegreesDialog,
                ),
              _selectTile(
                title: '退出全屏后的方向',
                subtitle: Pref.exitOrientationMode.desc,
                onTap: () => _select(
                  title: '退出全屏后的方向',
                  value: Pref.exitOrientationMode,
                  values: ExitOrientationMode.values,
                  key: SettingBoxKey.exitOrientationMode,
                  label: (e) => e.desc,
                ),
              ),
              _selectTile(
                title: '最终方向许可',
                subtitle: Pref.finalDirectionMask == 0
                    ? '关闭'
                    : [
                        if (Pref.finalDirectionMask &
                                OrientationMask.portraitUp !=
                            0)
                          '正竖',
                        if (Pref.finalDirectionMask &
                                OrientationMask.portraitDown !=
                            0)
                          '倒竖',
                        if (Pref.finalDirectionMask &
                                OrientationMask.landscapeLeft !=
                            0)
                          '左横',
                        if (Pref.finalDirectionMask &
                                OrientationMask.landscapeRight !=
                            0)
                          '右横',
                      ].join('、'),
                onTap: _showFinalDirectionMaskDialog,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
