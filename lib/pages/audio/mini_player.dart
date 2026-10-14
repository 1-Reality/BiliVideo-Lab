import 'dart:io' show File;

import 'package:PiliBro/common/widgets/image/network_img_layer.dart';
import 'package:PiliBro/pages/audio/session.dart';
import 'package:PiliBro/utils/path_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;

/// Floating capsule for the retained audio-only Player, laid out by
/// MainLayout above the bottom navigation. With no audio session it is a
/// zero-size box; the Obx only rebuilds when a session starts, stops or the
/// audio page is shown/hidden.
class AudioMiniPlayer extends StatelessWidget {
  const AudioMiniPlayer({super.key, required this.bottomInset});

  /// System inset to keep clear when no bottom navigation sits below.
  final double bottomInset;

  @override
  Widget build(BuildContext context) => Obx(() {
    final controller = AudioPlaybackSession.current.value;
    if (controller == null || AudioPlaybackSession.visiblePages.value > 0) {
      return const SizedBox.shrink();
    }
    final playing = controller.isPlayingRx.value;
    final local = controller.localItem.value;
    final item = controller.audioItem.value;
    final title = local?.showTitle ?? item?.arc.title ?? '正在播放音频';
    final artist = local?.ownerName ?? item?.owner.name;
    final avatar = item?.owner.avatar;
    final colorScheme = ColorScheme.of(context);

    final Widget cover = local != null
        ? ClipOval(
            child: Image.file(
              File(path.join(local.entryDirPath, PathUtils.coverName)),
              width: 44,
              height: 44,
              cacheWidth: 132,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.headphones_outlined),
            ),
          )
        : NetworkImgLayer(
            src: item?.arc.cover,
            width: 44,
            height: 44,
            type: .avatar,
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 8 + bottomInset),
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        elevation: 3,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: AudioPlaybackSession.reopen,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10),
                  child: cover,
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (artist != null && artist.isNotEmpty)
                        Row(
                          spacing: 6,
                          children: [
                            if (avatar != null && avatar.isNotEmpty)
                              NetworkImgLayer(
                                src: avatar,
                                width: 16,
                                height: 16,
                                type: .avatar,
                              ),
                            Flexible(
                              child: Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.outline,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: playing ? '暂停' : '播放',
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  onPressed: controller.playOrPause,
                ),
                IconButton(
                  tooltip: '打开播放页',
                  icon: const Icon(Icons.queue_music_rounded),
                  onPressed: AudioPlaybackSession.reopen,
                ),
                IconButton(
                  tooltip: '关闭音频播放',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: AudioPlaybackSession.stop,
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  });
}
