import 'dart:io' show Platform;

import 'package:PiliBro/common/widgets/flutter/list_tile.dart';
import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/common/widgets/view_safe_area.dart';
import 'package:PiliBro/pages/setting/widgets/select_dialog.dart';
import 'package:PiliBro/pages/setting/pages/orientation_probe.dart';
import 'package:PiliBro/pages/setting/widgets/slider_dialog.dart';
import 'package:PiliBro/pages/setting/widgets/switch_item.dart';
import 'package:PiliBro/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliBro/plugin/pl_player/models/orientation_mode.dart';
import 'package:PiliBro/plugin/pl_player/utils/orientation_handoff_lab.dart';
import 'package:PiliBro/utils/orientation_policy.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
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
    if (res == null) return;
    await GStorage.setting.put(key, res.index);
    await OrientationPolicy.compile();
    if (mounted) setState(() {});
  }

  Future<void> _showAngleDegreesDialog({
    required String key,
    required int value,
  }) async {
    final res = await showDialog<double>(
      context: context,
      builder: (context) => SliderDialog(
        title: const Text('APP 重力倾斜角度阈值'),
        min: 10,
        max: 90,
        divisions: 80,
        precise: 0,
        value: value.toDouble(),
        suffix: '°',
      ),
    );
    if (res == null) return;
    await GStorage.setting.put(key, res.toInt());
    await OrientationPolicy.compile();
    if (mounted) setState(() {});
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
    if (res == null) return;
    await GStorage.setting.put(SettingBoxKey.finalDirectionMask, res);
    await OrientationPolicy.compile();
    if (mounted) setState(() {});
  }

  Future<void> _showOrientationLabLog() async {
    final text = OrientationHandoffLab.text;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('方向交权实验日志（${OrientationHandoffLab.lineCount} 行）'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: SelectableText(text.isEmpty ? '暂无日志' : text),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              OrientationHandoffLab.clear();
              Get.back();
              if (mounted) setState(() {});
            },
            child: const Text('清空'),
          ),
          TextButton(
            onPressed: () => Clipboard.setData(
              ClipboardData(text: OrientationHandoffLab.text),
            ),
            child: const Text('复制'),
          ),
          TextButton(onPressed: Get.back, child: const Text('关闭')),
        ],
      ),
    );
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

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.primary),
    ),
  );

  List<Widget> _simpleSettings() => [
    _section('简单配置'),
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
      onChanged: (_) => OrientationPolicy.compile(),
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
        title: 'APP 重力倾斜角度阈值',
        subtitle: '当前：${Pref.angleDegrees}°',
        onTap: () => _showAngleDegreesDialog(
          key: SettingBoxKey.angleDegrees,
          value: Pref.angleDegrees,
        ),
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
  ];

  List<Widget> _advancedSettings() => [
    _section('高级配置'),
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        '高级配置与简单配置分别保存，不互相翻译。部分设置会在重新进入播放器或下次启动后生效。',
      ),
    ),
    _selectTile(
      title: 'APP 初始方向',
      subtitle: Pref.advancedAppInitialOrientation.desc,
      onTap: () => _select(
        title: 'APP 初始方向',
        value: Pref.advancedAppInitialOrientation,
        values: AppInitialOrientation.values,
        key: SettingBoxKey.advancedAppInitialOrientation,
        label: (e) => e.desc,
      ),
    ),
    _selectTile(
      title: 'APP 运行期间方向变化',
      subtitle: Pref.advancedAppRotationMode.desc,
      onTap: () => _select(
        title: 'APP 运行期间方向变化',
        value: Pref.advancedAppRotationMode,
        values: AppRotationMode.values,
        key: SettingBoxKey.advancedAppRotationMode,
        label: (e) => e.desc,
      ),
    ),
    _selectTile(
      title: '视频非全屏时方向变化',
      subtitle: Pref.advancedWindowedPlayerRotationMode.desc,
      onTap: () => _select(
        title: '视频非全屏时方向变化',
        value: Pref.advancedWindowedPlayerRotationMode,
        values: WindowedPlayerRotationMode.values,
        key: SettingBoxKey.advancedWindowedPlayerRotationMode,
        label: (e) => e.desc,
      ),
    ),
    SetSwitchItem(
      title: '横置时自动进入全屏',
      setKey: SettingBoxKey.advancedLandscapeEnter,
      defaultVal: Pref.advancedLandscapeEnter,
      onChanged: (_) => OrientationPolicy.compile(),
    ),
    SetSwitchItem(
      title: '竖置时自动退出全屏',
      setKey: SettingBoxKey.advancedPortraitExit,
      defaultVal: Pref.advancedPortraitExit,
      onChanged: (_) => OrientationPolicy.compile(),
    ),
    _selectTile(
      title: '进入全屏触发依据',
      subtitle: Pref.advancedEnterTriggerSource.desc,
      onTap: () => _select(
        title: '进入全屏触发依据',
        value: Pref.advancedEnterTriggerSource,
        values: OrientationTriggerSource.values,
        key: SettingBoxKey.advancedEnterTriggerSource,
        label: (e) => e.desc,
      ),
    ),
    _selectTile(
      title: '退出全屏触发依据',
      subtitle: Pref.advancedExitTriggerSource.desc,
      onTap: () => _select(
        title: '退出全屏触发依据',
        value: Pref.advancedExitTriggerSource,
        values: OrientationTriggerSource.values,
        key: SettingBoxKey.advancedExitTriggerSource,
        label: (e) => e.desc,
      ),
    ),
    _selectTile(
      title: '方向触发适用视频',
      subtitle: Pref.advancedTriggerContent.desc,
      onTap: () => _select(
        title: '方向触发适用视频',
        value: Pref.advancedTriggerContent,
        values: OrientationTriggerContent.values,
        key: SettingBoxKey.advancedTriggerContent,
        label: (e) => e.desc,
      ),
    ),
    _selectTile(
      title: '手动进入全屏时方向',
      subtitle: Pref.advancedManualEntryOrientation.desc,
      onTap: () => _select(
        title: '手动进入全屏时方向',
        value: Pref.advancedManualEntryOrientation,
        values: EntryOrientationPolicy.values
            .where((e) => e != EntryOrientationPolicy.triggerDirection)
            .toList(growable: false),
        key: SettingBoxKey.advancedManualEntryOrientation,
        label: (e) => e.desc,
      ),
    ),
    _selectTile(
      title: '播放自动进入全屏时方向',
      subtitle: Pref.advancedAutoEntryOrientation.desc,
      onTap: () => _select(
        title: '播放自动进入全屏时方向',
        value: Pref.advancedAutoEntryOrientation,
        values: EntryOrientationPolicy.values
            .where((e) => e != EntryOrientationPolicy.triggerDirection)
            .toList(growable: false),
        key: SettingBoxKey.advancedAutoEntryOrientation,
        label: (e) => e.desc,
      ),
    ),
    _selectTile(
      title: '方向触发进入全屏时方向',
      subtitle: Pref.advancedOrientationEntryOrientation.desc,
      onTap: () => _select(
        title: '方向触发进入全屏时方向',
        value: Pref.advancedOrientationEntryOrientation,
        values: EntryOrientationPolicy.values,
        key: SettingBoxKey.advancedOrientationEntryOrientation,
        label: (e) => e.desc,
      ),
    ),
    _selectTile(
      title: '全屏期间方向来源',
      subtitle: Pref.advancedFullScreenRotationSource.desc,
      onTap: () => _select(
        title: '全屏期间方向来源',
        value: Pref.advancedFullScreenRotationSource,
        values: FullScreenRotationSource.values,
        key: SettingBoxKey.advancedFullScreenRotationSource,
        label: (e) => e.desc,
      ),
    ),
    _selectTile(
      title: '全屏期间允许方向',
      subtitle: Pref.advancedFullScreenAllowedOrientation.desc,
      onTap: () => _select(
        title: '全屏期间允许方向',
        value: Pref.advancedFullScreenAllowedOrientation,
        values: FullScreenAllowedOrientation.values,
        key: SettingBoxKey.advancedFullScreenAllowedOrientation,
        label: (e) => e.desc,
      ),
    ),
    SetSwitchItem(
      title: 'APP 重力遵循系统方向锁定',
      setKey: SettingBoxKey.advancedGravityFollowSystemLock,
      defaultVal: Pref.advancedGravityFollowSystemLock,
      onChanged: (_) => OrientationPolicy.compile(),
    ),
    if (Platform.isAndroid)
      _selectTile(
        title: 'APP 重力倾斜角度阈值',
        subtitle: '当前：${Pref.advancedAngleDegrees}°',
        onTap: () => _showAngleDegreesDialog(
          key: SettingBoxKey.advancedAngleDegrees,
          value: Pref.advancedAngleDegrees,
        ),
      ),
    _selectTile(
      title: '方向自动退出全屏适用范围',
      subtitle: Pref.advancedAutoExitScope.desc,
      onTap: () => _select(
        title: '方向自动退出全屏适用范围',
        value: Pref.advancedAutoExitScope,
        values: OrientationAutoExitScope.values,
        key: SettingBoxKey.advancedAutoExitScope,
        label: (e) => e.desc,
      ),
    ),
    _selectTile(
      title: '退出全屏后的方向',
      subtitle: Pref.advancedExitOrientationMode.desc,
      onTap: () => _select(
        title: '退出全屏后的方向',
        value: Pref.advancedExitOrientationMode,
        values: ExitOrientationMode.values,
        key: SettingBoxKey.advancedExitOrientationMode,
        label: (e) => e.desc,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final mode = Pref.orientationPolicyMode;
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
              SetSwitchItem(
                title: '播放器控件锁同时锁定方向',
                subtitle: '关闭后，锁定播放器控件不会禁止屏幕继续旋转',
                setKey: SettingBoxKey.controlsLockOrientation,
                defaultVal: Pref.controlsLockOrientation,
                onChanged: (_) => OrientationPolicy.compile(),
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
              if (Platform.isAndroid) ...[
                _section('方向交权实验'),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '临时诊断功能。建议测试时使用“进入全屏强制横屏 + 全屏期间跟随系统 + 允许全部方向”；切换预设后重新进入播放器。',
                  ),
                ),
                ListTile(
                  title: const Text('方向事件探针'),
                  subtitle: const Text('锁横屏后分别记录系统建议、实际窗口和现有设备方向回调'),
                  trailing: const Icon(Icons.science_outlined),
                  onTap: () => Get.to(() => const OrientationProbePage()),
                ),
                _selectTile(
                  title: '交权实验预设',
                  subtitle: Pref.orientationHandoffExperiment.desc,
                  onTap: () => _select(
                    title: '交权实验预设',
                    value: Pref.orientationHandoffExperiment,
                    values: OrientationHandoffExperiment.values,
                    key: SettingBoxKey.orientationHandoffExperiment,
                    label: (e) => e.desc,
                  ),
                ),
                ListTile(
                  title: const Text('查看实验日志'),
                  subtitle: Text('当前 ${OrientationHandoffLab.lineCount} 行，可复制后直接发给 AI'),
                  trailing: const Icon(Icons.article_outlined),
                  onTap: _showOrientationLabLog,
                ),
                const Divider(),
              ],
              _selectTile(
                title: '方向配置模式',
                subtitle: mode.desc,
                onTap: () => _select(
                  title: '方向配置模式',
                  value: mode,
                  values: OrientationPolicyMode.values,
                  key: SettingBoxKey.orientationPolicyMode,
                  label: (e) => e.desc,
                ),
              ),
              const Divider(),
              ...(mode == OrientationPolicyMode.simple
                  ? _simpleSettings()
                  : _advancedSettings()),
            ],
          ],
        ),
      ),
    );
  }
}
