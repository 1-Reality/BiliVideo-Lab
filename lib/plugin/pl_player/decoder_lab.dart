import 'dart:io' show Platform;

import 'package:PiliPlus/plugin/pl_player/controller.dart';

/// A deliberately small, session-only decoder experiment descriptor.
///
/// The lab never rewrites the global decoder preference/order. It only changes
/// the currently opened offline player, so one cached video can be used as a
/// repeatable decoder/rendering test bench.
class DecoderLabMode {
  const DecoderLabMode({
    required this.label,
    required this.hwdec,
    this.vo,
  });

  final String label;
  final String hwdec;
  final String? vo;
}

class DecoderBenchmarkResult {
  const DecoderBenchmarkResult({
    required this.modeLabel,
    required this.targetSpeed,
    required this.wallTime,
    required this.mediaTime,
  });

  final String modeLabel;
  final double targetSpeed;
  final Duration wallTime;
  final Duration mediaTime;

  double get effectiveSpeed => wallTime.inMilliseconds == 0
      ? 0
      : mediaTime.inMilliseconds / wallTime.inMilliseconds;
}

extension DecoderLabController on PlPlayerController {
  List<DecoderLabMode> get decoderLabModes {
    final original = DecoderLabMode(
      label: '当前设置',
      hwdec: hwdec ?? 'no',
      vo: Platform.isAndroid ? 'gpu' : null,
    );
    if (Platform.isAndroid) {
      return [
        original,
        const DecoderLabMode(
          label: 'MediaCodec',
          hwdec: 'mediacodec',
          vo: 'gpu',
        ),
        const DecoderLabMode(
          label: 'MediaCodec Copy',
          hwdec: 'mediacodec-copy',
          vo: 'gpu',
        ),
        const DecoderLabMode(
          label: 'MediaCodec Embed',
          hwdec: 'mediacodec',
          vo: 'mediacodec_embed',
        ),
        const DecoderLabMode(label: '软件解码', hwdec: 'no', vo: 'gpu'),
        const DecoderLabMode(label: 'Auto Safe', hwdec: 'auto-safe', vo: 'gpu'),
      ];
    }
    if (Platform.isWindows) {
      return [
        original,
        const DecoderLabMode(label: 'D3D11VA', hwdec: 'd3d11va'),
        const DecoderLabMode(label: 'D3D11VA Copy', hwdec: 'd3d11va-copy'),
        const DecoderLabMode(label: 'NVDEC', hwdec: 'nvdec'),
        const DecoderLabMode(label: 'NVDEC Copy', hwdec: 'nvdec-copy'),
        const DecoderLabMode(label: 'D3D12VA', hwdec: 'd3d12va'),
        const DecoderLabMode(label: 'D3D12VA Copy', hwdec: 'd3d12va-copy'),
        const DecoderLabMode(label: 'CUDA', hwdec: 'cuda'),
        const DecoderLabMode(label: 'CUDA Copy', hwdec: 'cuda-copy'),
        const DecoderLabMode(label: '软件解码', hwdec: 'no'),
        const DecoderLabMode(label: 'Auto Safe', hwdec: 'auto-safe'),
      ];
    }
    return [
      original,
      const DecoderLabMode(label: '软件解码', hwdec: 'no'),
      const DecoderLabMode(label: 'Auto Safe', hwdec: 'auto-safe'),
    ];
  }

  /// Changes only the current offline playback session.
  ///
  /// Re-opening the same [Media] forces the decoder to be recreated while
  /// preserving position, speed and play/pause state. On Android the existing
  /// media_kit Surface is deliberately reused; `mediacodec_embed` is switched
  /// after the load hook because media_kit's current hook resets `vo` to `gpu`.
  Future<void> applyDecoderLabMode(DecoderLabMode mode) async {
    if (!isFileSource) {
      throw StateError('Decoder lab is only available for offline files.');
    }
    final player = videoPlayerController;
    if (player == null || player.current.isEmpty) {
      throw StateError('Player is not ready.');
    }

    final wasPlaying = player.state.playing;
    final oldPosition = player.state.position;
    final speed = playbackSpeed;
    final media = player.current.last.copyWith(start: oldPosition);

    await player.command(['set', 'hwdec', mode.hwdec]);
    if (mode.vo != null && !Platform.isAndroid) {
      await player.command(['set', 'vo', mode.vo!]);
    }

    await player.open(media, play: false);

    // AndroidVideoController's onLoad hook restores its configured `vo`.
    // Re-apply the lab VO afterwards so mediacodec_embed can reuse the Surface.
    if (mode.vo != null) {
      await player.command(['set', 'vo', mode.vo!]);
    }
    await player.command(['set', 'hwdec', mode.hwdec]);
    await setPlaybackSpeed(speed, recordSelection: false);

    if (wasPlaying) {
      await play();
    } else {
      await pause(notify: false);
    }
  }

