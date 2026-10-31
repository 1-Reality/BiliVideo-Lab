import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/common/widgets/view_safe_area.dart';
import 'package:PiliBro/pages/setting/widgets/switch_item.dart';
import 'package:PiliBro/plugin/pl_player/models/slide_action.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

/// 播放器滑动手势：竖滑分 1～3 列、横滑分四个象限，每块各选一个动作。
/// 两张表各存成一个整数，播放器创建时解一次
class GestureSettingsPage extends StatefulWidget {
  const GestureSettingsPage({super.key});

  @override
  State<GestureSettingsPage> createState() => _GestureSettingsPageState();
}

class _GestureSettingsPageState extends State<GestureSettingsPage> {
  static const _splitFlex = [(1, 2), (1, 1), (2, 1)];
  static final _verticalLabels = [
    for (final e in VerticalSlide.values) e.label,
  ];
  static final _horizontalLabels = [
    for (final e in HorizontalSlide.values) e.label,
  ];

  int vertical = Pref.slideVertical;
  int horizontal = Pref.slideHorizontal;

  void _saveVertical(int value) {
    setState(() => vertical = value);
    GStorage.setting.put(SettingBoxKey.slideVertical, value);
  }

  void _saveHorizontal(int value) {
    setState(() => horizontal = value);
    GStorage.setting.put(SettingBoxKey.slideHorizontal, value);
  }

  Widget _zone(
    Color border,
    String label,
    List<String> labels,
    ValueChanged<int> onSelected,
  ) => Expanded(
    child: PopupMenuButton<int>(
      tooltip: '选择动作',
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (var i = 0; i < labels.length; i++)
          PopupMenuItem(value: i, child: Text(labels[i])),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: border)),
        child: Center(child: Text(label)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.outline;
    final columns = vertical & 3;
    final split = horizontal >> 8 & 3;
    final (topFlex, bottomFlex) = _splitFlex[split];
    Widget quadrant(int q) => _zone(
      border,
      HorizontalSlide.values[horizontal >> q * 2 & 3].label,
      _horizontalLabels,
      (a) => _saveHorizontal(horizontal & ~(3 << q * 2) | a << q * 2),
    );
    return SimpleScaffold(
      appBar: AppBar(title: const Text('手势')),
      body: ViewSafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.viewPaddingOf(context).bottom + 100,
          ),
          children: [
            Text(
              '起手的位置决定动作，起手后往哪拖都算。横滑调倍速按分度值细调，每 16 一档，'
              '分度值在倍速设置里；竖滑调倍速按倍速列表粗调，每 40 一档。点方块选动作，下次打开视频生效。',
              style: TextStyle(color: border),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('上下滑动', style: theme.textTheme.titleMedium),
                const Spacer(),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1 列')),
                    ButtonSegment(value: 2, label: Text('2 列')),
                    ButtonSegment(value: 3, label: Text('3 列')),
                  ],
                  selected: {columns},
                  onSelectionChanged: (value) =>
                      _saveVertical(vertical & ~3 | value.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columns; c++)
                    _zone(
                      border,
                      VerticalSlide.values[vertical >> 2 + c * 3 & 7].label,
                      _verticalLabels,
                      (a) => _saveVertical(
                        vertical & ~(7 << 2 + c * 3) | a << 2 + c * 3,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Text('左右滑动', style: theme.textTheme.titleMedium),
                const Spacer(),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (var i = 0; i < slideSplitLabels.length; i++)
                      ButtonSegment(
                        value: i,
                        label: Text(slideSplitLabels[i]),
                      ),
                  ],
                  selected: {split},
                  onSelectionChanged: (value) => _saveHorizontal(
                    horizontal & ~(3 << 8) | value.first << 8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: topFlex,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [quadrant(0), quadrant(1)],
                    ),
                  ),
                  Expanded(
                    flex: bottomFlex,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [quadrant(2), quadrant(3)],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SetSwitchItem(
              title: '全屏手势反向',
              subtitle: '竖滑选了「全屏」的那一列：默认向上进入、向下退出，开启后反过来',
              setKey: SettingBoxKey.fullScreenGestureReverse,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}