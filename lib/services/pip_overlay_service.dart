import 'dart:async';
import 'dart:math' show max, min;

import 'package:PiliBro/pages/video/controller.dart';
import 'package:PiliBro/plugin/pl_player/models/play_status.dart';
import 'package:PiliBro/services/service_locator.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 应用内小窗：视频页退场后，播放器单例和 [VideoDetailController] 的所有权
/// 交给浮在根 Overlay 上的小窗；点回去时页面复用同一个控制器，播放不中断。
/// 没有小窗时这里只有一个静态字段，不占任何资源。
abstract final class PipOverlayService {
  static VideoDetailController? _ctr;
  static OverlayEntry? _entry;

  static bool get active => _ctr != null;

  static bool owns(VideoDetailController ctr) => identical(_ctr, ctr);

  /// 从视频页进入小窗：弹出连续叠着的视频页，播放器和控制器留给小窗。
  /// 页面在 dispose 里看到 [owns] 为真就不释放它们
  static void start(VideoDetailController ctr) {
    if (_ctr != null) return;
    _ctr = ctr;
    Get.until((route) => route.settings.name != '/videoV');
    _entry = OverlayEntry(builder: (_) => const _PipWindow());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final overlay = Get.overlayContext;
      if (overlay == null || _entry == null) return;
      Overlay.of(overlay).insert(_entry!);
    });
  }

  /// 点击返回：撤掉小窗，用原参数重新打开视频页，页面发现控制器仍在就复用
  static void restore() {
    final ctr = _ctr;
    if (ctr == null) return;
    _entry?.remove();
    _entry = null;
    _ctr = null;
    Get.toNamed<void>('/videoV', arguments: ctr.args);
  }

  /// 关闭小窗并释放播放器和控制器，等同视频页正常退出。
  /// 打开任何新的视频、直播、音频页之前都要先调用，播放器是单例
  static void close() {
    final ctr = _ctr;
    if (ctr == null) return;
    _entry?.remove();
    _entry = null;
    _ctr = null;
    final player = ctr.plPlayerController;
    videoPlayerServiceHandler?.onVideoDetailDispose(ctr.heroTag);
    ctr.makeHeartBeat();
    Get.delete<VideoDetailController>(tag: ctr.heroTag, force: true);
    player.dispose();
  }
}

class _PipWindow extends StatefulWidget {
  const _PipWindow();

  @override
  State<_PipWindow> createState() => _PipWindowState();
}

class _PipWindowState extends State<_PipWindow> {
  static const _scales = [1.0, 1.5, 2.0];
  static const _ratio = 0.5625;
  static const _kLeft = 'pipLeft', _kTop = 'pipTop', _kScale = 'pipScale';

  final VideoDetailController _ctr = PipOverlayService._ctr!;
  late final _player = _ctr.plPlayerController;
  late final double _baseLong = PlatformUtils.isDesktop ? 320 : 200;

  late PlayerStatus _status = _player.playerStatus;
  double? _left;
  double? _top;
  double _scale = _readDouble(_kScale) ?? 1.0;
  double _scaleStart = 1.0;
  bool _showControls = true;
  Timer? _hideTimer;

  static double? _readDouble(String key) {
    final v = GStorage.localCache.get(key);
    return v is num ? v.toDouble() : null;
  }

  double get _width => (_vertical ? _ratio : 1) * _baseLong * _scale;
  double get _height => (_vertical ? 1 : _ratio) * _baseLong * _scale;
  bool get _vertical => _ctr.isVertical.value;

  @override
  void initState() {
    super.initState();
    _left = _readDouble(_kLeft);
    _top = _readDouble(_kTop);
    _player.addStatusLister(_onStatus);
    _restartHideTimer();
  }

  @override
  void dispose() {
    _player.removeStatusLister(_onStatus);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onStatus(PlayerStatus status) {
    if (mounted) setState(() => _status = status);
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    if (PlatformUtils.isDesktop) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _status.isPlaying) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _restartHideTimer();
  }

  void _togglePlay() {
    _status.isPlaying ? _player.pause() : _player.play();
    _restartHideTimer();
  }

  void _cycleScale() {
    final old = _scale;
    setState(() {
      _scale = _scales.firstWhere((e) => e > old + 0.01, orElse: () => 1.0);
    });
    _save();
  }

  void _save() {
    GStorage.localCache
      ..put(_kLeft, _left)
      ..put(_kTop, _top)
      ..put(_kScale, _scale);
  }

  void _zoom(double next) => _scale = next.clamp(0.6, 3.0);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final pad = media.padding;
    final w = min(_width, screen.width - 8);
    final h = min(_height, screen.height - 8);
    final minLeft = pad.left + 4;
    final minTop = pad.top + 4;
    final maxLeft = max(minLeft, screen.width - pad.right - w - 4);
    final maxTop = max(minTop, screen.height - pad.bottom - h - 4);
    final left = (_left ?? maxLeft - 8).clamp(minLeft, maxLeft);
    final top = (_top ?? maxTop - 72).clamp(minTop, maxTop);

    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            setState(() {
              _zoom(_scale * (event.scrollDelta.dy < 0 ? 1.1 : 0.9091));
            });
            _save();
          }
        },
        child: MouseRegion(
          onEnter: PlatformUtils.isDesktop
              ? (_) => setState(() => _showControls = true)
              : null,
          onExit: PlatformUtils.isDesktop
              ? (_) => setState(() => _showControls = false)
              : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTap: _cycleScale,
            onScaleStart: (_) => _scaleStart = _scale,
            onScaleUpdate: (details) {
              setState(() {
                if (details.pointerCount > 1) {
                  _zoom(_scaleStart * details.scale);
                }
                _left = left + details.focalPointDelta.dx;
                _top = top + details.focalPointDelta.dy;
              });
            },
            onScaleEnd: (_) => _save(),
            child: Material(
              color: Colors.black,
              elevation: 8,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Obx(() {
                    final revision = _player.videoOutputRevision.value;
                    final controller = _player.videoController;
                    if (controller == null) return const SizedBox.shrink();
                    return FittedBox(
                      child: SimpleVideo(
                        key: ValueKey(revision),
                        controller: controller,
                        fill: Colors.black,
                      ),
                    );
                  }),
                  if (_showControls) ...[
                    const ColoredBox(color: Colors.black38),
                    Center(
                      child: IconButton(
                        iconSize: 36,
                        color: Colors.white,
                        onPressed: _togglePlay,
                        icon: Icon(
                          _status.isPlaying
                              ? Icons.pause_circle_outline
                              : _status.isCompleted
                              ? Icons.replay_circle_filled_outlined
                              : Icons.play_circle_outline,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: IconButton(
                        tooltip: '返回',
                        iconSize: 20,
                        color: Colors.white,
                        onPressed: PipOverlayService.restore,
                        icon: const Icon(Icons.open_in_full),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        tooltip: '关闭',
                        iconSize: 20,
                        color: Colors.white,
                        onPressed: PipOverlayService.close,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}