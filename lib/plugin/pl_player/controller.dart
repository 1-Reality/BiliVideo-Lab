import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:convert' show ascii, utf8;
import 'dart:io' show Platform;
import 'dart:math' show min;
import 'dart:ui' as ui;

import 'package:PiliBro/common/assets.dart';
import 'package:PiliBro/http/browser_ua.dart';
import 'package:PiliBro/http/constants.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/video.dart';
import 'package:PiliBro/models/common/account_type.dart';
import 'package:PiliBro/models/common/audio_normalization.dart';
import 'package:PiliBro/models/common/network_profile.dart';
import 'package:PiliBro/models/common/super_resolution_type.dart';
import 'package:PiliBro/models/common/video/video_decode_type.dart';
import 'package:PiliBro/models/common/video/video_type.dart';
import 'package:PiliBro/models/user/danmaku_rule.dart';
import 'package:PiliBro/models/video/play/url.dart';
import 'package:PiliBro/models_new/video/video_shot/data.dart';
import 'package:PiliBro/pages/danmaku/danmaku_model.dart';
import 'package:PiliBro/pages/setting/models/play_settings.dart'
    show kMaxVolume;
import 'package:PiliBro/pages/sponsor_block/block_mixin.dart';
import 'package:PiliBro/plugin/pl_player/models/data_source.dart';
import 'package:PiliBro/plugin/pl_player/models/data_status.dart';
import 'package:PiliBro/plugin/pl_player/models/double_tap_type.dart';
import 'package:PiliBro/plugin/pl_player/models/duration.dart';
import 'package:PiliBro/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliBro/plugin/pl_player/models/heart_beat_type.dart';
import 'package:PiliBro/plugin/pl_player/models/orientation_mode.dart';
import 'package:PiliBro/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliBro/plugin/pl_player/models/play_status.dart';
import 'package:PiliBro/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliBro/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliBro/services/service_locator.dart';
import 'package:PiliBro/services/playback_stats_service.dart';
import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/android/android_helper.dart';
import 'package:PiliBro/utils/android/bindings.g.dart';
import 'package:PiliBro/utils/asset_utils.dart';
import 'package:PiliBro/utils/connectivity_utils.dart';
import 'package:PiliBro/utils/device_utils.dart';
import 'package:PiliBro/utils/duration_utils.dart';
import 'package:PiliBro/utils/extension/box_ext.dart';
import 'package:PiliBro/utils/extension/num_ext.dart';
import 'package:PiliBro/utils/feed_back.dart';
import 'package:PiliBro/utils/image_utils.dart';
import 'package:PiliBro/utils/page_utils.dart';
import 'package:PiliBro/utils/orientation_policy.dart';
import 'package:PiliBro/plugin/pl_player/utils/orientation_platform.dart';
import 'package:PiliBro/utils/path_utils.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:archive/archive.dart' show getCrc32;
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show HapticFeedback, DeviceOrientation;
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:path/path.dart' as path;
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

typedef PlayCallback = Future<void>? Function();

class PlPlayerController with BlockConfigMixin, WidgetsBindingObserver {
  Player? _videoPlayerController;
  VideoController? _videoController;

  static PlPlayerController? _instance;

  final playerStatus = PlPlayerStatus(.playing);

  final Rx<DataStatus> dataStatus = Rx(.none);

  Duration? seekToPos;
  bool hasToasted = false;
  final RxBool isSeeking = false.obs;

  final RxInt position = RxInt(0);

  int get positionInMilliseconds =>
      videoPlayerController?.state.position.inMilliseconds ?? 0;

  final RxInt buffered = RxInt(0);

  final RxInt duration = RxInt(0);

  int durationInMilliseconds = 0;

  void updateDuration(Duration value) {
    duration.value = value.inSeconds;
    durationInMilliseconds = value.inMilliseconds;
  }

  int _playerCount = 0;

  late double lastPlaybackSpeed = 1.0;
  final RxDouble _playbackSpeed = Pref.playSpeedDefault.obs;
  late final RxDouble _longPressSpeed = Pref.longPressSpeedDefault.obs;

  final RxDouble volume = RxDouble(
    PlatformUtils.isDesktop ? Pref.desktopVolume : 1.0,
  );
  final setSystemBrightness = Pref.setSystemBrightness;

  final RxDouble brightness = (-1.0).obs;

  final RxBool showControls = false.obs;

  final RxBool showBrightnessStatus = false.obs;

  final RxBool longPressStatus = false.obs;

  final RxBool controlsLock = false.obs;

  final RxBool isFullScreen = false.obs;
  bool isLive = false;

  bool _isVertical = false;

  final Rx<VideoFitType> videoFit = Rx(.contain);

  late final RxBool continuePlayInBackground =
      Pref.continuePlayInBackground.obs;

  bool _autoPlay = false;

  // 记录历史记录
  int? _aid;
  String? _bvid;
  int? cid;
  int? _epid;
  int? _seasonId;
  int? _pgcType;
  VideoType _videoType = VideoType.ugc;
  int _heartDuration = 0;
  int _lastPositionEventSecond = -1;
  final Stopwatch _positionClock = Stopwatch()..start();
  late final int _statsSampleTicks = _positionClock.frequency >> 1;
  int _nextStatsSampleTick = 0;
  int? width;
  int? height;

  late final tryLook = !Accounts.get(AccountType.video).isLogin && Pref.p1080;

  late DataSource dataSource;

  Timer? _timer;
  Timer? _weakWifiBufferTimer;
  StreamSubscription? _subForSeek;
  StreamSubscription<NetworkPolicyChange>? _networkPolicySubscription;
  Future<void> Function(NetworkPolicyChange change)? onNetworkPolicyChanged;
  Future<bool> Function()? onCdnFallback;

  Box setting = GStorage.setting;

  // final Durations durations;

  String get bvid => _bvid!;

  /// 视频播放速度
  double get playbackSpeed => _playbackSpeed.value;

  // 长按倍速
  double get longPressSpeed => _longPressSpeed.value;

  /// [videoPlayerController] instance of Player
  Player? get videoPlayerController => _videoPlayerController;

  /// [videoController] instance of Player
  VideoController? get videoController => _videoController;

  bool isMuted = false;

  /// 听视频
  late final RxBool onlyPlayAudio = false.obs;

  /// 镜像
  late final RxBool flipX = false.obs;

  late final RxBool flipY = false.obs;

  final RxBool isBuffering = true.obs;

  /// 全屏方向
  // ignore: unnecessary_getters_setters
  bool get isVertical => _isVertical;

  set isVertical(bool value) {
    _isVertical = value;
  }

  /// 弹幕开关
  late final RxBool enableShowDanmaku = Pref.enableShowDanmaku.obs;
  late final RxBool enableShowLiveDanmaku = Pref.enableShowLiveDanmaku.obs;
  RxBool get enableShowDanmakuAdaptive =>
      isLive ? enableShowLiveDanmaku : enableShowDanmaku;

  late final bool autoPiP = Pref.autoPiP;
  bool get isPipMode =>
      (Platform.isAndroid && AndroidHelper.isPipMode) ||
      (PlatformUtils.isDesktop && isDesktopPip);
  late bool isDesktopPip = false;
  late Rect _lastWindowBounds;

  late final showWindowTitleBar = Pref.showWindowTitleBar;
  late final RxBool isAlwaysOnTop = false.obs;
  Future<void> setAlwaysOnTop(bool value) {
    isAlwaysOnTop.value = value;
    return windowManager.setAlwaysOnTop(value);
  }

  Future<void> exitDesktopPip() {
    isDesktopPip = false;
    PlaybackStatsService.changePlaybackForm(
      'window',
      videoPlayerController?.state.position ?? Duration.zero,
    );
    return Future.wait([
      if (showWindowTitleBar)
        windowManager.setTitleBarStyle(TitleBarStyle.normal),
      windowManager.setMinimumSize(const Size(400, 700)),
      windowManager.setBounds(_lastWindowBounds),
      setAlwaysOnTop(false),
      windowManager.setAspectRatio(0),
    ]);
  }

  Future<void> enterDesktopPip() async {
    if (isFullScreen.value) return;

    isDesktopPip = true;
    PlaybackStatsService.changePlaybackForm(
      'pip',
      videoPlayerController?.state.position ?? Duration.zero,
    );

    _lastWindowBounds = await windowManager.getBounds();

    if (showWindowTitleBar) {
      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }

    final Size size;
    final state = videoPlayerController!.state;
    int width = state.width;
    int height = state.height;
    if (width == 0) {
      width = this.width ?? 16;
    }
    if (height == 0) {
      height = this.height ?? 9;
    }
    if (height > width) {
      size = Size(280.0, 280.0 * height / width);
    } else {
      size = Size(280.0 * width / height, 280.0);
    }

    await windowManager.setMinimumSize(size);
    setAlwaysOnTop(true);
    windowManager
      ..setSize(size)
      ..setAspectRatio(width / height);
  }

  void toggleDesktopPip() {
    if (isDesktopPip) {
      exitDesktopPip();
    } else {
      enterDesktopPip();
    }
  }

  late bool _isAutoEnterPip = false;
  bool get isAutoEnterPip => _isAutoEnterPip;

  static bool get _isCurrVideoPage {
    final routing = Get.routing;
    return routing.route is GetPageRoute && _isVideoPage(routing.current);
  }

  static bool _isVideoPage(String routeName) {
    return routeName == '/videoV' || routeName == '/liveRoom';
  }

  void enterPip({bool autoEnter = false}) {
    if (videoPlayerController != null) {
      final state = videoPlayerController!.state;
      PageUtils.enterPip(
        autoEnter: autoEnter,
        width: state.width == 0 ? width : state.width,
        height: state.height == 0 ? height : state.height,
        isLive: isLive,
        isPlaying: playerStatus.isPlaying,
      );
    }
  }

