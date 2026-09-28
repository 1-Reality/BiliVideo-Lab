import 'package:PiliBro/pages/audio/controller.dart';
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
    current.value = controller;
    return controller;
  }

  static void onPageOpened() => visiblePages.value++;

  static void onPageClosed() {
    if (visiblePages.value > 0) visiblePages.value--;
  }

  static Future<void>? reopen() {
    if (current.value == null || _arguments == null) return null;
    return Get.toNamed<void>('/audio', arguments: _arguments);
  }

  static void pauseForVideo() => current.value?.onPause();

  static void stop() {
    final active = current.value;
    current.value = null;
    _arguments = null;
    active?.onPause();
    if (Get.isRegistered<AudioController>(tag: _tag)) {
      Get.delete<AudioController>(tag: _tag, force: true);
    }
  }
}