  Future<void> setDecoderLabFrameDrop(bool enabled) async {
    final player = videoPlayerController;
    if (player == null) return;
    await player.command([
      'set',
      'framedrop',
      enabled ? 'decoder+vo' : 'vo',
    ]);
  }

  Future<void> setDecoderLabSkipNonRef(bool enabled) async {
    final player = videoPlayerController;
    if (player == null || player.current.isEmpty) return;

    final wasPlaying = player.state.playing;
    final oldPosition = player.state.position;
    final speed = playbackSpeed;
    final media = player.current.last.copyWith(start: oldPosition);

    await player.command([
      'set',
      'vd-lavc-skipframe',
      enabled ? 'nonref' : 'none',
    ]);
    // Recreate the decoder so the test never depends on whether a particular
    // FFmpeg hwaccel applies skip_frame dynamically.
    await player.open(media, play: false);
    await setPlaybackSpeed(speed, recordSelection: false);
    if (wasPlaying) await play();
  }

  /// Runs a wall-clock benchmark on the current cached video and restores the
  /// original playback position/state afterwards. The playback speed is left
  /// exactly as the user selected it; the metric is media-time / wall-time.
  Future<DecoderBenchmarkResult> runDecoderBenchmark({
    required DecoderLabMode mode,
    Duration wallTime = const Duration(seconds: 10),
  }) async {
    if (!isFileSource) {
      throw StateError('Decoder benchmark requires an offline file.');
    }
    final player = videoPlayerController;
    if (player == null || player.current.isEmpty) {
      throw StateError('Player is not ready.');
    }

    final originalPosition = player.state.position;
    final originalPlaying = player.state.playing;
    final speed = playbackSpeed;
    final oldDanmakuEnabled = enableShowDanmakuAdaptive.value;
    final oldShowDanmaku = showDanmaku;

    // Keep repeated runs on different decoders comparable. If the current
    // position is too close to EOF for the requested wall-time at the selected
    // speed, move the benchmark window earlier but restore it afterwards.
    var start = originalPosition;
    final mediaBudget = Duration(
      milliseconds: (wallTime.inMilliseconds * speed * 1.15).round(),
    );
    final total = player.state.duration;
    if (total > Duration.zero && total - start < mediaBudget) {
      start = total > mediaBudget ? total - mediaBudget : Duration.zero;
    }

    enableShowDanmakuAdaptive.value = false;
    showDanmaku = false;

    try {
      await seekTo(start, recordStats: false);
      await setPlaybackSpeed(speed, recordSelection: false);
      await play();

      // Give the freshly selected decoder a short unmeasured settling window.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final measuredStart = player.state.position;
      final stopwatch = Stopwatch()..start();
      await Future<void>.delayed(wallTime);
      stopwatch.stop();
      final measuredEnd = player.state.position;
      await pause(notify: false);

      final mediaDelta = measuredEnd > measuredStart
          ? measuredEnd - measuredStart
          : Duration.zero;
      return DecoderBenchmarkResult(
        modeLabel: mode.label,
        targetSpeed: speed,
        wallTime: stopwatch.elapsed,
        mediaTime: mediaDelta,
      );
    } finally {
      enableShowDanmakuAdaptive.value = oldDanmakuEnabled;
      showDanmaku = oldShowDanmaku;
      await seekTo(originalPosition, recordStats: false);
      await setPlaybackSpeed(speed, recordSelection: false);
      if (originalPlaying) {
        await play();
      } else {
        await pause(notify: false);
      }
    }
  }
}