  void _disableAutoEnterPip() {
    if (_isAutoEnterPip) {
      PiliAndroidHelper.disableAutoEnterPip();
    }
  }

  // 弹幕相关配置
  late final enableTapDm = PlatformUtils.isMobile && Pref.enableTapDm;
  late RuleFilter filters = Pref.danmakuFilterRule;
  // 关联弹幕控制器
  DanmakuController<DanmakuExtra>? danmakuController;
  bool showDanmaku = true;
  Set<int> dmState = <int>{};
  late final mergeDanmaku = Pref.mergeDanmaku;
  late final String midHash = getCrc32(
    ascii.encode(Accounts.main.mid.toString()),
    0,
  ).toRadixString(16);
  late final RxDouble danmakuOpacity = Pref.danmakuOpacity.obs;

  late List<double> speedList = Pref.speedList;
  late bool enableAutoLongPressSpeed = Pref.enableAutoLongPressSpeed;
  late double longPressSpeedFactor = Pref.longPressSpeedFactor;
  late bool enableLongPressSlideSpeed = Pref.enableLongPressSlideSpeed;
  late final showControlDuration = Pref.enableLongShowControl
      ? const Duration(seconds: 30)
      : const Duration(seconds: 3);
  // 字幕
  late double subtitleFontScale = Pref.subtitleFontScale;
  late double subtitleFontScaleFS = Pref.subtitleFontScaleFS;
  late int subtitlePaddingH = Pref.subtitlePaddingH;
  late int subtitlePaddingB = Pref.subtitlePaddingB;
  late double subtitleBgOpacity = Pref.subtitleBgOpacity;
  final bool showVipDanmaku = Pref.showVipDanmaku; // loop unswitching
  late double subtitleStrokeWidth = Pref.subtitleStrokeWidth;
  late int subtitleFontWeight = Pref.subtitleFontWeight;

  // settings
  late final showFSActionItem = Pref.showFSActionItem;
  late final enableShrinkVideoSize = Pref.enableShrinkVideoSize;
  late final darkVideoPage = Pref.darkVideoPage;
  late final enableSlideVolumeBrightness = Pref.enableSlideVolumeBrightness;
  late final enableSlideFS = Pref.enableSlideFS;
  late final enableDragSubtitle = Pref.enableDragSubtitle;
  late final fastForBackwardDuration = Duration(
    seconds: Pref.fastForBackwardDuration,
  );

  late final horizontalSeasonPanel = Pref.horizontalSeasonPanel;
  late final preInitPlayer = Pref.preInitPlayer;
  late final showRelatedVideo = Pref.showRelatedVideo;
  late final showVideoReply = Pref.showVideoReply;
  late final showBangumiReply = Pref.showBangumiReply;
  late final reverseFromFirst = Pref.reverseFromFirst;
  late final horizontalPreview = Pref.horizontalPreview;
  late final showDmChart = Pref.showDmChart;
  late final showViewPoints = Pref.showViewPoints;
  late final showFsScreenshotBtn = Pref.showFsScreenshotBtn;
  late final showFsLockBtn = Pref.showFsLockBtn;
  late final keyboardControl = Pref.keyboardControl;
  late final uiScale = Pref.uiScale;

  late final bool autoEnterFullScreen = Pref.autoEnterFullScreen;
  late final bool autoExitFullscreen = Pref.autoExitFullscreen;
  late final bool autoPlayEnable = Pref.autoPlayEnable;
  late final bool enableVerticalExpand = Pref.enableVerticalExpand;
  late final bool pipNoDanmaku = Pref.pipNoDanmaku;

  late final bool tempPlayerConf = Pref.tempPlayerConf;

  int? cacheVideoQa;
  late int cacheAudioQa = Pref.defaultAudioQa;
  List<VideoDecodeFormatType>? cachePreferCodecs;
  List<VideoDecodeFormatType>? peakPreferCodecs;
  NetworkProfile? playbackNetworkProfile;
  int _networkProfileResolutions = 0;
  bool enableHeart = true;
  late final String? hwdec = Pref.enableHA ? Pref.hardwareDecoding : null;
  bool _hwdecFallbackToastShown = false;
  String? get _automaticHwdecFallback {
    final modes = hwdec?.split(',') ?? const <String>[];
    for (final mode in modes.skip(1)) {
      if (mode == 'auto' || mode == 'auto-safe' || mode == 'auto-copy') {
        return mode;
      }
    }
    return null;
  }

  late final progressType = Pref.btmProgressBehavior;
  late final enableQuickDouble = Pref.enableQuickDouble;
  late final fullScreenGestureReverse = Pref.fullScreenGestureReverse;

  late final isRelative = Pref.useRelativeSlide;
  late final offset = isRelative
      ? Pref.sliderDuration * 0.01
      : Pref.sliderDuration * 1000;

  num get sliderScale => isRelative ? durationInMilliseconds * offset : offset;

  // 播放顺序相关
  late PlayRepeat playRepeat = Pref.playRepeat;

  TextStyle get subTitleStyle => TextStyle(
    height: 1.5,
    fontSize:
        16 * (isFullScreen.value ? subtitleFontScaleFS : subtitleFontScale),
    letterSpacing: 0.1,
    wordSpacing: 0.1,
    color: Colors.white,
    fontWeight: FontWeight.values[subtitleFontWeight],
    backgroundColor: subtitleBgOpacity == 0
        ? null
        : Colors.black.withValues(alpha: subtitleBgOpacity),
  );

  late final Rx<SubtitleViewConfiguration> subtitleConfig = getSubConfig.obs;

  SubtitleViewConfiguration get getSubConfig {
    final subTitleStyle = this.subTitleStyle;
    return SubtitleViewConfiguration(
      style: subTitleStyle,
      strokeStyle: subtitleBgOpacity == 0
          ? subTitleStyle.copyWith(
              color: null,
              background: null,
              backgroundColor: null,
              foreground: Paint()
                ..color = Colors.black
                ..style = PaintingStyle.stroke
                ..strokeWidth = subtitleStrokeWidth,
            )
          : null,
      padding: EdgeInsets.only(
        left: subtitlePaddingH.toDouble(),
        right: subtitlePaddingH.toDouble(),
        bottom: subtitlePaddingB.toDouble(),
      ),
      textScaleFactor: 1,
    );
  }

  void updateSubtitleStyle() {
    subtitleConfig.value = getSubConfig;
  }

  void onUpdatePadding(EdgeInsets padding) {
    subtitlePaddingB = padding.bottom.round().clamp(0, 200);
    putSubtitleSettings();
  }

  static PlPlayerController? get instance => _instance;

  static bool instanceExists() {
    return _instance != null;
  }

  static void setPlayCallBack(PlayCallback? playCallBack) {
    _playCallBack = playCallBack;
  }

  static PlayCallback? _playCallBack;

  static Future<void>? playIfExists() {
    return _playCallBack?.call();
  }

  // try to get PlayerStatus
  static PlayerStatus? getPlayerStatusIfExists() {
    return _instance?.playerStatus.value;
  }

  static Future<void> pauseIfExists({
    bool notify = true,
    bool isInterrupt = false,
  }) async {
    if (_instance?.playerStatus.isPlaying ?? false) {
      await _instance?.pause(notify: notify, isInterrupt: isInterrupt);
    }
  }

  static Future<void> seekToIfExists(
    Duration position, {
    bool isSeek = true,
    bool recordStats = true,
  }) async {
    await _instance?.seekTo(
      position,
      isSeek: isSeek,
      recordStats: recordStats,
    );
  }

  static double? getVolumeIfExists() {
    return _instance?.volume.value;
  }

  static Future<void>? setVolumeIfExists(
    double volumeNew, {
    bool showIndicator = true,
  }) {
    return _instance?.setVolume(volumeNew, showIndicator: showIndicator);
  }

  Box video = GStorage.video;

  bool visible = true;

  DeviceOrientation? _orientation;
  bool? _systemLandscape;
  bool? _gravityLandscape;
  bool _observingSystemOrientation = false;
  int _fullScreenAllowedMask = OrientationMask.all;
  bool _entryDirectionApplied = false;
  bool? _entryTargetLandscape;
  bool _pendingSystemHandoff = false;
  bool _pendingSystemHandoffIgnoreLock = false;
  FullscreenEntryCause _fullScreenEntryCause = FullscreenEntryCause.manual;
  StreamSubscription<OrientationParams>? _orientationListener;
  late final OrientationPlan _orientationPlan = OrientationPolicy.plan;

  bool get _currentSystemLandscape {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return false;
    final size = views.first.physicalSize;
    return size.width > size.height;
  }

  bool get _needsSystemOrientation {
    if (_pendingSystemHandoff) return true;
    final plan = _orientationPlan;
    if (isFullScreen.value) {
      return plan.triggerExit &&
          plan.exitAllowsCause(_fullScreenEntryCause) &&
          plan.sourceUsesSystem(plan.exitTriggerSource);
    }
    return plan.triggerEnter &&
        plan.sourceUsesSystem(plan.enterTriggerSource);
  }

  bool get _needsGravityOrientation {
    final plan = _orientationPlan;
    if (!plan.gravityAllowed) return false;
    if (isFullScreen.value) {
      if (plan.triggerExit &&
          plan.exitAllowsCause(_fullScreenEntryCause) &&
          plan.sourceUsesGravity(plan.exitTriggerSource)) {
        return true;
      }
      return (!controlsLock.value || !plan.controlsLockOrientation) &&
          plan.fullScreenRotationSource ==
              FullScreenRotationSource.appGravity &&
          plan.fullScreenAllowed != FullScreenAllowedOrientation.entryExact &&
          plan.filterMask(_fullScreenAllowedMask) != 0;
    }
    return plan.triggerEnter &&
        plan.sourceUsesGravity(plan.enterTriggerSource);
  }

