import 'dart:io' show Platform;

import 'package:PiliBro/plugin/pl_player/controller.dart';
import 'package:PiliBro/plugin/pl_player/models/hwdec_type.dart';
import 'package:PiliBro/utils/path_utils.dart';
import 'package:path/path.dart' as path;

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
    required this.voDrops,
    required this.decoderDrops,
    required this.voDelayed,
    required this.avsync,
  });

  final String modeLabel;
  final double targetSpeed;
  final Duration wallTime;
  final Duration mediaTime;
  // 测量窗口内：显示环节丢的帧、解码环节丢的帧、上屏迟到的帧；结束那一刻的音画差（秒）
  final int voDrops;
  final int decoderDrops;
  final int voDelayed;
  final String avsync;

  double get effectiveSpeed => wallTime.inMilliseconds == 0
      ? 0
      : mediaTime.inMilliseconds / wallTime.inMilliseconds;
}

// mpv debug log (fflush per line) of every decoder-lab switch in this player
// instance; truncated when the player first opens it, closed with the player.
final decoderLabLogPath = path.join(appSupportDirPath, 'mpv-decoder-lab.log');

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
        hwdec: mediacodecEmbed ? 'mediacodec' : current,
        vo: mediacodecEmbed ? 'mediacodec_embed' : null,
        primary: true,
      ),
      for (final type in HwDecType.values)
        if (type != HwDecType.mediacodecEmbed)
          DecoderLabMode(
            label: '${type.hwdec} · ${type.desc}',
            hwdec: type.hwdec,
            primary: _decoderLabPrimary(type.hwdec),
          )
        else if (Platform.isAndroid)
          DecoderLabMode(
            label: '${type.hwdec} · ${type.desc}',
            hwdec: 'mediacodec',
            vo: 'mediacodec_embed',
            primary: true,
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

      // vo/hwdec/hwdec-software-fallback are applied ONLY by media_kit's
      // on_load hook. As per-file options they would be applied earlier, while
      // wid is still 0 from the on_unload hook; mpv recreates the VO at once
      // (UPDATE_VO + force-window) and mediacodec_embed's
      // mp_assert(WinID != 0) aborts the process.
      await player.command(['set', 'log-file', decoderLabLogPath]);
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

  // reopen：解码器初始化时才读的选项，设完重开当前文件
  Future<void> setDecoderLabOption(
    String name,
    String value, {
    bool reopen = false,
  }) async {
    final player = videoPlayerController;
    if (player == null || player.current.isEmpty) return;
    await player.command(['set', name, value]);
    if (!reopen) return;

    final wasPlaying = player.state.playing;
    final speed = playbackSpeed;
    await player.open(
      player.current.last.copyWith(start: player.state.position),
      play: false,
    );
    await setPlaybackSpeed(speed, recordSelection: false);
    if (wasPlaying) await play();
  }

  // 正式路径改倍速时会整条重写 vd-lavc-o，所以这里用 change-list 只增删 ndk_codec 这一个键
  Future<void> setDecoderLabNdkCodec(bool enabled) async {
    await videoPlayerController?.command(
      enabled
          ? ['change-list', 'vd-lavc-o', 'add', 'ndk_codec=1']
          : ['change-list', 'vd-lavc-o', 'remove', 'ndk_codec'],
    );
  }

  Future<DecoderBenchmarkResult> runDecoderBenchmark({
    required DecoderLabMode mode,
    double? targetSpeed,
    Duration wallTime = const Duration(seconds: 10),
    bool ndkCodec = false,
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
      if (ndkCodec) await setDecoderLabNdkCodec(true);
      await play();

      await Future<void>.delayed(const Duration(milliseconds: 350));
      final measuredStart = player.state.position;
      final voDrops = int.parse(player.getProperty('frame-drop-count'));
      final decoderDrops = int.parse(
        player.getProperty('decoder-frame-drop-count'),
      );
      final voDelayed = int.parse(player.getProperty('vo-delayed-frame-count'));
      final stopwatch = Stopwatch()..start();
      await Future<void>.delayed(wallTime);
      stopwatch.stop();
      final measuredEnd = player.state.position;
      final result = DecoderBenchmarkResult(
        modeLabel: mode.label,
        targetSpeed: speed,
        wallTime: stopwatch.elapsed,
        mediaTime: measuredEnd > measuredStart
            ? measuredEnd - measuredStart
            : Duration.zero,
        voDrops: int.parse(player.getProperty('frame-drop-count')) - voDrops,
        decoderDrops:
            int.parse(player.getProperty('decoder-frame-drop-count')) -
            decoderDrops,
        voDelayed:
            int.parse(player.getProperty('vo-delayed-frame-count')) - voDelayed,
        avsync: player.getProperty('avsync'),
      );
      await pause(notify: false);
      return result;
    } finally {
      enableShowDanmakuAdaptive.value = oldDanmakuEnabled;
      showDanmaku = oldShowDanmaku;
      await seekTo(originalPosition, recordStats: false);
      await setPlaybackSpeed(originalSpeed, recordSelection: false);
      if (ndkCodec) await setDecoderLabNdkCodec(true);
      if (originalPlaying) {
        await play();
      } else {
        await pause(notify: false);
      }
    }
  }
}
