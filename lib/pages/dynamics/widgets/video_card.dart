// 视频类动态的紧凑卡片：左封面 + 右标题/统计信息。
// 用它替换 video_panel.dart 的「大封面 + 下方标题」竖排布局，是否启用由设置决定。
import 'dart:math' show min;

import 'package:PiliBro/common/style.dart';
import 'package:PiliBro/common/widgets/image/network_img_layer.dart';
import 'package:PiliBro/common/widgets/svg/play_icon.dart';
import 'package:PiliBro/models/dynamics/result.dart';
import 'package:PiliBro/utils/num_utils.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

/// 设置页开关的运行时状态。
/// 用 ValueNotifier 是为了让已经渲染出来的动态卡片在切换开关时立即重建，
/// 不必重启或下拉刷新。Dart 顶层变量是懒初始化，首次访问时 GStorage 已打开。
final ValueNotifier<bool> compactVideoCardEnabled = ValueNotifier<bool>(
  Pref.dynCompactVideoCard,
);

const _videoTypes = {
  'DYNAMIC_TYPE_AV',
  'DYNAMIC_TYPE_UGC_SEASON',
  'DYNAMIC_TYPE_PGC',
  'DYNAMIC_TYPE_PGC_UNION',
  'DYNAMIC_TYPE_COURSES_SEASON',
};

bool isVideoDynamic(String? type) => type != null && _videoTypes.contains(type);

DynamicArchiveModel? videoArchiveOf(DynamicItemModel item) => switch (item.type) {
      'DYNAMIC_TYPE_AV' => item.modules.moduleDynamic?.major?.archive,
      'DYNAMIC_TYPE_UGC_SEASON' =>
        item.modules.moduleDynamic?.major?.ugcSeason,
      'DYNAMIC_TYPE_PGC' || 'DYNAMIC_TYPE_PGC_UNION' =>
        item.modules.moduleDynamic?.major?.pgc,
      'DYNAMIC_TYPE_COURSES_SEASON' =>
        item.modules.moduleDynamic?.major?.courses,
      _ => null,
    };

/// 返回 null 时表示保持原有竖排布局：非视频类型或缺少封面都走原逻辑。
/// 是否启用由 [compactVideoCardEnabled] 统一控制，
/// 列表流、转发内嵌、详情页、保存为图片共用同一套判断。
Widget? compactVideoCard(
  BuildContext context, {
  required ThemeData theme,
  required DynamicItemModel item,
  required int floor,
  bool isDetail = false, required bool isSave,
}) {
  if (!isVideoDynamic(item.type)) {
    return null;
  }
  final video = videoArchiveOf(item);
  final cover = video?.cover;
  if (video == null || cover == null || cover.isEmpty) {
    return null;
  }

  final padding = floor == 1
      ? const EdgeInsets.symmetric(horizontal: 12)
      : EdgeInsets.zero;

  return Padding(
    padding: padding,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final coverWidth = min(160.0, constraints.maxWidth * 0.42);
        final coverHeight = coverWidth / Style.aspectRatio;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            SizedBox(
              width: coverWidth,
              height: coverHeight,
              child: Stack(
                children: [
                  NetworkImgLayer(
                    width: coverWidth,
                    height: coverHeight,
                    src: cover,
                    quality: 40,
                  ),
                  const Positioned(
                    left: 6,
                    bottom: 6,
                    child: PlayIcon(size: 26),
                  ),
                  if (video.durationText case final durationText?)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          borderRadius: .all(.circular(4)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          child: Text(
                            durationText,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (video.title case final title?)
                    Text(
                      title,
                      maxLines: isDetail ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: theme.textTheme.titleSmall?.fontSize ?? 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _tag(theme, _typeLabel(item.type)),
                      if (video.badge?.text case final badge?)
                        _tag(
                          theme,
                          badge,
                          color: theme.colorScheme.error,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      if (video.stat?.play case final play?)
                        _stat(
                          theme,
                          Icons.play_arrow_outlined,
                          NumUtils.numFormat(play),
                        ),
                      if (video.stat?.danmu case final danmu?)
                        _stat(
                          theme,
                          Icons.subtitles_outlined,
                          NumUtils.numFormat(danmu),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

String _typeLabel(String? type) => switch (type) {
      'DYNAMIC_TYPE_UGC_SEASON' => '合集',
      'DYNAMIC_TYPE_PGC' || 'DYNAMIC_TYPE_PGC_UNION' => '番剧',
      'DYNAMIC_TYPE_COURSES_SEASON' => '课程',
      _ => '视频',
    };

Widget _tag(ThemeData theme, String text, {Color? color}) {
  final effectiveColor = color ?? theme.colorScheme.primary;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: effectiveColor.withValues(alpha: 0.12),
      borderRadius: const .all(.circular(4)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: effectiveColor),
    ),
  );
}

Widget _stat(ThemeData theme, IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.outline),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
        ),
      ],
    );