  void _updateOrientationInputs() {
    if (!PlatformUtils.isMobile) return;

    final needsSystem = _needsSystemOrientation;
    if (needsSystem && !_observingSystemOrientation) {
      _systemLandscape = _currentSystemLandscape;
      WidgetsBinding.instance.addObserver(this);
      _observingSystemOrientation = true;
    } else if (!needsSystem && _observingSystemOrientation) {
      WidgetsBinding.instance.removeObserver(this);
      _observingSystemOrientation = false;
    }

    final needsGravity = _needsGravityOrientation;
    if (needsGravity && _orientationListener == null) {
      _orientationListener = NativeDeviceOrientationPlatform.instance
          .onOrientationChanged(
            checkIsAutoRotate: false,
            angleDegrees: Platform.isAndroid ? _orientationPlan.angleDegrees : null,
          )
          .listen(_onOrientationChanged);
    } else if (!needsGravity) {
      _stopOrientationListener();
    }
  }

  void _stopOrientationListener() {
    _orientationListener?.cancel();
    _orientationListener = null;
  }

  @override
  void didChangeMetrics() {
    if (!_observingSystemOrientation) return;
    final next = _currentSystemLandscape;
    if (_pendingSystemHandoff) {
      unawaited(_tryCompleteSystemHandoff(next));
    }
    if (_systemLandscape == next) return;
    _systemLandscape = next;
    _evaluateOrientationTrigger();
  }

  void _onOrientationChanged(OrientationParams param) {
    _orientation = param.orientation;
    if (Platform.isIOS && !visible) return;
    _gravityLandscape =
        param.orientation == DeviceOrientation.landscapeLeft ||
        param.orientation == DeviceOrientation.landscapeRight;
    if (isFullScreen.value &&
        _orientationPlan.fullScreenRotationSource ==
            FullScreenRotationSource.appGravity &&
        (!controlsLock.value || !_orientationPlan.controlsLockOrientation)) {
      _applyGravityOrientation(param.orientation);
    }
    _evaluateOrientationTrigger();
  }

  void _applyGravityOrientation(DeviceOrientation orientation) {
    final bit = OrientationPolicy.orientationBit(orientation);
    if (_fullScreenAllowedMask & bit == 0 ||
        _orientationPlan.filterMask(bit) == 0) {
      return;
    }
    switch (orientation) {
      case DeviceOrientation.portraitUp:
        portraitUpMode();
      case DeviceOrientation.portraitDown:
        portraitDownMode();
      case DeviceOrientation.landscapeLeft:
        landscapeLeftMode();
      case DeviceOrientation.landscapeRight:
        landscapeRightMode();
    }
  }

  bool _triggerSourceMatches(
    OrientationTriggerSource source,
    bool landscape,
  ) {
    return switch (source) {
      OrientationTriggerSource.system => _systemLandscape == landscape,
      OrientationTriggerSource.appGravity => _gravityLandscape == landscape,
      OrientationTriggerSource.any =>
        _systemLandscape == landscape || _gravityLandscape == landscape,
      OrientationTriggerSource.both =>
        _systemLandscape == landscape && _gravityLandscape == landscape,
    };
  }

  void _evaluateOrientationTrigger() {
    if (_fsProcessing || controlsLock.value) return;
    final plan = _orientationPlan;
    if (!isFullScreen.value) {
      if (plan.triggerEnter &&
          plan.contentAllows(_isVertical) &&
          _triggerSourceMatches(plan.enterTriggerSource, true)) {
        triggerFullScreen(cause: FullscreenEntryCause.orientation);
      }
      return;
    }
    if (plan.triggerExit &&
        plan.exitAllowsCause(_fullScreenEntryCause) &&
        _triggerSourceMatches(plan.exitTriggerSource, false)) {
      triggerFullScreen(
        status: false,
        cause: FullscreenEntryCause.orientation,
      );
    }
  }

  // 添加一个私有构造函数
  PlPlayerController._() {
    _networkPolicySubscription = ConnectivityUtils.changes.listen((change) {
      onNetworkPolicyChanged?.call(change);
    });
    _updateOrientationInputs();

    if (!Accounts.heartbeat.isLogin || Pref.historyPause) {
      enableHeart = false;
    }

    if (Platform.isAndroid && autoPiP) {
      if (DeviceUtils.sdkInt < 31) {
        AndroidHelper$ToDart.onUserLeaveHint = Runnable.implement(
          $Runnable(run: _onUserLeaveHint),
        );
      } else {
        _isAutoEnterPip = true;
      }
    }
  }

  void applyNetworkProfile(
    NetworkProfile profile, {
    required bool resetSessionPreferences,
    bool refreshPeakPreferences = false,
  }) {
    playbackNetworkProfile = profile;
    if (resetSessionPreferences) {
      cacheVideoQa = profile.useCellularPreferences
          ? Pref.defaultVideoQaCellular
          : Pref.defaultVideoQa;
      cacheAudioQa = profile.useCellularPreferences
          ? Pref.defaultAudioQaCellular
          : Pref.defaultAudioQa;
      cachePreferCodecs = profile.useCellularPreferences
          ? Pref.preferCodecsCellular
          : Pref.preferCodecs;
    }
    final peakActive = ConnectivityUtils.isNetworkPeak(profile);
    if (resetSessionPreferences ||
        refreshPeakPreferences ||
        peakActive != (peakPreferCodecs != null)) {
      cachePreferCodecs ??= profile.useCellularPreferences
          ? Pref.preferCodecsCellular
          : Pref.preferCodecs;
      peakPreferCodecs = peakActive
          ? ConnectivityUtils.effectiveCodecs()
          : null;
    }
  }

  Future<NetworkProfile> resolveNetworkProfile() async {
    _networkProfileResolutions++;
    try {
      return await ConnectivityUtils.resolveForPlayback();
    } finally {
      _networkProfileResolutions--;
    }
  }

  bool get isResolvingNetworkProfile => _networkProfileResolutions != 0;

  List<VideoDecodeFormatType> get effectivePreferCodecs =>
      peakPreferCodecs ??
      cachePreferCodecs ??
      (playbackNetworkProfile?.useCellularPreferences == true
          ? Pref.preferCodecsCellular
          : Pref.preferCodecs);

  void _onUserLeaveHint() {
    if (playerStatus.isPlaying && _isCurrVideoPage) {
      enterPip();
    }
  }

  // 获取实例 传参
  static PlPlayerController getInstance({bool isLive = false}) {
    // 如果实例尚未创建，则创建一个新实例
    return (_instance ??= PlPlayerController._())
      ..isLive = isLive
      .._playerCount += 1;
  }

  bool _processing = false;
  bool get processing => _processing;

  // offline
  bool get isFileSource => dataSource is FileSource;

  bool get _hasKnownVideoOutputSize =>
      width != null && height != null && width! > 1 && height! > 1;

  late final _audioNormalization = Pref.audioNormalization;
  late final enableAudioNormalization =
      Platform.isAndroid && _audioNormalization != '0';
  late final String _audioNormalizationParam =
      AudioNormalization.getParamFromConfig(_audioNormalization);

