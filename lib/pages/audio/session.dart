import 'package:PiliBro/pages/audio/controller.dart';
import 'package:PiliBro/grpc/bilibili/app/listener/v1.pbenum.dart' show PlaylistSource;
import 'package:PiliBro/services/playback_focus.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Keep audio playback alive while its detail route is not on screen.
/// This service is only instantiated after entering an audio page.
abstract final class AudioPlaybackSession {
  static const _tag = 'persistentAudioSession';
  static final current = Rxn<AudioController>();
  static final visiblePages = 0.obs;
  static Map<String, dynamic>? _arguments;

  static void prepare(Map<String, dynamic> arguments) {
    final active = current.value;
    if (active != null) {
      final local = arguments['offlineEntry'];
      final sameTrack = local != null
          ? active.localItem.value?.avid == local.avid &&
              active.localItem.value?.cid == local.cid
          : active.localItem.value == null &&
              active.oid.toInt() == arguments['oid'] &&
              active.subId.firstOrNull?.toInt() ==
                  (arguments['subId'] as List<int>?)?.firstOrNull &&
              active.itemType == arguments['itemType'];
      if (!sameTrack) stop();
    }
    _arguments = arguments;
  }

  static AudioController attach() {
    final existing = current.value;
    if (existing != null) return existing;
    final controller = Get.put(
      AudioController(launchArguments: _arguments ?? Get.arguments),
      tag: _tag,
      permanent: true,
    );
    // 听视频页在路由 build 期间创建，此时通知底部播放条（不在同一棵子树）会
    // 触发 setState during build，等这一帧结束再通知
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => current.value = controller,
    );
    WidgetsBinding.instance.addObserver(_lifecycle);
    return controller;
  }

  static void onPageOpened() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => visiblePages.value++);

  static void onPageClosed() {
    if (visiblePages.value > 0) visiblePages.value--;
    if (Pref.audioContinueOnLeave) return;
    // 页面还在释放中，等这一帧结束再关；期间又打开了听视频页就不关
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (visiblePages.value == 0) stop();
    });
  }

  static Future<void>? reopen() {
    if (current.value == null || _arguments == null) return null;
    return Get.toNamed<void>('/audio', arguments: _arguments);
  }

  /// Transfer a video page currently in "listen to video" mode on exit.
  /// The video Player itself can still be disposed normally.
  static void continueFromVideo({
    required int aid,
    required int cid,
    required Duration progress,
    String? audioUrl,
  }) {
    final previous = current.value;
    if (previous != null && previous.localItem.value == null &&
        previous.oid.toInt() == aid && previous.subId.first.toInt() == cid) {
      previous.onSeek(progress);
      previous.onPlay();
      return;
    }
    final args = <String, dynamic>{
      'oid': aid,
      'subId': [cid],
      'itemType': 1,
      'from': PlaylistSource.UP_ARCHIVE,
      'start': progress,
      if (audioUrl != null && audioUrl.isNotEmpty) 'audioUrl': audioUrl,
    };
    prepare(args);
    attach();
  }

  static void pauseForVideo() => current.value?.onPause();

  static final _lifecycle = _BackgroundPause();

  static void stop() {
    final active = current.value;
    current.value = null;
    _arguments = null;
    WidgetsBinding.instance.removeObserver(_lifecycle);
    active?.onPause();
    if (Get.isRegistered<AudioController>(tag: _tag)) {
      Get.delete<AudioController>(tag: _tag, force: true);
    }
  }
}

/// 听视频进后台时按设置暂停，回到前台时恢复由它暂停的播放
class _BackgroundPause with WidgetsBindingObserver {
  bool _paused = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = AudioPlaybackSession.current.value;
    if (controller == null) return;
    if (state == AppLifecycleState.paused) {
      if (!controller.isPlaying()) return;
      PlaybackFocus.keepInBackground(
        Pref.audioBackgroundPlay,
        Pref.audioLockPlay,
      ).then((keep) {
        if (keep ||
            !controller.isPlaying() ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          return;
        }
        _paused = true;
        controller.onPause();
      });
    } else if (state == AppLifecycleState.resumed && _paused) {
      _paused = false;
      controller.onPlay();
    }
  }
}
