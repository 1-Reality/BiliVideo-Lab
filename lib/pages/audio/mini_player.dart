import 'dart:io' show File;

import 'package:PiliBro/common/widgets/image/network_img_layer.dart';
import 'package:PiliBro/grpc/bilibili/app/listener/v1.pbenum.dart'
    show PlaylistSource;
import 'package:PiliBro/models/common/video/video_type.dart';
import 'package:PiliBro/pages/audio/controller.dart';
import 'package:PiliBro/pages/audio/session.dart';
import 'package:PiliBro/pages/audio/view.dart';
import 'package:PiliBro/utils/page_utils.dart';
import 'package:PiliBro/utils/path_utils.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;

typedef LastVideo = ({
  VideoType videoType,
  int aid,
  String bvid,
  int cid,
  int? epId,
  int? seasonId,
  String? title,
  String? cover,
  String? upName,
  String? upFace,
  int? progressMs,
});

/// The bottom playback bar, independent of AudioFirstMode. [enabled] is read
/// once per launch; when false nothing below is touched: the video page does
/// not record [lastVideo] and MainLayout gets no miniPlayer child.
abstract final class PlaybackBar {
  static final bool enabled = Pref.showAudioMiniPlayer;

  /// The video page left most recently, shown when no audio session exists.
  static final lastVideo = Rxn<LastVideo>();
}

/// Floating capsule laid out by MainLayout above the bottom navigation.
/// Audio mode: the retained audio-only Player. Video mode: the last video
/// page left. The body returns to that mode; the note key switches to the
/// other one for this item only (the home default is left alone).
class PlaybackMiniBar extends StatelessWidget {
  const PlaybackMiniBar({super.key, required this.bottomInset});

  /// System inset to keep clear when no bottom navigation sits below.
  final double bottomInset;

  @override
  Widget build(BuildContext context) => Obx(() {
    final controller = AudioPlaybackSession.current.value;
    if (controller != null) {
      if (AudioPlaybackSession.visiblePages.value > 0) {
        return const SizedBox.shrink();
      }
      return _audio(context, controller);
    }
    final video = PlaybackBar.lastVideo.value;
    if (video == null) return const SizedBox.shrink();
    return _video(context, video);
  });

  Widget _audio(BuildContext context, AudioController controller) {
    final playing = controller.isPlayingRx.value;
    final local = controller.localItem.value;
    final item = controller.audioItem.value;
    final avatar = item?.owner.avatar;
    final Widget cover = local != null
        ? ClipOval(
            child: Image.file(
              File(path.join(local.entryDirPath, PathUtils.coverName)),
              width: 44,
              height: 44,
              cacheWidth: 132,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.headphones_outlined),
            ),
          )
        : NetworkImgLayer(
            src: item?.arc.cover,
            width: 44,
            height: 44,
            type: .avatar,
          );
    return _bar(
      context,
      cover: cover,
      title: local?.showTitle ?? item?.arc.title ?? '正在播放音频',
      artist: local?.ownerName ?? item?.owner.name,
      avatar: avatar,
      onTap: AudioPlaybackSession.reopen,
      actions: [
        IconButton(
          tooltip: playing ? '暂停' : '播放',
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          onPressed: controller.playOrPause,
        ),
        if (controller.isUgc && !controller.isOffline)
          IconButton(
            tooltip: '切换为视频观看',
            icon: const Icon(Icons.queue_music_rounded),
            onPressed: () {
              final aid = controller.oid.toInt();
              final cid = controller.subId.first.toInt();
              final progress =
                  controller.player?.state.position.inMilliseconds;
              AudioPlaybackSession.stop();
              PageUtils.toVideoPage(
                aid: aid,
                cid: cid,
                progress: progress,
                forceVideo: true,
              );
            },
          ),
        IconButton(
          tooltip: '关闭音频播放',
          icon: const Icon(Icons.close_rounded),
          onPressed: AudioPlaybackSession.stop,
        ),
      ],
    );
  }

  Widget _video(BuildContext context, LastVideo video) => _bar(
    context,
    cover: NetworkImgLayer(src: video.cover, width: 64, height: 40),
    title: video.title ?? video.bvid,
    artist: video.upName,
    avatar: video.upFace,
    onTap: () => PageUtils.toVideoPage(
      videoType: video.videoType,
      aid: video.aid,
      bvid: video.bvid,
      cid: video.cid,
      epId: video.epId,
      seasonId: video.seasonId,
      cover: video.cover,
      title: video.title,
      progress: video.progressMs,
      forceVideo: true,
    ),
    actions: [
      IconButton(
        tooltip: '切换为音频收听',
        icon: const Icon(Icons.queue_music_rounded),
        onPressed: () {
          PlaybackBar.lastVideo.value = null;
          // The listener API behind the audio page serves UGC only; PGC is
          // heard in the video page with just its audio stream opened.
          if (video.videoType != VideoType.ugc) {
            PageUtils.toVideoPage(
              videoType: video.videoType,
              aid: video.aid,
              bvid: video.bvid,
              cid: video.cid,
              epId: video.epId,
              seasonId: video.seasonId,
              cover: video.cover,
              title: video.title,
              progress: video.progressMs,
              forceVideo: true,
              extraArguments: const {'audioOnly': true},
            );
            return;
          }
          AudioPage.toAudioPage(
            oid: video.aid,
            subId: [video.cid],
            itemType: 1,
            from: PlaylistSource.UP_ARCHIVE,
            bvid: video.bvid,
            start: video.progressMs == null
                ? null
                : Duration(milliseconds: video.progressMs!),
          );
        },
      ),
      IconButton(
        tooltip: '关闭',
        icon: const Icon(Icons.close_rounded),
        onPressed: () => PlaybackBar.lastVideo.value = null,
      ),
    ],
  );

  Widget _bar(
    BuildContext context, {
    required Widget cover,
    required String title,
    required String? artist,
    required String? avatar,
    required VoidCallback onTap,
    required List<Widget> actions,
  }) {
    final colorScheme = ColorScheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 8 + bottomInset),
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        elevation: 3,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
                ...actions,
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