  // 初始化资源
  Future<void> setDataSource(
    DataSource dataSource, {
    bool isLive = false,
    bool autoplay = true,
    // 初始化播放位置
    Duration? seekTo,
    // 初始化播放速度
    double speed = 1.0,
    int? width,
    int? height,
    Duration? duration,
    // 方向
    bool? isVertical,
    // 记录历史记录
    int? aid,
    String? bvid,
    int? cid,
    int? epid,
    int? seasonId,
    int? pgcType,
    int? liveUid,
    String? liveName,
    int? videoUpUid,
    String? videoUpName,
    int? partitionId,
    String? partitionName,
    String? copyright,
    String? codec,
    String? quality,
    VideoType? videoType,
    VoidCallback? onInit,
    Volume? volume,
    bool autoFullScreenFlag = false,
  }) async {
    final previousPosition =
        _videoPlayerController?.state.position ?? Duration.zero;
    try {
      _processing = true;
      this.isLive = isLive;
      _videoType = videoType ?? VideoType.ugc;
      this.width = width;
      this.height = height;
      this.dataSource = dataSource;
      _hwdecFallbackToastShown = false;
      _autoPlay = autoplay;
      // 初始化视频倍速
      // _playbackSpeed.value = speed;
      // 初始化数据加载状态
      dataStatus.value = DataStatus.loading;
      if (dataSource is FileSource) {
        final missingMedia = dataSource.missingMedia(
          audioOnly: onlyPlayAudio.value,
        );
        if (missingMedia != null) {
          dataStatus.value = DataStatus.error;
          SmartDialog.showToast(
            '离线缓存缺少文件：${path.basename(missingMedia)}',
          );
          return;
        }
      }
      // 初始化全屏方向
      _isVertical = isVertical ?? false;
      if (PlatformUtils.isMobile &&
          !isFullScreen.value &&
          _orientationPlan.windowedRotation !=
              WindowedPlayerRotationMode.inheritApp) {
        await OrientationPolicy.applyWindowedRuntime(
          _orientationPlan.windowedRotation,
        );
      }
      _aid = aid;
      _bvid = bvid;
      this.cid = cid;
      _epid = epid;
      _seasonId = seasonId;
      _pgcType = pgcType;

      if (showSeekPreview) {
        _clearPreview();
      }
      cancelLongPressTimer();
      if (_videoPlayerController != null &&
          _videoPlayerController!.state.playing) {
        await pause(notify: false);
      }

      if (_playerCount == 0) {
        return;
      }
      PlaybackStatsService.openMedia(
        isLive: isLive,
        previousPosition: previousPosition,
        initialPosition: seekTo ?? Duration.zero,
        speed: _playbackSpeed.value,
        defaultSpeed: Pref.playSpeedDefault,
        cid: cid,
        liveUid: liveUid,
        liveName: liveName,
        videoUpUid: videoUpUid,
        videoUpName: videoUpName,
        partitionId: partitionId,
        partitionName: partitionName,
        copyright: copyright,
        sourceDuration: duration,
        orientation: width == null ||
                height == null ||
                width <= 0 ||
                height <= 0
            ? 'unknown'
            : width == height
            ? 'square'
            : isVertical == true
            ? 'vertical'
            : 'horizontal',
        contentType: dataSource is FileSource
            ? 'local'
            : (videoType ?? VideoType.ugc).name,
        codec: codec,
        quality: quality,
        network: switch (ConnectivityUtils.current) {
          final profile? =>
            '${profile.transport.name}:${profile.useCellularPreferences ? 'cellularPreference' : 'broadbandPreference'}',
          null => 'unknown',
        },
        subtitle: Pref.subtitlePreferenceV2.name,
        danmakuEnabled: enableShowDanmakuAdaptive.value,
        decoder: hwdec ?? 'software',
      );
      // 配置Player 音轨、字幕等等
      await _createVideoController(dataSource, seekTo, volume);

      if (_playerCount == 0) {
        _removeListeners();
        _videoPlayerController?.dispose();
        _videoPlayerController = null;
        _videoController = null;
        return;
      }

      updateDuration(duration ?? _videoPlayerController!.state.duration);
      position.value = buffered.value = seekTo?.inSeconds ?? 0;

      dataStatus.value = .loaded;

      if (autoFullScreenFlag && autoEnterFullScreen) {
        triggerFullScreen(
          status: true,
          cause: FullscreenEntryCause.playbackAuto,
        );
      }

      await _initializePlayer();
      onInit?.call();
    } catch (err, stackTrace) {
      dataStatus.value = DataStatus.error;
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
        debugPrint('plPlayer err:  $err');
      }
    } finally {
      _processing = false;
    }
  }

  String? shadersDirPath;
  Future<String> get copyShadersToExternalDirectory async {
    if (shadersDirPath != null) {
      return shadersDirPath!;
    }

    return shadersDirPath = await AssetUtils.getOrCopy(
      'assets/shaders',
      Assets.mpvAnime4KShaders.followedBy(Assets.mpvAnime4KShadersLite),
      path.join(appSupportDirPath, 'anime_shaders'),
    );
  }

  late final isAnim = _pgcType == 1 || _pgcType == 4;
  late final Rx<SuperResolutionType> superResolutionType =
      (isAnim ? Pref.superResolutionType : SuperResolutionType.disable).obs;
  Future<void> setShader([SuperResolutionType? type, NativePlayer? pp]) async {
    if (type == null) {
      type = superResolutionType.value;
    } else {
      superResolutionType.value = type;
      if (isAnim && !tempPlayerConf) {
        setting.put(SettingBoxKey.superResolutionType, type.index);
      }
    }
    pp ??= _videoPlayerController!;
    switch (type) {
      case SuperResolutionType.disable:
        return pp.command(const ['change-list', 'glsl-shaders', 'clr', '']);
      case SuperResolutionType.efficiency:
        return pp.command([
          'change-list',
          'glsl-shaders',
          'set',
          PathUtils.buildShadersAbsolutePath(
            await copyShadersToExternalDirectory,
            Assets.mpvAnime4KShadersLite,
          ),
        ]);
      case SuperResolutionType.quality:
        return pp.command([
          'change-list',
          'glsl-shaders',
          'set',
          PathUtils.buildShadersAbsolutePath(
            await copyShadersToExternalDirectory,
            Assets.mpvAnime4KShaders,
          ),
        ]);
    }
  }

  static final loudnormRegExp = RegExp('loudnorm=([^,]+)');

  Future<Player> _initPlayer() async {
    assert(_videoPlayerController == null);
    final opt = {
      'video-sync': Pref.videoSync,
      if (Platform.isAndroid) 'ao': Pref.audioOutput,
      'volume':
          (PlatformUtils.isMobile ? Pref.playerVolume : volume.value * 100)
              .toString(),
      'volume-max': kMaxVolume.toString(),
    };
    final autosync = Pref.autosync;
    if (autosync != '0') {
      opt['autosync'] = autosync;
    }

    final player = await Player.create(
      configuration: PlayerConfiguration(
        logLevel: kDebugMode ? .warn : .error,
        options: opt,
      ),
    );

    assert(_videoController == null);

    _videoController = await VideoController.create(
      player,
      configuration: VideoControllerConfiguration(
        width: Platform.isWindows
            ? (hwdec != null && !_hasKnownVideoOutputSize
                  ? 1
                  : (_hasKnownVideoOutputSize ? width : null))
            : null,
        height: Platform.isWindows
            ? (hwdec != null && !_hasKnownVideoOutputSize
                  ? 1
                  : (_hasKnownVideoOutputSize ? height : null))
            : null,
        enableHardwareAcceleration: hwdec != null,
        androidAttachSurfaceAfterVideoParameters: false,
        hwdec: hwdec,
      ),
    );

    player.setMediaHeader(userAgent: BrowserUa.pc, referer: HttpString.baseUrl);

    _startListeners(player);

    return player;
  }

  // 配置播放器
  Future<void> _createVideoController(
    DataSource dataSource,
    Duration? seekTo,
    Volume? volume,
  ) async {
    _weakWifiBufferTimer?.cancel();
    _weakWifiBufferTimer = null;
    isBuffering.value = false;
    _heartDuration = 0;
    danmakuController?.clear();

    var player = _videoPlayerController;

    if (player == null) {
      player = await _initPlayer();
      if (_playerCount == 0) {
        _removeListeners();
        player.dispose();
        player = null;
        _videoController = null;
        return;
      }
      _videoPlayerController = player;
      if (isAnim && superResolutionType.value != .disable) {
        await setShader();
      }
    }

    if (Platform.isWindows && _hasKnownVideoOutputSize) {
      await _videoController?.setSize(width: width, height: height);
    }

    final profile = playbackNetworkProfile ?? ConnectivityUtils.current;
    final bufferProfile = profile?.transport == NetworkTransport.cellular
        ? 2
        : profile?.useCellularPreferences == true
        ? 1
        : 0;
    final Map<String, String> extras = {
      if (dataSource is FileSource)
        'cache': 'no'
      else if (isLive)
        ...Pref.initLiveBuffer(bufferProfile)
      else
        ...Pref.initBuffer(_playbackSpeed.value, bufferProfile),
    };

    String video = dataSource.videoSource;
    if (dataSource.audioSource case final audio? when (audio.isNotEmpty)) {
      if (onlyPlayAudio.value) {
        video = audio;
      } else {
        // dely_open need provide length
        video =
            ('edl://'
            '!no_chapters;'
            // '!delay_open,media_type=video;'
            '%${isFileSource ? utf8.encode(video).length : video.length}%$video;'
            '!new_stream;!no_chapters;'
            // '!delay_open,media_type=audio;'
            '%${isFileSource ? utf8.encode(audio).length : audio.length}%$audio');
      }
      if (enableAudioNormalization) {
        final String audioNormalization;
        if (volume != null && volume.isNotEmpty) {
          audioNormalization = _audioNormalizationParam.replaceFirstMapped(
            loudnormRegExp,
            (i) =>
                'loudnorm=${volume.format(
                  Map.fromEntries(
                    i.group(1)!.split(':').map((item) {
                      final parts = item.split('=');
                      return MapEntry(parts[0].toLowerCase(), num.parse(parts[1]));
                    }),
                  ),
                )}',
          );
        } else {
          audioNormalization = _audioNormalizationParam.replaceFirst(
            loudnormRegExp,
            AudioNormalization.getParamFromConfig(Pref.fallbackNormalization),
          );
        }
        if (audioNormalization.isNotEmpty) {
          extras['lavfi-complex'] = '"[aid1] $audioNormalization [ao]"';
        }
      }
    }

    await player.open(
      Media(
        video,
        start: seekTo,
        extras: extras.isEmpty ? null : extras,
      ),
      play: false,
    );
  }

  Future<void>? refreshPlayer() {
    if (dataSource is FileSource) {
      return null;
    }
    if (_videoPlayerController case final ctr? when (ctr.current.isNotEmpty)) {
      PlaybackStatsService.rebase(ctr.state.position);
      return ctr.open(
        ctr.current.last.copyWith(start: ctr.state.position),
        play: true,
      );
    }
    return null;
  }

  // 开始播放
  Future<void> _initializePlayer() async {
    if (_instance == null) return;
    // 设置倍速
    if (isLive) {
      await setPlaybackSpeed(1.0, recordSelection: false);
    } else {
      if (_videoPlayerController?.state.rate != _playbackSpeed.value) {
        await setPlaybackSpeed(_playbackSpeed.value, recordSelection: false);
      }
    }
    _initVideoFit();
    // if (_looping) {
    //   await setLooping(_looping);
    // }

    // 跳转播放
    // if (seekTo != Duration.zero) {
    //   await this.seekTo(seekTo);
    // }

    // 自动播放
    if (_autoPlay) {
      playIfExists();
      // await play(duration: duration);
    }
  }

  List<StreamSubscription>? _subscriptions;
  final Set<ValueChanged<Duration>> _positionListeners = {};
  final Set<ValueChanged<Duration>> _rawPositionListeners = {};
  final Set<ValueChanged<PlayerStatus>> _statusListeners = {};

  /// 播放事件监听
  void _startListeners(NativePlayer player) {
    assert(_subscriptions == null);
    final stream = player.stream;
    _subscriptions = [
      if (Platform.isWindows && hwdec != null)
        stream.videoParams.listen((params) {
          final dw = params.dw;
          final dh = params.dh;
          if (dw == null || dh == null || dw < 1 || dh < 1) return;
          final rotate = params.rotate ?? 0;
          if (rotate == 0 || rotate == 180) {
            _videoController?.setSize(width: dw, height: dh);
          } else {
            _videoController?.setSize(width: dh, height: dw);
          }
        }),

      /// playing
      stream.playing.listen((bool playing) {
        PlaybackStatsService.updatePlaying(playing, player.state.position);
        WakelockPlus.toggle(enable: playing);
        if (playing) {
          if (_isAutoEnterPip) {
            if (_isCurrVideoPage) {
              enterPip(autoEnter: true);
            } else {
              _disableAutoEnterPip();
            }
          }
          playerStatus.value = .playing;
        } else {
          _disableAutoEnterPip();
          playerStatus.value = .paused;
        }

        videoPlayerServiceHandler?.onStatusChange(
          playerStatus.value,
          isBuffering.value,
          isLive,
        );

        for (final element in _statusListeners) {
          element(playing ? .playing : .paused);
        }

        final seconds = videoPlayerController!.state.position.inSeconds;
        if (seconds != 0) {
          makeHeartBeat(seconds, type: .status);
        }
      }),

      ///completed
      stream.completed.listen((bool completed) {
        if (completed) {
          PlaybackStatsService.markCompleted(player.state.position);
          playerStatus.value = .completed;

          for (final element in _statusListeners) {
            element(.completed);
          }

          makeHeartBeat(-1, type: .completed);
        }
      }),

      /// position
      stream.position.listen((Duration position) {
        final ticks = _positionClock.elapsedTicks;
        if (ticks >= _nextStatsSampleTick) {
          _nextStatsSampleTick = ticks + _statsSampleTicks;
          PlaybackStatsService.samplePosition(position);
        }

        for (final element in _rawPositionListeners) {
          element(position);
        }

        final positionUs = position.inMicroseconds;
        final lastSecond = _lastPositionEventSecond;
        final secondStartUs = lastSecond * Duration.microsecondsPerSecond;
        if (lastSecond < 0 ||
            positionUs < secondStartUs ||
            positionUs >= secondStartUs + Duration.microsecondsPerSecond) {
          final posInSeconds = positionUs ~/ Duration.microsecondsPerSecond;
          _lastPositionEventSecond = posInSeconds;
          if (!isSeeking.value) {
            this.position.value = posInSeconds;
          }

          videoPlayerServiceHandler?.onPositionChange(position);
          makeHeartBeat(posInSeconds);
          for (final element in _positionListeners) {
            element(position);
          }
        }
      }),
      stream.duration.listen(updateDuration),
      stream.buffer.listen((Duration buffer) {
        buffered.value = buffer.inSeconds;
      }),
      stream.buffering.listen((bool buffering) {
        PlaybackStatsService.updateBuffering(
          buffering,
          player.state.position,
        );
        isBuffering.value = buffering;
        if (buffering && !isLive) {
          _weakWifiBufferTimer ??= Timer(const Duration(seconds: 5), () {
            _weakWifiBufferTimer = null;
            if (isBuffering.value && playerStatus.isPlaying) {
              ConnectivityUtils.markCurrentWifiWeak();
            }
          });
        } else {
          _weakWifiBufferTimer?.cancel();
          _weakWifiBufferTimer = null;
        }
        videoPlayerServiceHandler?.onStatusChange(
          playerStatus.value,
          buffering,
          isLive,
        );
      }),
      if (kDebugMode)
        stream.log.listen(((PlayerLog log) {
          if (log.level == 'error' || log.level == 'fatal') {
            Utils.reportError(
              '${log.level}: ${log.prefix}: ${log.text}\n${player.state.playlist}',
              null,
            );
          } else {
            debugPrint(log.toString());
          }
        })),
      stream.error.listen((String event) {
        if (dataSource is FileSource &&
            (event.startsWith('Failed to open file') ||
                event.startsWith('Failed to open .') ||
                event.startsWith('Cannot open') ||
                event.startsWith('Can not open') ||
                event.startsWith('error running'))) {
          dataStatus.value = DataStatus.error;
          EasyThrottle.throttle(
            'controllerStream.localFileError',
            const Duration(seconds: 3),
            () => SmartDialog.showToast(
              '离线缓存打开失败：${event.length > 160 ? '${event.substring(0, 160)}…' : event}',
            ),
          );
          if (!kDebugMode) {
            Utils.reportError('$event\n${player.state.playlist}');
          }
          return;
        }
        if (isLive) {
          if (event.startsWith('tcp: ffurl_read returned ') ||
              event.startsWith("Failed to open https://") ||
              event.startsWith("Can not open external file https://")) {
            Future.delayed(const Duration(milliseconds: 3000), refreshPlayer);
          }
          return;
        }
        if (event.startsWith("Failed to open https://") ||
            event.startsWith("Can not open external file https://") ||
            //tcp: ffurl_read returned 0xdfb9b0bb
            //tcp: ffurl_read returned 0xffffff99
            event.startsWith('tcp: ffurl_read returned ')) {
          EasyThrottle.throttle(
            'controllerStream.error.listen',
            const Duration(milliseconds: 10000),
            () {
              Future.delayed(const Duration(milliseconds: 3000), () async {
                // if (kDebugMode) {
                //   debugPrint("isBuffering.value: ${isBuffering.value}");
                // }
                // if (kDebugMode) {
                //   debugPrint("_buffered.value: ${_buffered.value}");
                // }
                if (isBuffering.value && buffered.value == 0) {
                  if (await onCdnFallback?.call() == true) return;
                  SmartDialog.showToast(
                    '视频链接打开失败，重试中',
                    displayTime: const Duration(milliseconds: 500),
                  );
                  refreshPlayer();
                }
              });
            },
          );
        } else if (event.startsWith('Could not open codec')) {
          final fallback = _automaticHwdecFallback;
          if (fallback != null && !_hwdecFallbackToastShown) {
            _hwdecFallbackToastShown = true;
            SmartDialog.showToast(
              '首选硬解模式不可用，已交由 $fallback 继续兜底',
              displayTime: const Duration(seconds: 3),
            );
          } else if (fallback == null) {
            SmartDialog.showToast('无法加载解码器, $event，可能会切换至软解');
          }
        } else if (!onlyPlayAudio.value) {
          if (event.startsWith("error running") ||
              event.startsWith("Failed to open .") ||
              event.startsWith("Cannot open") ||
              event.startsWith("Can not open")) {
            return;
          }
          if (!kDebugMode) {
            Utils.reportError('$event\n${player.state.playlist}');
          }
          // SmartDialog.showToast('视频加载错误, $event');
        }
      }),
    ];
  }

  /// 移除事件监听
  void _removeListeners() {
    _subscriptions?.forEach((e) => e.cancel());
    _subscriptions?.clear();
    _subscriptions = null;
  }

  void _cancelSubForSeek() {
    if (_subForSeek != null) {
      _subForSeek!.cancel();
      _subForSeek = null;
    }
  }

  /// 跳转至指定位置
  Future<void> seekTo(
    Duration position, {
    bool isSeek = true,
    bool recordStats = true,
  }) async {
    if (_playerCount == 0) {
      return;
    }
    if (position < Duration.zero) {
      position = Duration.zero;
    }
    PlaybackStatsService.seek(
      _videoPlayerController?.state.position ?? Duration.zero,
      position,
      userInitiated: recordStats,
    );
    _heartDuration = position.inSeconds;

    Future<void> seek() async {
      if (isSeek) {
        /// 拖动进度条调节时，不等待第一帧，防止抖动
        await _videoPlayerController?.stream.buffer.first;
      }
      danmakuController?.clear();
      try {
        await _videoPlayerController?.seek(position);
      } catch (e) {
        if (kDebugMode) debugPrint('seek failed: $e');
      }
    }

    if (duration.value != 0) {
      seek();
    } else {
      // if (kDebugMode) debugPrint('seek duration else');
      _subForSeek?.cancel();
      _subForSeek = duration.listen((_) {
        seek();
        _cancelSubForSeek();
      });
    }
  }

  /// 设置倍速
  Future<void> setPlaybackSpeed(
    double speed, {
    bool recordSelection = true,
    bool temporary = false,
    bool forceRecordSelection = false,
  }) async {
    lastPlaybackSpeed = playbackSpeed;

    final player = _videoPlayerController;
    final unchanged = speed == player?.state.rate;
    if (unchanged && !forceRecordSelection) {
      return;
    }

    PlaybackStatsService.changeSpeed(
      speed,
      player?.state.position ?? Duration.zero,
      recordSelection: recordSelection,
      temporary: temporary,
    );

    if (!unchanged) await player?.setRate(speed);
    _playbackSpeed.value = speed;
    final danmaku = danmakuController;
    if (danmaku != null) {
      try {
        final currentOption = danmaku.option;
        final speedScale = lastPlaybackSpeed / speed;
        final updatedOption = currentOption.copyWith(
          duration: currentOption.duration * speedScale,
          staticDuration: currentOption.staticDuration * speedScale,
        );
        danmaku.updateOption(updatedOption);
      } catch (_) {}
    }
  }

  // 还原默认速度
  double playSpeedDefault = Pref.playSpeedDefault;
  Future<void> setDefaultSpeed() async {
    await _videoPlayerController?.setRate(playSpeedDefault);
    _playbackSpeed.value = playSpeedDefault;
  }

  /// 播放视频
  Future<void> play({bool repeat = false, bool hideControls = true}) async {
    if (_playerCount == 0) return;
    // 播放时自动隐藏控制条
    controls = !hideControls;
    // repeat为true，将从头播放
    if (repeat) {
      // await seekTo(Duration.zero);
      await seekTo(Duration.zero, isSeek: false, recordStats: false);
    }

    await _videoPlayerController?.play();

    audioSessionHandler?.setActive(true);

    playerStatus.value = PlayerStatus.playing;
    // screenManager.setOverlays(false);
  }

  /// 暂停播放
  Future<void> pause({bool notify = true, bool isInterrupt = false}) async {
    await _videoPlayerController?.pause();
    playerStatus.value = PlayerStatus.paused;

    // 主动暂停时让出音频焦点
    if (!isInterrupt) {
      audioSessionHandler?.setActive(false);
    }
  }

  bool tripling = false;

  /// 隐藏控制条
  void hideTaskControls() {
    _timer?.cancel();
    _timer = Timer(showControlDuration, () {
      if (!isSeeking.value && !tripling) {
        controls = false;
      }
      _timer = null;
    });
  }

  void onSeekEnd() {
    if (seekToPos != null) {
      feedBack();
    }
    if (showSeekPreview) {
      showPreview.value = false;
    }
    hasToasted = false;
    isSeeking.value = false;
    hideTaskControls();
  }

  final RxBool volumeIndicator = false.obs;
  Timer? volumeTimer;
  bool volumeInterceptEventStream = false;

  final double maxVolume = PlatformUtils.isDesktop ? Pref.maxVolume : 1.0;
  Future<void> setVolume(double volume, {bool showIndicator = true}) async {
    if (this.volume.value != volume) {
      this.volume.value = volume;
      try {
        if (PlatformUtils.isDesktop) {
          await _videoPlayerController!.setVolume(volume * 100);
        } else {
          FlutterVolumeController.updateShowSystemUI(false);
          await FlutterVolumeController.setVolume(volume);
        }
      } catch (err) {
        if (kDebugMode) debugPrint(err.toString());
      }
    }
    if (showIndicator) {
      volumeIndicator.value = true;
    }
    volumeInterceptEventStream = true;
    volumeTimer?.cancel();
    volumeTimer = Timer(const Duration(milliseconds: 200), () {
      volumeIndicator.value = false;
      volumeInterceptEventStream = false;
      if (PlatformUtils.isDesktop) {
        setting.put(SettingBoxKey.desktopVolume, volume.toPrecision(3));
      }
    });
  }

  /// Toggle Change the videofit accordingly
  void toggleVideoFit(VideoFitType value) {
    _prefFit = videoFit.value = value;
    video.put(VideoBoxKey.cacheVideoFit, value.index);
  }

  /// 读取fit
  var _prefFit = VideoFitType.values[Pref.cacheVideoFit];
  void _initVideoFit() {
    if (_prefFit == .fill && _isVertical) {
      videoFit.value = .contain;
    } else {
      videoFit.value = _prefFit;
    }
  }

  /// 设置后台播放
  void setBackgroundPlay(bool val) {
    videoPlayerServiceHandler?.enableBackgroundPlay = val;
    if (!tempPlayerConf) {
      setting.put(SettingBoxKey.enableBackgroundPlay, val);
    }
  }

  set controls(bool visible) {
    showControls.value = visible;
    _timer?.cancel();
    if (visible) {
      hideTaskControls();
    }
  }

  Timer? longPressTimer;
  Timer? _longPressSpeedLockTimer;
  double? _lockedLongPressSpeed;
  double? _longPressRestoreSpeed;
  void cancelLongPressTimer() {
    longPressTimer?.cancel();
    longPressTimer = null;
    _longPressSpeedLockTimer?.cancel();
    _longPressSpeedLockTimer = null;
    _lockedLongPressSpeed = null;
  }

  void _armLongPressSpeedLock() {
    _longPressSpeedLockTimer?.cancel();
    _lockedLongPressSpeed = null;
    _longPressSpeedLockTimer = Timer(const Duration(seconds: 2), () {
      if (longPressStatus.value) {
        _lockedLongPressSpeed = playbackSpeed;
        HapticFeedback.mediumImpact();
        SmartDialog.showToast(
          '$playbackSpeed 倍将在松手后保持',
          displayTime: const Duration(seconds: 1),
        );
      }
    });
  }

  /// 设置长按倍速状态 live模式下禁用
  Future<void> setLongPressStatus(bool val) async {
    if (isLive) {
      return;
    }
    if (controlsLock.value) {
      return;
    }
    if (longPressStatus.value == val) {
      return;
    }
    if (val) {
      if (playerStatus.isPlaying) {
        _longPressRestoreSpeed = playbackSpeed;
        longPressStatus.value = val;
        HapticFeedback.lightImpact();
        await setPlaybackSpeed(
          enableAutoLongPressSpeed
              ? playbackSpeed * longPressSpeedFactor
              : longPressSpeed,
          recordSelection: false,
          temporary: true,
        );
      }
    } else {
      _longPressSpeedLockTimer?.cancel();
      _longPressSpeedLockTimer = null;
      longPressStatus.value = val;
      final lockedSpeed = _lockedLongPressSpeed;
      _lockedLongPressSpeed = null;
      if (lockedSpeed != null && (playbackSpeed - lockedSpeed).abs() < 0.001) {
        _longPressRestoreSpeed = null;
        await setPlaybackSpeed(
          lockedSpeed,
          temporary: false,
          forceRecordSelection: true,
        );
        return;
      }
      final restoreSpeed = _longPressRestoreSpeed ?? lastPlaybackSpeed;
      _longPressRestoreSpeed = null;
      await setPlaybackSpeed(
        restoreSpeed,
        recordSelection: false,
        temporary: false,
      );
    }
  }

  Future<void> adjustLongPressSpeed(int steps) async {
    if (!longPressStatus.value || !enableLongPressSlideSpeed || steps == 0) {
      return;
    }
    final nextSpeed = playbackSpeed + steps * 0.25;
    await setPlaybackSpeed(
      nextSpeed > 0.25 ? nextSpeed : 0.25,
      recordSelection: false,
      temporary: true,
    );
    _armLongPressSpeedLock();
  }

  bool get isCompleted =>
      videoPlayerController!.state.completed ||
      durationInMilliseconds - positionInMilliseconds <= 50;

  // 双击播放、暂停
  Future<void> onDoubleTapCenter() async {
    if (!isLive && isCompleted) {
      await seekTo(Duration.zero, isSeek: false, recordStats: false);
      videoPlayerController!.play();
    } else {
      videoPlayerController!.playOrPause();
    }
  }

  final RxBool mountSeekBackwardButton = false.obs;
  final RxBool mountSeekForwardButton = false.obs;

  void onDoubleTapSeekBackward() {
    mountSeekBackwardButton.value = true;
  }

  void onDoubleTapSeekForward() {
    mountSeekForwardButton.value = true;
  }

  void onForward(Duration duration) {
    onForwardBackward(videoPlayerController!.state.position + duration);
  }

  void onBackward(Duration duration) {
    onForwardBackward(videoPlayerController!.state.position - duration);
  }

  void onForwardBackward(Duration duration) {
    seekTo(
      duration.clamp(Duration.zero, videoPlayerController!.state.duration),
      isSeek: false,
    ).whenComplete(play);
  }

  void doubleTapFuc(DoubleTapType type) {
    if (!enableQuickDouble) {
      onDoubleTapCenter();
      return;
    }
    switch (type) {
      case DoubleTapType.left:
        // 双击左边区域 👈
        onDoubleTapSeekBackward();
        break;
      case DoubleTapType.center:
        onDoubleTapCenter();
        break;
      case DoubleTapType.right:
        // 双击右边区域 👈
        onDoubleTapSeekForward();
        break;
    }
  }

  /// 关闭控制栏
  void onLockControl(bool val) {
    feedBack();
    controlsLock.value = val;
    if (!val && showControls.value) {
      showControls.refresh();
    }
    controls = !val;
    if (PlatformUtils.isMobile && isFullScreen.value) {
      if (val && _orientationPlan.controlsLockOrientation) {
        lockedMode();
      } else if (!val && _orientationPlan.controlsLockOrientation) {
        _applyFullScreenRuntimePolicy();
      }
      _updateOrientationInputs();
    }
  }

  void _setFullScreen(bool val) {
    isFullScreen.value = val;
    PlaybackStatsService.changePlaybackForm(
      val ? 'fullscreen' : 'window',
      videoPlayerController?.state.position ?? Duration.zero,
    );
    updateSubtitleStyle();
    if (!val) {
      _pendingSystemHandoff = false;
      _entryTargetLandscape = null;
    }
    _updateOrientationInputs();
    if (val && _pendingSystemHandoff) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pendingSystemHandoff) {
          unawaited(_tryCompleteSystemHandoff());
        }
      });
    }
  }

  double screenRatio = 0.0;
  bool isManualFS = true;
  late final removeSafeArea = Pref.removeSafeArea;

  int _entryAxisMask(
    EntryOrientationPolicy policy,
    DeviceOrientation? triggerOrientation,
  ) {
    if (policy == EntryOrientationPolicy.triggerDirection &&
        triggerOrientation != null) {
      return triggerOrientation == DeviceOrientation.portraitUp ||
              triggerOrientation == DeviceOrientation.portraitDown
          ? OrientationMask.portrait
          : OrientationMask.landscape;
    }
    return switch (policy) {
      EntryOrientationPolicy.portrait ||
      EntryOrientationPolicy.portraitUp ||
      EntryOrientationPolicy.portraitDown => OrientationMask.portrait,
      EntryOrientationPolicy.landscape ||
      EntryOrientationPolicy.landscapeLeft ||
      EntryOrientationPolicy.landscapeRight => OrientationMask.landscape,
      EntryOrientationPolicy.video =>
        _isVertical ? OrientationMask.portrait : OrientationMask.landscape,
      EntryOrientationPolicy.ratio =>
        _isVertical || screenRatio < kScreenRatio
            ? OrientationMask.portrait
            : OrientationMask.landscape,
      EntryOrientationPolicy.keepCurrent ||
      EntryOrientationPolicy.triggerDirection =>
        _currentSystemLandscape
            ? OrientationMask.landscape
            : OrientationMask.portrait,
    };
  }

  void _compileFullScreenAllowedMask(
    EntryOrientationPolicy entryPolicy,
    DeviceOrientation? triggerOrientation,
  ) {
    _entryTargetLandscape =
        _entryAxisMask(entryPolicy, triggerOrientation) ==
        OrientationMask.landscape;
    _fullScreenAllowedMask = switch (_orientationPlan.fullScreenAllowed) {
      FullScreenAllowedOrientation.all => OrientationMask.all,
      FullScreenAllowedOrientation.landscape => OrientationMask.landscape,
      FullScreenAllowedOrientation.portrait => OrientationMask.portrait,
      FullScreenAllowedOrientation.entryAxis =>
        _entryAxisMask(entryPolicy, triggerOrientation),
      FullScreenAllowedOrientation.entryExact => 0,
    };
  }

  Future<void>? _applyAxisOrientation(int mask) {
    final filtered = _orientationPlan.filterMask(mask);
    if (filtered == 0) return null;
    _entryDirectionApplied = true;
    if (mask == OrientationMask.portrait) {
      return filtered == OrientationMask.portraitDown
          ? portraitDownMode()
          : portraitUpMode();
    }
    if (_orientation == DeviceOrientation.landscapeRight &&
        filtered & OrientationMask.landscapeRight != 0) {
      return landscapeRightMode();
    }
    return filtered == OrientationMask.landscapeRight
        ? landscapeRightMode()
        : landscapeLeftMode();
  }

  Future<void>? _applyConcreteOrientation(DeviceOrientation orientation) {
    if (_orientationPlan.filterMask(
          OrientationPolicy.orientationBit(orientation),
        ) ==
        0) {
      return null;
    }
    _entryDirectionApplied = true;
    return switch (orientation) {
      DeviceOrientation.portraitUp => portraitUpMode(),
      DeviceOrientation.portraitDown => portraitDownMode(),
      DeviceOrientation.landscapeLeft => landscapeLeftMode(),
      DeviceOrientation.landscapeRight => landscapeRightMode(),
    };
  }

  void onVideoOrientationChanged(bool isVertical) {
    _isVertical = isVertical;
    if (!isFullScreen.value) return;
    final policy = _orientationPlan.entryForCause(_fullScreenEntryCause);
    if (policy == EntryOrientationPolicy.video ||
        policy == EntryOrientationPolicy.ratio) {
      changeOrientation(policy: policy);
    }
  }

  Future<void>? changeOrientation({
    required EntryOrientationPolicy policy,
    DeviceOrientation? triggerOrientation,
  }) {
    return switch (policy) {
      EntryOrientationPolicy.keepCurrent => null,
      EntryOrientationPolicy.video => _applyAxisOrientation(
          _isVertical ? OrientationMask.portrait : OrientationMask.landscape,
        ),
      EntryOrientationPolicy.portrait =>
        _applyAxisOrientation(OrientationMask.portrait),
      EntryOrientationPolicy.landscape =>
        _applyAxisOrientation(OrientationMask.landscape),
      EntryOrientationPolicy.ratio => _applyAxisOrientation(
          _isVertical || screenRatio < kScreenRatio
              ? OrientationMask.portrait
              : OrientationMask.landscape,
        ),
      EntryOrientationPolicy.portraitUp =>
        _applyConcreteOrientation(DeviceOrientation.portraitUp),
      EntryOrientationPolicy.portraitDown =>
        _applyConcreteOrientation(DeviceOrientation.portraitDown),
      EntryOrientationPolicy.landscapeLeft =>
        _applyConcreteOrientation(DeviceOrientation.landscapeLeft),
      EntryOrientationPolicy.landscapeRight =>
        _applyConcreteOrientation(DeviceOrientation.landscapeRight),
      EntryOrientationPolicy.triggerDirection => triggerOrientation == null
          ? null
          : _applyConcreteOrientation(triggerOrientation),
    };
  }

  bool get _systemExitNeedsWindowRotation {
    final plan = _orientationPlan;
    return plan.triggerExit &&
        plan.exitAllowsCause(_fullScreenEntryCause) &&
        plan.sourceUsesSystem(plan.exitTriggerSource);
  }

  bool? get _windowedSystemHandoffIgnoreLock {
    final plan = _orientationPlan;
    return switch (plan.windowedRotation) {
      WindowedPlayerRotationMode.keepCurrent => null,
      WindowedPlayerRotationMode.followSystem => false,
      WindowedPlayerRotationMode.alwaysAuto => true,
      WindowedPlayerRotationMode.inheritApp => switch (plan.appRotation) {
        AppRotationMode.lockInitial => null,
        AppRotationMode.followSystem => false,
        AppRotationMode.alwaysAuto => true,
      },
    };
  }

  void _queueSystemHandoff({required bool ignoreSystemLock}) {
    _pendingSystemHandoff = true;
    _pendingSystemHandoffIgnoreLock = ignoreSystemLock;
  }

  Future<void> _tryCompleteSystemHandoff([bool? currentLandscape]) async {
    if (!_pendingSystemHandoff || _fsProcessing || !isFullScreen.value) return;
    final targetLandscape = _entryTargetLandscape;
    if (targetLandscape != null &&
        (currentLandscape ?? _currentSystemLandscape) != targetLandscape) {
      return;
    }

    _pendingSystemHandoff = false;
    final ignoreSystemLock = _pendingSystemHandoffIgnoreLock;
    final allowed = _orientationPlan.filterMask(_fullScreenAllowedMask);
    if (allowed == 0) {
      _updateOrientationInputs();
      return;
    }

    if (ignoreSystemLock) {
      await OrientationPolicy.applySystemPolicy(
        ignoreSystemLock: true,
        allowedMask: allowed,
        filterEnabled: allowed != OrientationMask.all,
      );
    } else if (allowed == OrientationMask.all) {
      await (followSystemMode() ?? Future<void>.value());
    } else {
      await OrientationPolicy.applySystemPolicy(
        ignoreSystemLock: false,
        allowedMask: allowed,
        filterEnabled: true,
      );
    }
    _updateOrientationInputs();
  }

  Future<void> _applyFullScreenRuntimePolicy() async {
    final plan = _orientationPlan;
    final allowed = plan.filterMask(_fullScreenAllowedMask);
    if (plan.fullScreenAllowed == FullScreenAllowedOrientation.entryExact ||
        allowed == 0) {
      if (!_entryDirectionApplied) await lockedMode();
      return;
    }
    switch (plan.fullScreenRotationSource) {
      case FullScreenRotationSource.keepCurrent:
        if (!_entryDirectionApplied) {
          await lockedMode();
          return;
        }
        if (_systemExitNeedsWindowRotation) {
          final ignoreSystemLock = _windowedSystemHandoffIgnoreLock;
          if (ignoreSystemLock == true) {
            _queueSystemHandoff(ignoreSystemLock: true);
          } else if (ignoreSystemLock == false &&
              await OrientationPlatform.systemAutoRotate()) {
            _queueSystemHandoff(ignoreSystemLock: false);
          }
        }
        return;
      case FullScreenRotationSource.appGravity:
        if (!_entryDirectionApplied) await lockedMode();
        return;
      case FullScreenRotationSource.followSystem:
        if (_entryDirectionApplied) {
          if (await OrientationPlatform.systemAutoRotate()) {
            _queueSystemHandoff(ignoreSystemLock: false);
          }
          return;
        }
        await OrientationPolicy.applySystemPolicy(
          ignoreSystemLock: false,
          allowedMask: allowed,
          filterEnabled: allowed != OrientationMask.all,
        );
        return;
      case FullScreenRotationSource.alwaysAuto:
        if (_entryDirectionApplied) {
          _queueSystemHandoff(ignoreSystemLock: true);
          return;
        }
        await OrientationPolicy.applySystemPolicy(
          ignoreSystemLock: true,
          allowedMask: allowed,
          filterEnabled: allowed != OrientationMask.all,
        );
        return;
    }
  }

  // 全屏
  bool _fsProcessing = false;
  Future<void> triggerFullScreen({
    bool status = true,
    bool inAppFullScreen = false,
    FullscreenEntryCause cause = FullscreenEntryCause.manual,
  }) async {
    if (isDesktopPip) return;
    if (isFullScreen.value == status) return;

    if (_fsProcessing) return;
    _fsProcessing = true;
    isManualFS = cause == FullscreenEntryCause.manual;
    try {
      if (status) {
        _fullScreenEntryCause = cause;
        if (PlatformUtils.isMobile) {
          hideSystemBar();
          _entryDirectionApplied = false;
          final entryPolicy = _orientationPlan.entryForCause(cause);
          final triggerOrientation = cause == FullscreenEntryCause.orientation
              ? _orientation
              : null;
          _compileFullScreenAllowedMask(entryPolicy, triggerOrientation);
          await changeOrientation(
            policy: entryPolicy,
            triggerOrientation: triggerOrientation,
          );
          await _applyFullScreenRuntimePolicy();
        } else {
          await enterDesktopFullScreen(inAppFullScreen: inAppFullScreen);
        }
      } else {
        if (PlatformUtils.isMobile) {
          if (!removeSafeArea) {
            showSystemBar();
          }
          await resetScreenRotation();
        } else {
          await exitDesktopFullScreen();
        }
      }
    } finally {
      _setFullScreen(status);
      _fsProcessing = false;
    }
  }

  void addPositionListener(ValueChanged<Duration> listener) {
    if (_playerCount == 0) return;
    _positionListeners.add(listener);
  }

  void removePositionListener(ValueChanged<Duration> listener) =>
      _positionListeners.remove(listener);

  void addRawPositionListener(ValueChanged<Duration> listener) {
    if (_playerCount == 0) return;
    _rawPositionListeners.add(listener);
  }

  void removeRawPositionListener(ValueChanged<Duration> listener) =>
      _rawPositionListeners.remove(listener);

  void addStatusLister(ValueChanged<PlayerStatus> listener) {
    if (_playerCount == 0) return;
    _statusListeners.add(listener);
  }

  void removeStatusLister(ValueChanged<PlayerStatus> listener) =>
      _statusListeners.remove(listener);

  // 记录播放记录
  Future<void>? makeHeartBeat(
    int progress, {
    HeartBeatType type = .playing,
    bool isManual = false,
    dynamic aid,
    dynamic bvid,
    dynamic cid,
    dynamic epid,
    dynamic seasonId,
    dynamic pgcType,
    VideoType? videoType,
  }) {
    if (isLive ||
        !enableHeart ||
        progress == 0 ||
        (playerStatus.isPaused && !isManual)) {
      return null;
    }

    Future<void> send() {
      return VideoHttp.heartBeat(
        aid: aid ?? _aid,
        bvid: bvid ?? _bvid,
        cid: cid ?? this.cid,
        progress: progress,
        epid: epid ?? _epid,
        seasonId: seasonId ?? _seasonId,
        subType: pgcType ?? _pgcType,
        videoType: videoType ?? _videoType,
      );
    }

    switch (type) {
      case .playing:
        if (progress > _heartDuration &&
            (progress & ~7) != (_heartDuration & ~7)) {
          _heartDuration = progress;
          return send();
        }
      case .status:
        if (progress - _heartDuration >= 2) {
          _heartDuration = progress;
          return send();
        }
      case .completed:
        if (playerStatus.isCompleted &&
            (durationInMilliseconds - positionInMilliseconds) <= 1000) {
          progress = -1;
        }
        return send();
    }
    return null;
  }

  void setPlayRepeat(PlayRepeat type) {
    playRepeat = type;
    if (!tempPlayerConf) video.put(VideoBoxKey.playRepeat, type.index);
  }

  void putSubtitleSettings() {
    setting.putAllNE({
      SettingBoxKey.subtitleFontScale: subtitleFontScale,
      SettingBoxKey.subtitleFontScaleFS: subtitleFontScaleFS,
      SettingBoxKey.subtitlePaddingH: subtitlePaddingH,
      SettingBoxKey.subtitlePaddingB: subtitlePaddingB,
      SettingBoxKey.subtitleBgOpacity: subtitleBgOpacity,
      SettingBoxKey.subtitleStrokeWidth: subtitleStrokeWidth,
      SettingBoxKey.subtitleFontWeight: subtitleFontWeight,
    });
  }

  bool _isCloseAll = false;
  bool get isCloseAll => _isCloseAll;

  Future<void>? resetScreenRotation() {
    return switch (_orientationPlan.exitMode) {
      ExitOrientationMode.restoreApp => OrientationPolicy.restoreApp(),
      ExitOrientationMode.keepPlayer => OrientationPolicy.applyWindowedRuntime(
          _orientationPlan.windowedRotation,
        ),
      ExitOrientationMode.lockPlayer => lockedMode(),
    };
  }

  void onCloseAll() {
    _isCloseAll = true;
    if (PlatformUtils.isDesktop) exitDesktopFullScreen();
    dispose();
    Get.until((route) => route.isFirst);
  }

  void dispose() {
    // 离开播放器后统一恢复 APP 运行方向，避免视频窗口策略泄漏到其他页面。
    if (PlatformUtils.isMobile) {
      OrientationPolicy.restoreApp();
    }
    cancelLongPressTimer();
    _cancelSubForSeek();
    if (!_isCloseAll && _playerCount > 1) {
      _playerCount -= 1;
      _heartDuration = 0;
      return;
    }

    _playerCount = 0;
    if (removeSafeArea) {
      showSystemBar();
    }
    danmakuController = null;
    _pendingSystemHandoff = false;
    _entryTargetLandscape = null;
    if (_observingSystemOrientation) {
      WidgetsBinding.instance.removeObserver(this);
      _observingSystemOrientation = false;
    }
    _stopOrientationListener();
    _disableAutoEnterPip();
    setPlayCallBack(null);
    dmState.clear();
    if (showSeekPreview) {
      _clearPreview();
    }
    if (Platform.isAndroid) {
      AndroidHelper$ToDart.onUserLeaveHint?.release();
      AndroidHelper$ToDart.onUserLeaveHint = null;
    }
    _timer?.cancel();
    _weakWifiBufferTimer?.cancel();
    _weakWifiBufferTimer = null;
    _networkPolicySubscription?.cancel();
    _networkPolicySubscription = null;
    onNetworkPolicyChanged = null;
    onCdnFallback = null;
    // _position.close();
    // _playerEventSubs?.cancel();
    // _sliderPosition.close();
    // _sliderTempPosition.close();
    // _isSliderMoving.close();
    // _duration.close();
    // _buffered.close();
    // _showControls.close();
    // _controlsLock.close();

    // playerStatus.close();
    // dataStatus.close();

    if (PlatformUtils.isDesktop && isAlwaysOnTop.value) {
      windowManager.setAlwaysOnTop(false);
    }

    _removeListeners();
    _positionListeners.clear();
    _rawPositionListeners.clear();
    _statusListeners.clear();
    if (playerStatus.isPlaying) {
      WakelockPlus.disable();
    }
    if (kDebugMode) {
      debugPrint('dispose player');
    }
    PlaybackStatsService.endMedia(
      _videoPlayerController?.state.position ?? Duration.zero,
    );
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    _videoController = null;
    _instance = null;
    videoPlayerServiceHandler?.clear();
  }

  static void updatePlayCount() {
    if (_instance?._playerCount == 1) {
      _instance?.dispose();
    } else {
      _instance?._playerCount -= 1;
    }
  }

  void setContinuePlayInBackground() {
    continuePlayInBackground.toggle();
    if (!tempPlayerConf) {
      setting.put(
        SettingBoxKey.continuePlayInBackground,
        continuePlayInBackground.value,
      );
    }
  }

  late final Map<String, ui.Image?> previewCache = {};
  LoadingState<VideoShotData>? videoShot;
  late final RxBool showPreview = false.obs;
  late final showSeekPreview = Pref.showSeekPreview;
  late final previewIndex = RxnInt();

  void updatePreviewIndex(int seconds) {
    if (videoShot == null) {
      videoShot = LoadingState.loading();
      getVideoShot();
      return;
    }
    if (videoShot case Success(:final response)) {
      showPreview.value = true;
      final index = response.index;
      var low = 0;
      var high = index.length;
      while (low < high) {
        final mid = (low + high) >> 1;
        if (index[mid] <= seconds) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      previewIndex.value = low > 1 ? low - 2 : 0;
    }
  }

  void _clearPreview() {
    showPreview.value = false;
    previewIndex.value = null;
    videoShot = null;
    for (final i in previewCache.values) {
      i?.dispose();
    }
    previewCache.clear();
  }

  Future<void> getVideoShot() async {
    videoShot = await VideoHttp.videoshot(bvid: bvid, cid: cid!);
  }

  Future<void> takeScreenshot() async {
    SmartDialog.showToast('截图中');
    final time = DurationUtils.formatDuration(
      positionInMilliseconds * 0.001,
    ).replaceAll(':', '-');
    final image = await videoPlayerController?.screenshot();
    if (image != null) {
      SmartDialog.showToast('点击弹窗保存截图');
      showDialog(
        context: Get.context!,
        builder: (context) => GestureDetector(
          onTap: () async {
            final bytes = await image.toByteData(format: .png);
            if (bytes != null) {
              ImageUtils.saveByteImg(
                bytes: bytes.buffer.asUint8List(),
                fileName: 'screenshot_${cid}_$time',
              );
            } else {
              SmartDialog.showToast('保存失败');
            }
            Get.back();
          },
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: min(MediaQuery.widthOf(context) * 0.3333333333333333, 350),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      width: 5,
                      color: ColorScheme.of(context).surface,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: RawImage(image: image),
                  ),
                ),
              ),
            ),
          ),
        ),
      ).whenComplete(image.dispose);
    } else {
      SmartDialog.showToast('截图失败');
    }
  }

  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) {
      if (playerStatus.isPlaying) {
        pause();
      }

      setPlayCallBack(null);

      if (Platform.isAndroid && _playerCount <= 1) {
        _disableAutoEnterPip();
        if (!setSystemBrightness) {
          ScreenBrightnessPlatform.instance.resetApplicationScreenBrightness();
        }
      }

      return;
    }

    if (controlsLock.value) {
      onLockControl(false);
      return;
    }
    if (isDesktopPip) {
      exitDesktopPip();
      return;
    }
    if (isFullScreen.value) {
      triggerFullScreen(status: false);
      return;
    }
    Get.back();
  }
}
