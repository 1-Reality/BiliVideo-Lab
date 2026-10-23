import 'dart:math';

import 'package:PiliBro/common/widgets/flutter/list_tile.dart';
import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/common/widgets/view_safe_area.dart';
import 'package:PiliBro/pages/setting/widgets/switch_item.dart';
import 'package:PiliBro/plugin/pl_player/controller.dart';
import 'package:PiliBro/plugin/pl_player/widgets/speed_panel.dart';
import 'package:PiliBro/utils/extension/context_ext.dart';
import 'package:PiliBro/utils/filtering_text.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class PlaySpeedPage extends StatefulWidget {
  const PlaySpeedPage({super.key});

  @override
  State<PlaySpeedPage> createState() => _PlaySpeedPageState();
}

class _PlaySpeedPageState extends State<PlaySpeedPage> {
  late double playSpeedDefault = Pref.playSpeedDefault;
  late double longPressSpeedDefault = Pref.longPressSpeedDefault;
  late List<double> speedList = Pref.speedList;
  late bool enableAutoLongPressSpeed = Pref.enableAutoLongPressSpeed;
  late double longPressSpeedFactor = Pref.longPressSpeedFactor;
  late bool enableLongPressSlideSpeed = Pref.enableLongPressSlideSpeed;
  late int gridCols = Pref.speedGridCols;
  late int gridColsLandscape = Pref.speedGridColsLandscape;
  late bool gridManual = Pref.speedGridManual;
  late int sliderMin = Pref.speedSliderMin;
  late int sliderMax = Pref.speedSliderMax;
  late int speedStep = Pref.speedStep;
  late bool wheelSpeed = Pref.wheelSpeed;
  late bool arrowKeySpeed = Pref.arrowKeySpeed;
  List<({int id, String title, Icon icon})> sheetMenu = [
    (
      id: 1,
      title: '设置为默认倍速',
      icon: const Icon(
        Icons.speed,
        size: 21,
      ),
    ),
    (
      id: 2,
      title: '设置为默认长按倍速',
      icon: const Icon(
        Icons.speed_sharp,
        size: 21,
      ),
    ),
    (
      id: -1,
      title: '删除该项',
      icon: const Icon(
        Icons.delete_outline,
        size: 21,
      ),
    ),
  ];

  Box video = GStorage.video;

  void _updateLongPressSpeedFactor(double value) {
    longPressSpeedFactor = value;
    PlPlayerController.instance?.longPressSpeedFactor = value;
    if (mounted) setState(() {});
  }

  Future<void> _saveLongPressSpeedFactor(double value) async {
    _updateLongPressSpeedFactor(value);
    await GStorage.setting.put(SettingBoxKey.longPressSpeedFactor, value);
  }

  Future<void> _inputLongPressSpeedFactor() async {
    var value = longPressSpeedFactor.toString();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义长按倍速系数'),
        content: TextFormField(
          autofocus: true,
          initialValue: value,
          keyboardType: const .numberWithOptions(decimal: true),
          inputFormatters: FilteringText.decimal,
          decoration: const InputDecoration(
            suffixText: '倍',
            border: OutlineInputBorder(borderRadius: .all(.circular(6))),
          ),
          onChanged: (text) => value = text,
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(value);
              if (parsed == null || parsed <= 0) {
                SmartDialog.showToast('请输入大于 0 的数值');
                return;
              }
              Get.back(result: parsed);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result != null) await _saveLongPressSpeedFactor(result);
  }

  // 倍速列表变动后同步给播放器；列数没手动指定时按近正方形重算：竖屏向下取整、横屏向上取整
  void _onSpeedListChanged() {
    final player = PlPlayerController.instance?..speedList = speedList;
    if (gridManual) return;
    final n = speedList.length;
    gridCols = sqrt(n).toInt();
    gridColsLandscape = sqrt(n - 1).toInt() + 1;
    GStorage.setting.putAll({
      SettingBoxKey.speedGridCols: gridCols,
      SettingBoxKey.speedGridColsLandscape: gridColsLandscape,
    });
    player
      ?..speedGridCols = gridCols
      ..speedGridColsLandscape = gridColsLandscape;
  }

