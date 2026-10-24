import 'dart:io' show Platform;

import 'package:PiliBro/common/widgets/flutter/list_tile.dart';
import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/common/widgets/view_safe_area.dart';
import 'package:PiliBro/pages/setting/widgets/select_dialog.dart';
import 'package:PiliBro/pages/setting/widgets/slider_dialog.dart';
import 'package:PiliBro/pages/setting/widgets/switch_item.dart';
import 'package:PiliBro/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliBro/plugin/pl_player/models/orientation_mode.dart';
import 'package:PiliBro/utils/orientation_diagnostics.dart';
import 'package:PiliBro/utils/orientation_policy.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class OrientationSettingsPage extends StatefulWidget {
  const OrientationSettingsPage({super.key});

  @override
  State<OrientationSettingsPage> createState() =>
      _OrientationSettingsPageState();
}

class _OrientationSettingsPageState extends State<OrientationSettingsPage> {
  BrotherOrientationPhase _brotherPhase = BrotherOrientationPhase.app;
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

  Future<void> _showAutoExitCausesDialog() async {
    var mask = Pref.advancedAutoExitCauses;
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
            title: const Text('方向自动退出全屏适用范围'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                item('手动进入全屏', FullscreenEntryCauseMask.manual),
                item('播放自动进入全屏', FullscreenEntryCauseMask.playbackAuto),
                item('方向触发进入全屏', FullscreenEntryCauseMask.orientation),
              ],
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
    await GStorage.setting.put(SettingBoxKey.advancedAutoExitCauses, res);
    await OrientationPolicy.compile();
    if (mounted) setState(() {});
  }

