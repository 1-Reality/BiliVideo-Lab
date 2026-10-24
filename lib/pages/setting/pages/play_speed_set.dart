import 'dart:math';

import 'package:PiliBro/common/widgets/flutter/list_tile.dart';
import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/common/widgets/stateful_builder.dart';
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
import 'package:material_ui/material_ui.dart' hide ListTile, StatefulBuilder;

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
  late double gridWidth = Pref.speedGridWidth;
  late double gridWidthLandscape = Pref.speedGridWidthLandscape;
  late double sliderWidth = Pref.speedSliderWidth;
  late int sliderMin = Pref.speedSliderMin;
  late int sliderMax = Pref.speedSliderMax;
  late int sliderStep = Pref.speedSliderStep;
  late int panelLayout = Pref.speedPanelLayout;
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

  // 自动宽度：矩阵不到 6 列给 280，否则每列 56；滑杆每 1 倍 80，
  // 分度值小于 0.1 时再放宽 1.5 倍，不窄于 280，取 56 的整数倍
  static double _autoGridWidth(int cols) => cols < 6 ? 280 : cols * 56.0;

  static double _autoSliderWidth(int span, int step) {
    final raw = span * (step < 10 ? 1.2 : 0.8);
    return raw <= 280 ? 280 : (raw / 56).ceil() * 56.0;
  }

  static const _border = OutlineInputBorder(borderRadius: .all(.circular(6)));

  // 矩阵宽度变了行高同比缩放，最矮 32 保证好点
  void _saveGrid(int cols, int colsLandscape, double width, double widthL) {
    final rowHeight = max(32.0, 36 * width / _autoGridWidth(cols));
    final rowHeightL = max(32.0, 36 * widthL / _autoGridWidth(colsLandscape));
    gridCols = cols;
    gridColsLandscape = colsLandscape;
    gridWidth = width;
    gridWidthLandscape = widthL;
    GStorage.setting.putAll({
      SettingBoxKey.speedGridCols: cols,
      SettingBoxKey.speedGridColsLandscape: colsLandscape,
      SettingBoxKey.speedGridWidth: width,
      SettingBoxKey.speedGridWidthLandscape: widthL,
      SettingBoxKey.speedGridRowHeight: rowHeight,
      SettingBoxKey.speedGridRowHeightLandscape: rowHeightL,
    });
    PlPlayerController.instance
      ?..speedGridCols = cols
      ..speedGridColsLandscape = colsLandscape
      ..speedGridWidth = width
      ..speedGridWidthLandscape = widthL
      ..speedGridRowHeight = rowHeight
      ..speedGridRowHeightLandscape = rowHeightL;
  }

  // 倍速列表变动后同步给播放器；列数没手动指定时按近正方形重算：竖屏向下取整、
  // 横屏向上取整，宽度随列数回到自动
  void _onSpeedListChanged() {
    PlPlayerController.instance?.speedList = speedList;
    if (gridManual) return;
    final n = speedList.length;
    final cols = sqrt(n).toInt();
    final colsL = sqrt(n - 1).toInt() + 1;
    _saveGrid(cols, colsL, _autoGridWidth(cols), _autoGridWidth(colsL));
  }

  // 宽度框只要没被手动改过，就跟着其他参数实时换成自动值；改过就以手填为准
  Future<void> _setGridCols() async {
    final colsCtrl = TextEditingController(text: '$gridCols');
    final colsLCtrl = TextEditingController(text: '$gridColsLandscape');
    final widthCtrl = TextEditingController(text: '${gridWidth.round()}');
    final widthLCtrl = TextEditingController(
      text: '${gridWidthLandscape.round()}',
    );
    var widthTouched = false;
    var widthLTouched = false;
    Widget field(
      TextEditingController ctrl,
      String label,
      String suffix,
      ValueChanged<String> onChanged,
    ) => Expanded(
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: _border,
        ),
        onChanged: onChanged,
      ),
    );
    // (0, …) 表示恢复自动
    final result = await showDialog<(int, int, int, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        onDispose: () {
          colsCtrl.dispose();
          colsLCtrl.dispose();
          widthCtrl.dispose();
          widthLCtrl.dispose();
        },
        builder: (context, _) => AlertDialog(
          title: const Text('矩阵列数与宽度'),
          content: Column(
            spacing: 16,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                spacing: 12,
                children: [
                  field(colsCtrl, '竖屏', '列', (text) {
                    if (!widthTouched) {
                      widthCtrl.text =
                          '${_autoGridWidth(int.tryParse(text) ?? 1).round()}';
                    }
                  }),
                  field(widthCtrl, '竖屏宽', '', (_) => widthTouched = true),
                ],
              ),
              Row(
                spacing: 12,
                children: [
                  field(colsLCtrl, '横屏', '列', (text) {
                    if (!widthLTouched) {
                      widthLCtrl.text =
                          '${_autoGridWidth(int.tryParse(text) ?? 1).round()}';
                    }
                  }),
                  field(
                    widthLCtrl,
                    '横屏宽',
                    '',
                    (_) => widthLTouched = true,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('取消')),
            TextButton(
              onPressed: () => Get.back(result: (0, 0, 0, 0)),
              child: const Text('自动'),
            ),
            TextButton(
              onPressed: () {
                final p = int.tryParse(colsCtrl.text) ?? 0;
                final l = int.tryParse(colsLCtrl.text) ?? 0;
                final w = int.tryParse(widthCtrl.text) ?? 0;
                final wl = int.tryParse(widthLCtrl.text) ?? 0;
                if (p < 1 || l < 1) {
                  SmartDialog.showToast('列数至少为 1');
                  return;
                }
                if (w < 280 || wl < 280) {
                  SmartDialog.showToast('宽度至少 280，放得下加减按钮');
                  return;
                }
                Get.back(result: (p, l, w, wl));
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    gridManual = result.$1 != 0;
    GStorage.setting.put(SettingBoxKey.speedGridManual, gridManual);
    if (gridManual) {
      _saveGrid(
        result.$1,
        result.$2,
        result.$3.toDouble(),
        result.$4.toDouble(),
      );
    } else {
      _onSpeedListChanged();
    }
    setState(() {});
  }

  Future<void> _setSliderRange() async {
    final minCtrl = TextEditingController(text: formatCenti(sliderMin));
    final maxCtrl = TextEditingController(text: formatCenti(sliderMax));
    final stepCtrl = TextEditingController(text: formatCenti(sliderStep));
    final widthCtrl = TextEditingController(text: '${sliderWidth.round()}');
    var widthTouched = false;
    // 内部精度 0.01，分度值不小于它；两端对齐到分度值的整数倍。不合法时返回 null
    (int, int, int)? parse() {
      final step = ((double.tryParse(stepCtrl.text) ?? 0) * 100).round();
      if (step < 1) return null;
      final lo =
          ((double.tryParse(minCtrl.text) ?? 0) * 100 / step).round() * step;
      final hi =
          ((double.tryParse(maxCtrl.text) ?? 0) * 100 / step).round() * step;
      return lo < step || hi <= lo ? null : (lo, hi, step);
    }

    void follow(String _) {
      if (widthTouched) return;
      if (parse() case (final lo, final hi, final step)) {
        widthCtrl.text = '${_autoSliderWidth(hi - lo, step).round()}';
      }
    }

    Widget field(TextEditingController ctrl, String label) => TextField(
      controller: ctrl,
      keyboardType: const .numberWithOptions(decimal: true),
      inputFormatters: FilteringText.decimal,
      decoration: InputDecoration(
        labelText: label,
        suffixText: '倍',
        border: _border,
      ),
      onChanged: follow,
    );
    final result = await showDialog<(int, int, int, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        onDispose: () {
          minCtrl.dispose();
          maxCtrl.dispose();
          stepCtrl.dispose();
          widthCtrl.dispose();
        },
        builder: (context, _) => AlertDialog(
          title: const Text('滑杆范围与宽度'),
          content: Column(
            spacing: 16,
            mainAxisSize: MainAxisSize.min,
            children: [
              field(minCtrl, '最小'),
              field(maxCtrl, '最大'),
              field(stepCtrl, '分度值'),
              TextField(
                controller: widthCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '宽度',
                  helperText: '不改则随范围和分度值自动计算',
                  border: _border,
                ),
                onChanged: (_) => widthTouched = true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('取消')),
            TextButton(
              onPressed: () {
                final range = parse();
                if (range == null) {
                  SmartDialog.showToast('分度值至少 0.01，最小要大于 0，且最大要大于最小');
                  return;
                }
                final width = int.tryParse(widthCtrl.text) ?? 0;
                if (width < 280) {
                  SmartDialog.showToast('宽度至少 280，放得下加减按钮');
                  return;
                }
                Get.back(result: (range.$1, range.$2, range.$3, width));
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    sliderMin = result.$1;
    sliderMax = result.$2;
    sliderStep = result.$3;
    sliderWidth = result.$4.toDouble();
    final divisions = (sliderMax - sliderMin) ~/ sliderStep;
    GStorage.setting.putAll({
      SettingBoxKey.speedSliderMin: sliderMin,
      SettingBoxKey.speedSliderMax: sliderMax,
      SettingBoxKey.speedSliderStep: sliderStep,
      SettingBoxKey.speedSliderDivisions: divisions,
      SettingBoxKey.speedSliderWidth: sliderWidth,
    });
    PlPlayerController.instance
      ?..speedSliderMin = sliderMin
      ..speedSliderMax = sliderMax
      ..speedSliderDivisions = divisions
      ..speedSliderWidth = sliderWidth;
    setState(() {});
  }

  static String _panelModeDesc(int mode) => switch (mode & 6) {
    0 => '常规列表',
    2 => '矩阵',
    4 => '滑杆',
    _ =>
      '${mode & 1 != 0 ? '一个面板' : '两个面板'}：'
          '${mode & 8 != 0 ? '滑杆在上，矩阵在下' : '矩阵在上，滑杆在下'}',
  };

  // 四位一组：常规、矩阵、滑杆、滑杆在上；矩阵与滑杆都勾时常规表示合成一个面板，
  // 后勾的那个排在下面
  Widget _panelModeTile(int shift, String name) {
    final mode = panelLayout >> shift & 15;
    return ListTile(
      title: Text('$name倍速面板'),
      subtitle: Text(_panelModeDesc(mode)),
      trailing: SegmentedButton<int>(
        multiSelectionEnabled: true,
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 1, label: Text('常规')),
          ButtonSegment(value: 2, label: Text('矩阵')),
          ButtonSegment(value: 4, label: Text('滑杆')),
        ],
        selected: {
          for (final bit in const [1, 2, 4])
            if (mode & bit != 0) bit,
        },
        onSelectionChanged: (value) {
          final bits = value.fold(0, (a, b) => a | b);
          final added = bits & ~mode;
          // 后勾矩阵则滑杆在上，后勾滑杆则矩阵在上，其余保持
          final top = bits & 6 != 6
              ? mode & 8
              : added & 2 != 0
              ? 8
              : added & 4 != 0
              ? 0
              : mode & 8;
          panelLayout =
              panelLayout & ~(15 << shift) | (bits | top) << shift;
          PlPlayerController.instance?.speedPanelLayout = panelLayout;
          GStorage.setting.put(SettingBoxKey.speedPanelLayout, panelLayout);
          setState(() {});
        },
      ),
    );
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
            for (final (shift, name) in const [
              (0, '半屏'),
              (4, '全屏'),
              (8, '电脑'),
            ])
              _panelModeTile(shift, name),
            ListTile(
              title: const Text('矩阵列数与宽度'),
              subtitle: Text(
                '竖屏 $gridCols 列宽 ${gridWidth.round()}，横屏 $gridColsLandscape 列宽 ${gridWidthLandscape.round()}${gridManual ? '' : '，随倍速列表自动计算'}',
              ),
              onTap: _setGridCols,
            ),
            ListTile(
              title: const Text('滑杆范围与宽度'),
              subtitle: Text(
                '${formatCenti(sliderMin)} ~ ${formatCenti(sliderMax)} 倍，分度值 ${formatCenti(sliderStep)}，宽 ${sliderWidth.round()}',
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
