// 视频类动态的紧凑卡片：左封面 + 右标题/统计信息。
// 用它替换 video_panel.dart 的「大封面 + 下方标题」竖排布局，是否启用由设置决定。
import 'package:PiliBro/common/widgets/image/network_img_layer.dart';
import 'package:PiliBro/common/widgets/svg/play_icon.dart';
import 'package:PiliBro/models/dynamics/result.dart';
import 'package:PiliBro/utils/num_utils.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

// 设置页开关的缓存，改了以后下次构建生效
bool compactVideoCardEnabled = Pref.dynCompactVideoCard;

/// 只接管普通视频和合集，其余类型返回 null 走原卡片
Widget? compactVideoCard({
  required ThemeData theme,
  required DynamicItemModel item,
  required int floor,
  required bool isDetail,
}) {
  final major = item.modules.moduleDynamic?.major;
  final DynamicArchiveModel? video;
  final String label;
  switch (item.type) {
    case 'DYNAMIC_TYPE_AV':
      video = major?.archive;
      label = '视频';
    case 'DYNAMIC_TYPE_UGC_SEASON':
      video = major?.ugcSeason;
      label = '合集';
    default:
      return null;
  }
  if (video == null) return null;

  final padding = floor == 1
      ? const EdgeInsets.symmetric(horizontal: 12)
      : EdgeInsets.zero;

  return Padding(
    padding: padding,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        SizedBox(
          width: 160,
          height: 100,
          child: Stack(
            children: [
              NetworkImgLayer(
                width: 160,
                height: 100,
                src: video.cover,
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
                      _tag(theme, label),
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
    ),
  );
}

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