  Future<void> _setGridCols() async {
    var portrait = '$gridCols';
    var landscape = '$gridColsLandscape';
    // (0, 0) 表示恢复自动
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('矩阵列数'),
        content: Column(
          spacing: 16,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              autofocus: true,
              initialValue: portrait,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '竖屏',
                suffixText: '列',
                border: OutlineInputBorder(borderRadius: .all(.circular(6))),
              ),
              onChanged: (text) => portrait = text,
            ),
            TextFormField(
              initialValue: landscape,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '横屏',
                suffixText: '列',
                border: OutlineInputBorder(borderRadius: .all(.circular(6))),
              ),
              onChanged: (text) => landscape = text,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          TextButton(
            onPressed: () => Get.back(result: (0, 0)),
            child: const Text('自动'),
          ),
          TextButton(
            onPressed: () {
              final p = int.tryParse(portrait) ?? 0;
              final l = int.tryParse(landscape) ?? 0;
              if (p < 1 || l < 1) {
                SmartDialog.showToast('列数至少为 1');
                return;
              }
              Get.back(result: (p, l));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == null) return;
    gridManual = result.$1 != 0;
    GStorage.setting.put(SettingBoxKey.speedGridManual, gridManual);
    if (gridManual) {
      gridCols = result.$1;
      gridColsLandscape = result.$2;
      GStorage.setting.putAll({
        SettingBoxKey.speedGridCols: gridCols,
        SettingBoxKey.speedGridColsLandscape: gridColsLandscape,
      });
      PlPlayerController.instance
        ?..speedGridCols = gridCols
        ..speedGridColsLandscape = gridColsLandscape;
    } else {
      _onSpeedListChanged();
    }
    setState(() {});
  }

