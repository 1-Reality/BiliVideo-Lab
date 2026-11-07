import 'dart:io' show Platform;

import 'package:PiliBro/models/common/focus_reaction.dart';
import 'package:PiliBro/pages/audio/session.dart';
import 'package:PiliBro/plugin/pl_player/controller.dart';
import 'package:PiliBro/services/service_locator.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:media_kit/media_kit.dart';

/// 播放期间和系统打交道的几件事：音频焦点、拔耳机、进后台时屏幕亮没亮。
/// 视频和听视频共用，作用在正在出声的那个播放器上。
/// 安卓用自己的原生实现（PlaybackBridge），按焦点变化的类型分别反应；
/// 其他平台仍交给 audio_session。设置都在事件发生时现读
abstract final class PlaybackFocus {
  static const _channel = MethodChannel('pilibro/playback');

  // 被压低的播放器和它压低前的音量
  static Player? _ducked;
  static double _volume = 100;
  // 短暂失去焦点时暂停的播放器，拿回焦点后恢复
  static Player? _paused;

  static void init() {
    if (Platform.isAndroid) _channel.setMethodCallHandler(_onCall);
  }

  /// 播放器开始出声
  static void onStart() {
    _restore();
    _paused = null;
    if (Platform.isAndroid) {
      _channel.invokeMethod('start', Pref.focusTakeover);
    } else {
      audioSessionHandler?.setActive(true);
    }
  }

  /// 用户主动暂停。另一个播放器还在出声时（视频和听视频交接的瞬间）不让出焦点
  static void onStop() {
    if (_playing != null) return;
    _restore();
    _paused = null;
    if (Platform.isAndroid) {
      _channel.invokeMethod('stop');
    } else {
      audioSessionHandler?.setActive(false);
    }
  }

  static void onNoisy() {
    if (!Pref.pauseOnNoisy) return;
    PlPlayerController.pauseIfExists();
    AudioPlaybackSession.current.value?.onPause();
  }

  /// 进后台时是否继续播放。回桌面和锁屏分开设置，两个一样时不用问系统
  static Future<bool> keepInBackground(bool background, bool lock) async {
    if (background == lock || !Platform.isAndroid) return background;
    final screenOn =
        await _channel.invokeMethod<bool>('isInteractive') ?? true;
    return screenOn ? background : lock;
  }

  static Player? get _playing {
    final video = PlPlayerController.playerIfExists;
    if (video?.state.playing ?? false) return video;
    final audio = AudioPlaybackSession.current.value?.player;
    if (audio?.state.playing ?? false) return audio;
    return null;
  }

  static Future<void> _onCall(MethodCall call) async {
    if (call.method == 'noisy') {
      onNoisy();
      return;
    }
    switch (call.arguments) {
      // 别人短暂发声并允许压低：导航、提示音
      case 'duck':
        _react(Pref.focusOnDuck);
      // 别人长期拿走焦点：另一个 App 开始放歌，之后不会再还回来
      case 'loss':
        _react(Pref.focusOnLoss);
      // 别人短暂占用并要求暂停：来电、语音助手
      case 'transient':
        _pause();
      case 'gain':
        _restore();
        _paused?.play();
        _paused = null;
    }
  }

  static void _react(FocusReaction reaction) {
    switch (reaction) {
      case FocusReaction.ignore:
        break;
      case FocusReaction.duck:
        final player = _playing;
        if (player == null || _ducked != null) return;
        _ducked = player;
        _volume = player.state.volume;
        player.setVolume(_volume * Pref.duckPercent / 100);
      case FocusReaction.pause:
        _pause();
    }
  }

  static void _pause() {
    final player = _playing;
    if (player == null) return;
    _paused = player;
    player.pause();
  }

  static void _restore() {
    final player = _ducked;
    if (player == null) return;
    _ducked = null;
    // 压低期间播放器可能已经释放
    player.setVolume(_volume).ignore();
  }
}