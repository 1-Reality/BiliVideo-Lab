import 'dart:io' show Platform;

import 'package:PiliBro/plugin/pl_player/controller.dart';
import 'package:PiliBro/plugin/pl_player/models/hwdec_type.dart';

class DecoderLabMode {
  const DecoderLabMode({
    required this.label,
    required this.hwdec,
    required this.primary,
    this.vo,
  });

  final String label;
  final String hwdec;
  final bool primary;
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
  static const _androidVoProperty = 'user-data/pilibro-decoder-lab-vo';
  static const _androidHwdecProperty = 'user-data/pilibro-decoder-lab-hwdec';
  static const _androidFallbackProperty =
      'user-data/pilibro-decoder-lab-hwdec-fallback';

  bool _decoderLabPrimary(String hwdec) {
    if (Platform.isAndroid) {
      return const {
        'mediacodec',
        'mediacodec-copy',
        'auto',
        'auto-safe',
        'auto-copy',
        'no',
      }.contains(hwdec);
    }
    if (Platform.isWindows) {
      return const {
        'd3d11va',
        'd3d11va-copy',
        'nvdec',
        'nvdec-copy',
        'd3d12va',
        'd3d12va-copy',
        'cuda',
        'cuda-copy',
        'auto',
        'auto-safe',
        'auto-copy',
        'no',
      }.contains(hwdec);
    }
    return const {'auto', 'auto-safe', 'auto-copy', 'no'}.contains(hwdec);
  }

  List<DecoderLabMode> get decoderLabModes {
    final current = hwdec ?? 'no';
    return [
      DecoderLabMode(
        label: '当前设置 · $current',
        hwdec: current,
        primary: true,
      ),
      if (Platform.isAndroid)
        const DecoderLabMode(
          label: 'mediacodec + mediacodec_embed · MediaCodec Embed',
          hwdec: 'mediacodec',
          vo: 'mediacodec_embed',
          primary: true,
        ),
      for (final type in HwDecType.values)
        DecoderLabMode(
          label: '${type.hwdec} · ${type.desc}',
          hwdec: type.hwdec,
          primary: _decoderLabPrimary(type.hwdec),
        ),
    ];
  }

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
    final currentMedia = player.current.last;
    final extras = Map<String, String>.from(
      currentMedia.extras ?? const <String, String>{},
    );

    if (Platform.isAndroid) {
      final labVo = mode.vo ?? 'gpu';
      final fallback = labVo == 'mediacodec_embed' ? 'no' : '3';

      // Apply the experiment as per-file options as well as through media_kit's
      // Android on_load hook. This puts hwdec/vo on the same load lifecycle,
      // before decoder probing begins, rather than changing hwdec globally and
      // hoping the later Surface/VO recreation observes it.
      extras
        ..['hwdec'] = mode.hwdec
        ..['vo'] = labVo
        ..['hwdec-software-fallback'] = fallback;

      await player.command(['set', _androidVoProperty, labVo]);
      await player.command(['set', _androidHwdecProperty, mode.hwdec]);
      await player.command(['set', _androidFallbackProperty, fallback]);
    } else {
      await player.command(['set', 'hwdec', mode.hwdec]);
    }

    final media = currentMedia.copyWith(
      start: oldPosition,
      extras: extras,
    );
    await player.open(media, play: false);
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
    await player.open(media, play: false);
    await setPlaybackSpeed(speed, recordSelection: false);
    if (wasPlaying) await play();
  }

  Future<DecoderBenchmarkResult> runDecoderBenchmark({
    required DecoderLabMode mode,
    double? targetSpeed,
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
    final originalSpeed = playbackSpeed;
    final speed = targetSpeed ?? originalSpeed;
    final oldDanmakuEnabled = enableShowDanmakuAdaptive.value;
    final oldShowDanmaku = showDanmaku;

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
      await setPlaybackSpeed(originalSpeed, recordSelection: false);
      if (originalPlaying) {
        await play();
      } else {
        await pause(notify: false);
      }
    }
  }
}
