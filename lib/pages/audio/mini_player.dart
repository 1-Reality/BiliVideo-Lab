import 'package:PiliBro/pages/audio/session.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// A small control surface for the retained audio-only Player.
class AudioMiniPlayer extends StatelessWidget {
  const AudioMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    final controller = AudioPlaybackSession.current.value;
    if (controller == null || AudioPlaybackSession.visiblePages.value > 0) {
      return const SizedBox.shrink();
    }
    final playing = controller.isPlayingRx.value;
    final title = controller.localItem.value?.showTitle ??
        controller.audioItem.value?.arc.title ?? '正在播放音频';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.headphones_outlined),
              ),
              Expanded(
                child: InkWell(
                  onTap: AudioPlaybackSession.reopen,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(title, maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              IconButton(
                tooltip: playing ? '暂停音频' : '继续播放',
                icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                onPressed: controller.playOrPause,
              ),
              IconButton(
                tooltip: '关闭音频播放',
                icon: const Icon(Icons.close_rounded),
                onPressed: AudioPlaybackSession.stop,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  });
}