  Future<void> _showManualExitConfirmationsDialog() async {
    final controller = TextEditingController(
      text: Pref.advancedManualExitConfirmations.toString(),
    );
    final res = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('手动全屏退出确认次数'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            helperText: '0 = 关闭；不设上限',
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          TextButton(
            onPressed: () => Get.back(
              result: int.tryParse(controller.text),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (res == null) return;
    await GStorage.setting.put(
      SettingBoxKey.advancedManualExitConfirmations,
      res,
    );
    await OrientationPolicy.compile();
    if (mounted) setState(() {});
  }

  String _autoExitCausesLabel(int mask) {
    final values = [
      if (mask & FullscreenEntryCauseMask.manual != 0) '手动',
      if (mask & FullscreenEntryCauseMask.playbackAuto != 0) '播放自动',
      if (mask & FullscreenEntryCauseMask.orientation != 0) '方向触发',
    ];
    return values.isEmpty ? '无' : values.join('、');
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


  Future<T?> _pickEnum<T extends Enum>({
    required String title,
    required T value,
    required List<T> values,
    required String Function(T value) label,
  }) =>
      showDialog<T>(
        context: context,
        builder: (context) => SelectDialog<T>(
          title: title,
          value: value,
          values: values.map((e) => (e, label(e))).toList(),
        ),
      );

  BrotherPhaseConfig get _brotherPhaseConfig => switch (_brotherPhase) {
    BrotherOrientationPhase.app => Pref.brotherAppPhase,
    BrotherOrientationPhase.windowed => Pref.brotherWindowedPhase,
    BrotherOrientationPhase.fullscreen => Pref.brotherFullscreenPhase,
  };

  String get _brotherPhaseKey => switch (_brotherPhase) {
    BrotherOrientationPhase.app => SettingBoxKey.brotherAppPhase,
    BrotherOrientationPhase.windowed => SettingBoxKey.brotherWindowedPhase,
    BrotherOrientationPhase.fullscreen => SettingBoxKey.brotherFullscreenPhase,
  };

  Future<void> _writeBrotherPhase(BrotherPhaseConfig config) async {
    await GStorage.setting.put(_brotherPhaseKey, config.toStorage());
    await OrientationPolicy.compile();
    if (mounted) setState(() {});
  }

  List<BrotherDirectionAction> _brotherActionValues({
    required bool resume,
  }) {
    if (_brotherPhase == BrotherOrientationPhase.app) {
      return BrotherDirectionAction.values
          .where(
            (e) =>
                e != BrotherDirectionAction.video &&
                e != BrotherDirectionAction.ratio &&
                e != BrotherDirectionAction.triggerDirection,
          )
          .toList(growable: false);
    }
    if (_brotherPhase == BrotherOrientationPhase.windowed && !resume) {
      return BrotherDirectionAction.values
          .where((e) => e != BrotherDirectionAction.triggerDirection)
          .toList(growable: false);
    }
    return BrotherDirectionAction.values;
  }

  List<BrotherRuntimeMode> get _brotherRuntimeValues =>
      BrotherRuntimeMode.values;

  String _brotherRuntimeLabel(BrotherRuntimeMode mode) =>
      _brotherPhase == BrotherOrientationPhase.app &&
          mode == BrotherRuntimeMode.appGravity
      ? '${mode.desc}（APP 普通页面不可用）'
      : mode.desc;

  Future<void> _editBrotherEnterAction() async {
    final phase = _brotherPhaseConfig;
    final res = await _pickEnum(
      title: '进入这个阶段时转到',
      value: phase.enterAction,
      values: _brotherActionValues(resume: false),
      label: (e) => e.desc,
    );
    if (res != null) await _writeBrotherPhase(phase.copyWith(enterAction: res));
  }

  Future<void> _editBrotherResumeAction() async {
    final phase = _brotherPhaseConfig;
    final res = await _pickEnum(
      title: '从更深一层返回时转到',
      value: phase.resumeAction,
      values: _brotherActionValues(resume: true),
      label: (e) => e.desc,
    );
    if (res != null) await _writeBrotherPhase(phase.copyWith(resumeAction: res));
  }

  Future<void> _editBrotherRuntimeMode() async {
    final phase = _brotherPhaseConfig;
    final res = await _pickEnum(
      title: '停留期间怎么旋转',
      value: phase.runtimeMode,
      values: _brotherRuntimeValues,
      label: _brotherRuntimeLabel,
    );
    if (res != null) await _writeBrotherPhase(phase.copyWith(runtimeMode: res));
  }

  Future<void> _editBrotherResumeRuntime(bool landscape) async {
    final phase = _brotherPhaseConfig;
    final current = landscape
        ? phase.resumeLandscapeRuntimeMode
        : phase.resumePortraitRuntimeMode;
    final res = await showDialog<int>(
      context: context,
      builder: (context) => SelectDialog<int>(
        title: landscape ? '以横屏返回时改用' : '以竖屏返回时改用',
        value: current?.index ?? -1,
        values: [
          (-1, '不改用，和「停留期间怎么旋转」相同'),
          for (final mode in _brotherRuntimeValues)
            (mode.index, _brotherRuntimeLabel(mode)),
        ],
      ),
    );
    if (res == null) return;
    await _writeBrotherPhase(
      phase.withResumeRuntime(
        landscape: landscape,
        mode: res < 0 ? null : BrotherRuntimeMode.values[res],
      ),
    );
  }

  Future<void> _editBrotherRuntimeLatchAxis() async {
    final phase = _brotherPhaseConfig;
    final res = await _pickEnum(
      title: '转到某个方向后切换旋转方式（只切一次）',
      value: phase.runtimeLatchAxis,
      values: BrotherRuntimeLatchAxis.values,
      label: (e) => e.desc,
    );
    if (res != null) {
      await _writeBrotherPhase(phase.copyWith(runtimeLatchAxis: res));
    }
  }

  Future<void> _editBrotherRuntimeLatchMode() async {
    final phase = _brotherPhaseConfig;
    final res = await _pickEnum(
      title: '切换后改用',
      value: phase.runtimeLatchMode,
      values: _brotherRuntimeValues,
      label: _brotherRuntimeLabel,
    );
    if (res != null) {
      await _writeBrotherPhase(phase.copyWith(runtimeLatchMode: res));
    }
  }

  Future<void> _editBrotherRuntimeActivation() async {
    final phase = _brotherPhaseConfig;
    final res = await _pickEnum(
      title: '什么时候开始按上面的方式旋转',
      value: phase.runtimeActivation,
      values: BrotherRuntimeActivation.values,
      label: (e) => e.desc,
    );
    if (res != null) {
      await _writeBrotherPhase(phase.copyWith(runtimeActivation: res));
    }
  }

  Future<void> _editBrotherAllowedBasis() async {
    final phase = _brotherPhaseConfig;
    final res = await _pickEnum(
      title: '允许转到哪些方向',
      value: phase.allowedBasis,
      values: BrotherAllowedBasis.values,
      label: (e) => e.desc,
    );
    if (res != null) await _writeBrotherPhase(phase.copyWith(allowedBasis: res));
  }

  String _directionMaskLabel(int mask) {
    if (mask == 0) return '空集';
    if (mask == OrientationMask.all) return '全部';
    return [
      if (mask & OrientationMask.portraitUp != 0) '正竖',
      if (mask & OrientationMask.portraitDown != 0) '倒竖',
      if (mask & OrientationMask.landscapeLeft != 0) '左横',
      if (mask & OrientationMask.landscapeRight != 0) '右横',
    ].join('、');
  }

  Future<int?> _directionMaskDialog({
    required String title,
    required int initial,
  }) async {
    var mask = initial;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget item(String title, int bit) => CheckboxListTile(
            title: Text(title),
            value: mask & bit != 0,
            onChanged: (value) => setDialogState(() {
              mask = value == true ? mask | bit : mask & ~bit;
            }),
          );
          return AlertDialog(
            title: Text(title),
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
  }

  Future<void> _editBrotherAllowedMask() async {
    final phase = _brotherPhaseConfig;
    final res = await _directionMaskDialog(
      title: '固定允许的方向',
      initial: phase.allowedMask,
    );
    if (res != null) await _writeBrotherPhase(phase.copyWith(allowedMask: res));
  }

  Future<void> _editBrotherAngle() async {
    final phase = _brotherPhaseConfig;
    final res = await showDialog<double>(
      context: context,
      builder: (context) => SliderDialog(
        title: const Text('APP 重力倾斜角度阈值'),
        min: 10,
        max: 90,
        divisions: 80,
        precise: 0,
        value: phase.angleDegrees.toDouble(),
        suffix: '°',
      ),
    );
    if (res != null) {
      await _writeBrotherPhase(phase.copyWith(angleDegrees: res.toInt()));
    }
  }

  String _signalMaskLabel(int mask) {
    final values = [
      if (mask & BrotherOrientationSignalMask.window != 0) '界面方向变化',
      if (mask & BrotherOrientationSignalMask.proposedSystem != 0)
        '系统建议方向变化',
      if (mask & BrotherOrientationSignalMask.appGravity != 0) 'APP 自己读到的重力方向变了',
    ];
    return values.isEmpty ? '无' : values.join(' + ');
  }

  Future<int?> _signalMaskDialog({
    required String title,
    required int initial,
  }) async {
    var mask = initial;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget item(String title, int bit) => CheckboxListTile(
            title: Text(title),
            value: mask & bit != 0,
            onChanged: (value) => setDialogState(() {
              mask = value == true ? mask | bit : mask & ~bit;
            }),
          );
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  item(
                    '界面方向变了（Flutter Metrics）',
                    BrotherOrientationSignalMask.window,
                  ),
                  item(
                    '系统建议旋转（Android 14 起；开着旋转锁定也会提示）',
                    BrotherOrientationSignalMask.proposedSystem,
                  ),
                  item(
                    'APP 自己读到的重力方向变了',
                    BrotherOrientationSignalMask.appGravity,
                  ),
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
  }

  Future<int?> _nonNegativeIntDialog({
    required String title,
    required int initial,
    String helper = '非负整数；不设上限',
  }) async {
    final controller = TextEditingController(text: initial.toString());
    final res = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(helperText: helper),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          TextButton(
            onPressed: () => Get.back(result: int.tryParse(controller.text)),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return res;
  }

  Future<void> _writeBrotherValue(String key, Object value) async {
    await GStorage.setting.put(key, value);
    await OrientationPolicy.compile();
    if (mounted) setState(() {});
  }

  Future<void> _toggleBrotherMaskBit(
    String key,
    int current,
    int bit,
    bool enabled,
  ) => _writeBrotherValue(key, enabled ? current | bit : current & ~bit);

  Future<void> _editSignalMask(String key, int current, String title) async {
    final res = await _signalMaskDialog(title: title, initial: current);
    if (res != null) await _writeBrotherValue(key, res);
  }

  Future<void> _editRequiredCount(
    String key,
    int current,
    String title,
  ) async {
    final res = await _nonNegativeIntDialog(
      title: title,
      initial: current,
      helper: '填 0 表示不看信号、总是满足；填得比选中的信号还多，就永远不会触发。不会自动帮您改。',
    );
    if (res != null) await _writeBrotherValue(key, res);
  }

  Widget _brotherBitSwitch({
    required String title,
    required String key,
    required int current,
    required int bit,
    String? subtitle,
  }) => SwitchListTile(
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    value: current & bit != 0,
    onChanged: (value) =>
        _toggleBrotherMaskBit(key, current, bit, value),
  );

  List<Widget> _brotherPhaseTemplate() {
    final phase = _brotherPhaseConfig;
    return [
      _section(_brotherPhase.desc),
      _selectTile(
        title: '进入这个阶段时转到',
        subtitle: phase.enterAction.desc,
        onTap: _editBrotherEnterAction,
      ),
      if (_brotherPhase != BrotherOrientationPhase.fullscreen)
        _selectTile(
          title: '从更深一层返回时转到',
          subtitle: phase.resumeAction.desc,
          onTap: _editBrotherResumeAction,
        ),
      _selectTile(
        title: '停留期间怎么旋转',
        subtitle: _brotherRuntimeLabel(phase.runtimeMode),
        onTap: _editBrotherRuntimeMode,
      ),
      if (_brotherPhase != BrotherOrientationPhase.fullscreen) ...[
        _selectTile(
          title: '以横屏返回时改用',
          subtitle: phase.resumeLandscapeRuntimeMode == null
              ? '不改用，和「停留期间怎么旋转」相同'
              : _brotherRuntimeLabel(phase.resumeLandscapeRuntimeMode!),
          onTap: () => _editBrotherResumeRuntime(true),
        ),
        _selectTile(
          title: '以竖屏返回时改用',
          subtitle: phase.resumePortraitRuntimeMode == null
              ? '不改用，和「停留期间怎么旋转」相同'
              : _brotherRuntimeLabel(phase.resumePortraitRuntimeMode!),
          onTap: () => _editBrotherResumeRuntime(false),
        ),
      ],
      if (_brotherPhase == BrotherOrientationPhase.app) ...[
        _selectTile(
          title: '转到某个方向后切换旋转方式（只切一次）',
          subtitle: phase.runtimeLatchAxis.desc,
          onTap: _editBrotherRuntimeLatchAxis,
        ),
        if (phase.runtimeLatchAxis != BrotherRuntimeLatchAxis.off)
          _selectTile(
            title: '切换后改用',
            subtitle: _brotherRuntimeLabel(phase.runtimeLatchMode),
            onTap: _editBrotherRuntimeLatchMode,
          ),
      ],
      if (_brotherPhase != BrotherOrientationPhase.app)
        _selectTile(
          title: '什么时候开始按上面的方式旋转',
          subtitle: phase.runtimeActivation.desc,
          onTap: _editBrotherRuntimeActivation,
        ),
      _selectTile(
        title: '允许转到哪些方向',
        subtitle: phase.allowedBasis.desc,
        onTap: _editBrotherAllowedBasis,
      ),
      _selectTile(
        title: '固定允许的方向',
        subtitle: '${_directionMaskLabel(phase.allowedMask)}${phase.allowedBasis == BrotherAllowedBasis.fixed ? '' : '（上一项没选「固定」，此项不生效）'}',
        onTap: _editBrotherAllowedMask,
      ),
      if (_brotherPhase != BrotherOrientationPhase.app) ...[
        SwitchListTile(
          title: const Text('APP 重力遵循系统方向锁定'),
          subtitle: const Text('只在用到「APP 自己读重力」时生效：开着旋转锁定就不按重力转'),
          value: phase.gravityFollowSystemLock,
          onChanged: (value) => _writeBrotherPhase(
            phase.copyWith(gravityFollowSystemLock: value),
          ),
        ),
        _selectTile(
          title: 'APP 重力倾斜角度阈值',
          subtitle: '${phase.angleDegrees}°',
          onTap: _editBrotherAngle,
        ),
      ],
    ];
  }

  Future<void> _editBrotherEntryOverride(
    FullscreenEntryCause cause,
    BrotherDirectionAction current,
    String title,
  ) async {
    final res = await _pickEnum(
      title: title,
      value: current,
      values: BrotherDirectionAction.values,
      label: (e) => e.desc,
    );
    if (res == null) return;
    final key = switch (cause) {
      FullscreenEntryCause.manual => SettingBoxKey.brotherFullscreenManualEnter,
      FullscreenEntryCause.playbackAuto =>
        SettingBoxKey.brotherFullscreenPlaybackEnter,
      FullscreenEntryCause.orientation =>
        SettingBoxKey.brotherFullscreenOrientationEnter,
    };
    await _writeBrotherValue(key, res.index);
  }

  Future<void> _editBrotherResumeOverride(
    FullscreenExitCause cause,
    BrotherDirectionAction current,
    String title,
  ) async {
    final res = await _pickEnum(
      title: title,
      value: current,
      values: BrotherDirectionAction.values,
      label: (e) => e.desc,
    );
    if (res == null) return;
    final key = switch (cause) {
      FullscreenExitCause.manual => SettingBoxKey.brotherWindowedManualResume,
      FullscreenExitCause.playbackAuto =>
        SettingBoxKey.brotherWindowedPlaybackResume,
      FullscreenExitCause.orientation =>
        SettingBoxKey.brotherWindowedOrientationResume,
    };
    await _writeBrotherValue(key, res.index);
  }

  List<Widget> _brotherWindowedSpecial() {
    final overrideMask = Pref.brotherWindowedResumeOverrideMask;
    return [
      _section('视频非全屏：自动进入全屏、退出后转到哪'),
      SwitchListTile(
        title: const Text('横置时自动进入全屏'),
        value: Pref.brotherLandscapeEnter,
        onChanged: (value) =>
            _writeBrotherValue(SettingBoxKey.brotherLandscapeEnter, value),
      ),
      _selectTile(
        title: '用哪些信号判断「手机横过来了」',
        subtitle: _signalMaskLabel(Pref.brotherEnterSignalMask),
        onTap: () => _editSignalMask(
          SettingBoxKey.brotherEnterSignalMask,
          Pref.brotherEnterSignalMask,
          '用哪些信号判断「手机横过来了」',
        ),
      ),
      _selectTile(
        title: '至少几个信号同时满足才进入全屏',
        subtitle: '${Pref.brotherEnterSignalRequired}',
        onTap: () => _editRequiredCount(
          SettingBoxKey.brotherEnterSignalRequired,
          Pref.brotherEnterSignalRequired,
          '至少几个信号同时满足才进入全屏',
        ),
      ),
      _selectTile(
        title: '哪些视频会自动进入全屏',
        subtitle: Pref.brotherEnterTriggerContent.desc,
        onTap: () async {
          final res = await _pickEnum(
            title: '哪些视频会自动进入全屏',
            value: Pref.brotherEnterTriggerContent,
            values: OrientationTriggerContent.values,
            label: (e) => e.desc,
          );
          if (res != null) {
            await _writeBrotherValue(
              SettingBoxKey.brotherEnterTriggerContent,
              res.index,
            );
          }
        },
      ),
      const Divider(),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text('退出全屏回到非全屏时，可以按退出的原因分别指定转到哪个方向，代替上面的「从更深一层返回时转到」。'),
      ),
      _brotherBitSwitch(
        title: '手动退出全屏时单独指定方向',
        key: SettingBoxKey.brotherWindowedResumeOverrideMask,
        current: overrideMask,
        bit: FullscreenExitCauseMask.manual,
      ),
      _selectTile(
        title: '手动退出全屏后转到',
        subtitle: '${Pref.brotherWindowedManualResume.desc}${overrideMask & FullscreenExitCauseMask.manual == 0 ? '（未单独指定，按上面的设置）' : ''}',
        onTap: () => _editBrotherResumeOverride(
          FullscreenExitCause.manual,
          Pref.brotherWindowedManualResume,
          '手动退出全屏后转到',
        ),
      ),
      _brotherBitSwitch(
        title: '播放结束自动退出时单独指定方向',
        key: SettingBoxKey.brotherWindowedResumeOverrideMask,
        current: overrideMask,
        bit: FullscreenExitCauseMask.playbackAuto,
      ),
      _selectTile(
        title: '播放结束自动退出后转到',
        subtitle: '${Pref.brotherWindowedPlaybackResume.desc}${overrideMask & FullscreenExitCauseMask.playbackAuto == 0 ? '（未单独指定，按上面的设置）' : ''}',
        onTap: () => _editBrotherResumeOverride(
          FullscreenExitCause.playbackAuto,
          Pref.brotherWindowedPlaybackResume,
          '播放结束自动退出后转到',
        ),
      ),
      _brotherBitSwitch(
        title: '竖过来自动退出时单独指定方向',
        key: SettingBoxKey.brotherWindowedResumeOverrideMask,
        current: overrideMask,
        bit: FullscreenExitCauseMask.orientation,
      ),
      _selectTile(
        title: '竖过来自动退出后转到',
        subtitle: '${Pref.brotherWindowedOrientationResume.desc}${overrideMask & FullscreenExitCauseMask.orientation == 0 ? '（未单独指定，按上面的设置）' : ''}',
        onTap: () => _editBrotherResumeOverride(
          FullscreenExitCause.orientation,
          Pref.brotherWindowedOrientationResume,
          '竖过来自动退出后转到',
        ),
      ),
    ];
  }

  List<Widget> _brotherFullscreenSpecial() {
    final enterMask = Pref.brotherFullscreenEnterOverrideMask;
    final exitCauses = Pref.brotherAutoExitCauses;
    return [
      _section('视频全屏：进入时转到哪、自动退出全屏'),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Text('进入全屏时，可以按进入的原因分别指定转到哪个方向，代替上面的「进入这个阶段时转到」。'),
      ),
      _brotherBitSwitch(
        title: '手动进入全屏时单独指定方向',
        key: SettingBoxKey.brotherFullscreenEnterOverrideMask,
        current: enterMask,
        bit: FullscreenEntryCauseMask.manual,
      ),
      _selectTile(
        title: '手动进入全屏时转到',
        subtitle: '${Pref.brotherFullscreenManualEnter.desc}${enterMask & FullscreenEntryCauseMask.manual == 0 ? '（未单独指定，按上面的设置）' : ''}',
        onTap: () => _editBrotherEntryOverride(
          FullscreenEntryCause.manual,
          Pref.brotherFullscreenManualEnter,
          '手动进入全屏时转到',
        ),
      ),
      _brotherBitSwitch(
        title: '播放开始自动进入时单独指定方向',
        key: SettingBoxKey.brotherFullscreenEnterOverrideMask,
        current: enterMask,
        bit: FullscreenEntryCauseMask.playbackAuto,
      ),
      _selectTile(
        title: '播放开始自动进入全屏时转到',
        subtitle: '${Pref.brotherFullscreenPlaybackEnter.desc}${enterMask & FullscreenEntryCauseMask.playbackAuto == 0 ? '（未单独指定，按上面的设置）' : ''}',
        onTap: () => _editBrotherEntryOverride(
          FullscreenEntryCause.playbackAuto,
          Pref.brotherFullscreenPlaybackEnter,
          '播放开始自动进入全屏时转到',
        ),
      ),
      _brotherBitSwitch(
        title: '横过来自动进入时单独指定方向',
        key: SettingBoxKey.brotherFullscreenEnterOverrideMask,
        current: enterMask,
        bit: FullscreenEntryCauseMask.orientation,
      ),
      _selectTile(
        title: '横过来自动进入全屏时转到',
        subtitle: '${Pref.brotherFullscreenOrientationEnter.desc}${enterMask & FullscreenEntryCauseMask.orientation == 0 ? '（未单独指定，按上面的设置）' : ''}',
        onTap: () => _editBrotherEntryOverride(
          FullscreenEntryCause.orientation,
          Pref.brotherFullscreenOrientationEnter,
          '横过来自动进入全屏时转到',
        ),
      ),
      const Divider(),
      SwitchListTile(
        title: const Text('竖置时自动退出全屏'),
        value: Pref.brotherPortraitExit,
        onChanged: (value) =>
            _writeBrotherValue(SettingBoxKey.brotherPortraitExit, value),
      ),
      _selectTile(
        title: '用哪些信号判断「手机竖回来了」',
        subtitle: _signalMaskLabel(Pref.brotherExitSignalMask),
        onTap: () => _editSignalMask(
          SettingBoxKey.brotherExitSignalMask,
          Pref.brotherExitSignalMask,
          '用哪些信号判断「手机竖回来了」',
        ),
      ),
      _selectTile(
        title: '至少几个信号同时满足才退出全屏',
        subtitle: '${Pref.brotherExitSignalRequired}',
        onTap: () => _editRequiredCount(
          SettingBoxKey.brotherExitSignalRequired,
          Pref.brotherExitSignalRequired,
          '至少几个信号同时满足才退出全屏',
        ),
      ),
      _selectTile(
        title: '哪些视频会自动退出全屏',
        subtitle: Pref.brotherExitTriggerContent.desc,
        onTap: () async {
          final res = await _pickEnum(
            title: '哪些视频会自动退出全屏',
            value: Pref.brotherExitTriggerContent,
            values: OrientationTriggerContent.values,
            label: (e) => e.desc,
          );
          if (res != null) {
            await _writeBrotherValue(
              SettingBoxKey.brotherExitTriggerContent,
              res.index,
            );
          }
        },
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 2),
        child: Text('竖过来自动退出全屏，只对以下方式进入的全屏生效：'),
      ),
      _brotherBitSwitch(
        title: '手动进入的全屏',
        key: SettingBoxKey.brotherAutoExitCauses,
        current: exitCauses,
        bit: FullscreenEntryCauseMask.manual,
      ),
      _brotherBitSwitch(
        title: '播放自动进入的全屏',
        key: SettingBoxKey.brotherAutoExitCauses,
        current: exitCauses,
        bit: FullscreenEntryCauseMask.playbackAuto,
      ),
      _brotherBitSwitch(
        title: '方向触发进入的全屏',
        key: SettingBoxKey.brotherAutoExitCauses,
        current: exitCauses,
        bit: FullscreenEntryCauseMask.orientation,
      ),
      _selectTile(
        title: '手动全屏退出确认次数',
        subtitle: Pref.brotherManualExitConfirmations == 0
            ? '关闭'
            : '${Pref.brotherManualExitConfirmations} 次',
        onTap: () async {
          final res = await _nonNegativeIntDialog(
            title: '手动全屏退出确认次数',
            initial: Pref.brotherManualExitConfirmations,
            helper: '0 = 关闭；不设上限',
          );
          if (res != null) {
            await _writeBrotherValue(
              SettingBoxKey.brotherManualExitConfirmations,
              res,
            );
          }
        },
      ),
      _selectTile(
        title: '手动退出确认信号',
        subtitle: _signalMaskLabel(Pref.brotherManualExitSignalMask),
        onTap: () => _editSignalMask(
          SettingBoxKey.brotherManualExitSignalMask,
          Pref.brotherManualExitSignalMask,
          '手动退出确认信号',
        ),
      ),
      _selectTile(
        title: '手动退出确认最少满足信号数',
        subtitle: '${Pref.brotherManualExitSignalRequired}',
        onTap: () => _editRequiredCount(
          SettingBoxKey.brotherManualExitSignalRequired,
          Pref.brotherManualExitSignalRequired,
          '手动退出确认最少满足信号数',
        ),
      ),
    ];
  }

  List<Widget> _brotherSettings() => [
    _section('哥哥科技模式'),
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        '分三个阶段：APP 普通页面、视频非全屏、视频全屏，三个阶段的选项完全相同。'
        '每个阶段管三件事：刚进入时转到哪个方向、从更深一层返回时转到哪个方向、停留期间怎么跟着手机转。'
        '系统无法直接实现的组合也照您的选择执行，不会被自动改掉。',
      ),
    ),
    _selectTile(
      title: '阶段',
      subtitle: _brotherPhase.desc,
      onTap: () async {
        final res = await _pickEnum(
          title: '阶段',
          value: _brotherPhase,
          values: BrotherOrientationPhase.values,
          label: (e) => e.desc,
        );
        if (res != null && mounted) setState(() => _brotherPhase = res);
      },
    ),
    ..._brotherPhaseTemplate(),
    if (_brotherPhase == BrotherOrientationPhase.windowed)
      ..._brotherWindowedSpecial(),
    if (_brotherPhase == BrotherOrientationPhase.fullscreen)
      ..._brotherFullscreenSpecial(),
    _section('诊断：当前设置会启用哪些监听'),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SelectableText(
        BrotherOrientationDiagnostics.describe(
          BrotherDiagnosticsCompiler.compile(OrientationPolicy.brotherPlan),
        ),
      ),
    ),
  ];

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
      title: '手动进入全屏时转到',
      subtitle: Pref.advancedManualEntryOrientation.desc,
      onTap: () => _select(
        title: '手动进入全屏时转到',
        value: Pref.advancedManualEntryOrientation,
        values: EntryOrientationPolicy.values
            .where((e) => e != EntryOrientationPolicy.triggerDirection)
            .toList(growable: false),
        key: SettingBoxKey.advancedManualEntryOrientation,
        label: (e) => e.desc,
      ),
    ),
    _selectTile(
      title: '播放开始自动进入全屏时转到',
      subtitle: Pref.advancedAutoEntryOrientation.desc,
      onTap: () => _select(
        title: '播放开始自动进入全屏时转到',
        value: Pref.advancedAutoEntryOrientation,
        values: EntryOrientationPolicy.values
            .where((e) => e != EntryOrientationPolicy.triggerDirection)
            .toList(growable: false),
        key: SettingBoxKey.advancedAutoEntryOrientation,
        label: (e) => e.desc,
      ),
    ),
    _selectTile(
      title: '横过来自动进入全屏时转到',
      subtitle: Pref.advancedOrientationEntryOrientation.desc,
      onTap: () => _select(
        title: '横过来自动进入全屏时转到',
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
      subtitle: _autoExitCausesLabel(Pref.advancedAutoExitCauses),
      onTap: _showAutoExitCausesDialog,
    ),
    _selectTile(
      title: '手动全屏退出确认次数',
      subtitle: Pref.advancedManualExitConfirmations == 0
          ? '关闭'
          : '${Pref.advancedManualExitConfirmations} 次',
      onTap: _showManualExitConfirmationsDialog,
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
            SetSwitchItem(
              title: '竖屏播放页移除安全边距',
              subtitle: '公共布局设置；仅影响播放页竖屏',
              setKey: SettingBoxKey.removeSafeAreaPortrait,
              defaultVal: Pref.removeSafeAreaPortrait,
            ),
            SetSwitchItem(
              title: '横屏播放页移除安全边距',
              subtitle: '公共布局设置；仅影响播放页横屏',
              setKey: SettingBoxKey.removeSafeAreaLandscape,
              defaultVal: Pref.removeSafeAreaLandscape,
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
              ...switch (mode) {
                OrientationPolicyMode.simple => _simpleSettings(),
                OrientationPolicyMode.advanced => _advancedSettings(),
                OrientationPolicyMode.brotherTech => _brotherSettings(),
              },
            ],
          ],
        ),
      ),
    );
  }
}