  Future<void> _setSliderRange() async {
    var minText = formatCenti(sliderMin);
    var maxText = formatCenti(sliderMax);
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('滑杆范围'),
        content: Column(
          spacing: 16,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              autofocus: true,
              initialValue: minText,
              keyboardType: const .numberWithOptions(decimal: true),
              inputFormatters: FilteringText.decimal,
              decoration: const InputDecoration(
                labelText: '最小',
                suffixText: '倍',
                border: OutlineInputBorder(borderRadius: .all(.circular(6))),
              ),
              onChanged: (text) => minText = text,
            ),
            TextFormField(
              initialValue: maxText,
              keyboardType: const .numberWithOptions(decimal: true),
              inputFormatters: FilteringText.decimal,
              decoration: const InputDecoration(
                labelText: '最大',
                suffixText: '倍',
                border: OutlineInputBorder(borderRadius: .all(.circular(6))),
              ),
              onChanged: (text) => maxText = text,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          TextButton(
            onPressed: () {
              // 两端对齐到 0.1，滑杆步长 0.1
              final lo = ((double.tryParse(minText) ?? 0) * 10).round() * 10;
              final hi = ((double.tryParse(maxText) ?? 0) * 10).round() * 10;
              if (lo < 10 || hi <= lo) {
                SmartDialog.showToast('最小至少 0.1，且最大要大于最小');
                return;
              }
              Get.back(result: (lo, hi));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == null) return;
    sliderMin = result.$1;
    sliderMax = result.$2;
    final divisions = (sliderMax - sliderMin) ~/ 10;
    GStorage.setting.putAll({
      SettingBoxKey.speedSliderMin: sliderMin,
      SettingBoxKey.speedSliderMax: sliderMax,
      SettingBoxKey.speedSliderDivisions: divisions,
    });
    PlPlayerController.instance
      ?..speedSliderMin = sliderMin
      ..speedSliderMax = sliderMax
      ..speedSliderDivisions = divisions;
    setState(() {});
  }

  Future<void> _setSpeedInput() async {
    var stepText = formatCenti(speedStep);
    var wheel = wheelSpeed;
    var arrowKey = arrowKeySpeed;
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('滚轮 / 方向键调倍速'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: stepText,
                keyboardType: const .numberWithOptions(decimal: true),
                inputFormatters: FilteringText.decimal,
                decoration: const InputDecoration(
                  labelText: '分度值',
                  suffixText: '倍',
                  border: OutlineInputBorder(borderRadius: .all(.circular(6))),
                ),
                onChanged: (text) => stepText = text,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('鼠标滚轮调倍速'),
                value: wheel,
                onChanged: (value) => setDialogState(() => wheel = value!),
              ),
              CheckboxListTile(
                title: const Text('键盘上下键调倍速'),
                value: arrowKey,
                onChanged: (value) => setDialogState(() => arrowKey = value!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('取消')),
            TextButton(
              onPressed: () {
                final step = ((double.tryParse(stepText) ?? 0) * 100).round();
                if (step < 1) {
                  SmartDialog.showToast('分度值至少 0.01');
                  return;
                }
                Get.back(result: step);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    speedStep = result;
    wheelSpeed = wheel;
    arrowKeySpeed = arrowKey;
    GStorage.setting.putAll({
      SettingBoxKey.speedStep: speedStep,
      SettingBoxKey.wheelSpeed: wheelSpeed,
      SettingBoxKey.arrowKeySpeed: arrowKeySpeed,
    });
    PlPlayerController.instance
      ?..speedStep = speedStep
      ..wheelSpeed = wheelSpeed
      ..arrowKeySpeed = arrowKeySpeed;
    setState(() {});
  }

  // 添加自定义倍速
  void onAddSpeed() {
    String initialValue = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加倍速'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            TextFormField(
              autofocus: true,
              initialValue: initialValue,
              keyboardType: const .numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '自定义倍速',
                border: OutlineInputBorder(borderRadius: .all(.circular(6))),
              ),
              onChanged: (value) => initialValue = value,
              inputFormatters: FilteringText.decimal,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () {
              try {
                final val = double.parse(initialValue);
                if (speedList.contains(val)) {
                  SmartDialog.showToast('该倍速已存在');
                } else {
                  Get.back();
                  speedList
                    ..add(val)
                    ..sort();
                  video.put(VideoBoxKey.speedsList, speedList);
                  _onSpeedListChanged();
                  setState(() {});
                }
              } catch (e) {
                SmartDialog.showToast(e.toString());
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  // 设定倍速弹窗
  void showBottomSheet(ThemeData theme, int index) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      clipBehavior: Clip.hardEdge,
      constraints: BoxConstraints(
        maxWidth: min(640, context.mediaQueryShortestSide),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            ...sheetMenu.map(
              (item) => ListTile(
                enabled: enableAutoLongPressSpeed && item.id == 2
                    ? false
                    : true,
                onTap: () {
                  Get.back();
                  menuAction(index, item.id);
                },
                minLeadingWidth: 0,
                iconColor: theme.colorScheme.onSurface,
                leading: item.icon,
                title: Text(
                  item.title,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            SizedBox(height: 25 + MediaQuery.viewPaddingOf(context).bottom),
          ],
        );
      },
    );
  }

  //
  void menuAction(int index, int id) {
    double speed = speedList[index];
    // 设置
    if (id == 1) {
      // 设置默认倍速
      playSpeedDefault = speed;
      video.put(VideoBoxKey.playSpeedDefault, playSpeedDefault);
    } else if (id == 2) {
      // 设置默认长按倍速
      longPressSpeedDefault = speed;
      video.put(VideoBoxKey.longPressSpeedDefault, longPressSpeedDefault);
    } else if (id == -1) {
      if ([
        1.0,
        playSpeedDefault,
        longPressSpeedDefault,
      ].contains(speed)) {
        SmartDialog.showToast('不支持删除默认倍速');
        return;
      }
      speedList.removeAt(index);
      video.put(VideoBoxKey.speedsList, speedList);
      _onSpeedListChanged();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('倍速设置'),
        actions: [
          TextButton(
            onPressed: () async {
              await video.delete(VideoBoxKey.speedsList);
              speedList = Pref.speedList;
              _onSpeedListChanged();
              setState(() {});
            },
            child: const Text('重置'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ViewSafeArea(
        child: ListView(
          padding: .only(
            bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 14,
                right: 14,
                top: 6,
                bottom: 0,
              ),
              child: Text(
                '点击下方按钮设置默认（长按）倍速',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ),
            ListTile(
              title: const Text('默认倍速'),
              subtitle: Text(playSpeedDefault.toString()),
            ),
            SetSwitchItem(
              title: '动态长按倍速',
              subtitle: '长按时使用当前倍速乘以自定义系数',
              setKey: SettingBoxKey.enableAutoLongPressSpeed,
              defaultVal: enableAutoLongPressSpeed,
              onChanged: (val) {
                enableAutoLongPressSpeed = val;
                PlPlayerController.instance?.enableAutoLongPressSpeed = val;
                setState(() {});
              },
            ),
            if (enableAutoLongPressSpeed) ...[
              ListTile(
                title: const Text('长按倍速系数'),
                subtitle: Text(
                  '$longPressSpeedFactor 倍（${(longPressSpeedFactor * 100).round()}%）',
                ),
                trailing: TextButton(
                  onPressed: _inputLongPressSpeedFactor,
                  child: const Text('手动输入'),
                ),
              ),
              Slider(
                value: longPressSpeedFactor.clamp(0.5, 3.0),
                min: 0.5,
                max: 3,
                divisions: 10,
                label:
                    '${(longPressSpeedFactor.clamp(0.5, 3.0) * 100).round()}%',
                onChanged: _updateLongPressSpeedFactor,
                onChangeEnd: _saveLongPressSpeedFactor,
              ),
            ],
            if (!enableAutoLongPressSpeed)
              ListTile(
                title: const Text('默认长按倍速'),
                subtitle: Text(longPressSpeedDefault.toString()),
              ),
            SetSwitchItem(
              title: '长按时上下滑动调整临时倍速',
              subtitle: '向上加速、向下减速，每档 0.25 倍；松手后恢复原倍速',
              setKey: SettingBoxKey.enableLongPressSlideSpeed,
              defaultVal: enableLongPressSlideSpeed,
              onChanged: (value) {
                enableLongPressSlideSpeed = value;
                PlPlayerController.instance?.enableLongPressSlideSpeed = value;
              },
            ),
            SetSwitchItem(
              title: '滑杆式倍速面板',
              subtitle: '关闭时为矩阵面板，矩阵下方附带 1.5 倍宽的小滑杆',
              setKey: SettingBoxKey.speedPanelSlider,
              onChanged: (value) =>
                  PlPlayerController.instance?.speedPanelSlider = value,
            ),
            ListTile(
              title: const Text('矩阵列数'),
              subtitle: Text(
                '竖屏 $gridCols 列，横屏 $gridColsLandscape 列${gridManual ? '' : '，随倍速列表自动计算'}',
              ),
              onTap: _setGridCols,
            ),
            ListTile(
              title: const Text('滑杆范围'),
              subtitle: Text(
                '${formatCenti(sliderMin)} ~ ${formatCenti(sliderMax)} 倍，步长 0.1',
              ),
              onTap: _setSliderRange,
            ),
            ListTile(
              title: const Text('滚轮 / 方向键调倍速'),
              subtitle: Text(
                wheelSpeed || arrowKeySpeed
                    ? '${wheelSpeed && arrowKeySpeed ? '滚轮和上下键' : wheelSpeed ? '滚轮' : '上下键'}调倍速，每次 ${formatCenti(speedStep)} 倍'
                    : '关闭，滚轮和上下键调音量',
              ),
              onTap: _setSpeedInput,
            ),
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('倍速时间统计'),
              subtitle: const Text('查看最常用倍速、实际节约时间、倒带回看与高级参数'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed('/playbackStats'),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 14,
                right: 14,
                bottom: 10,
                top: 20,
              ),
              child: Row(
                children: [
                  Text(
                    '倍速列表',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onAddSpeed,
                    child: const Text('添加'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 18,
                right: 18,
                bottom: 30,
              ),
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: 8,
                runSpacing: 2,
                children: List.generate(
                  speedList.length,
                  (index) => FilledButton.tonal(
                    style: FilledButton.styleFrom(tapTargetSize: .padded),
                    onPressed: () => showBottomSheet(theme, index),
                    child: Text(speedList[index].toString()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
