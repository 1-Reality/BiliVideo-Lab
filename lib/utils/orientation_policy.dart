import 'dart:io' show Platform;

import 'package:PiliBro/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliBro/plugin/pl_player/models/orientation_mode.dart';
import 'package:PiliBro/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliBro/plugin/pl_player/utils/orientation_platform.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver;

final class OrientationPlan {
  const OrientationPlan({
    required this.appInitial,
    required this.appRotation,
    required this.windowedRotation,
    required this.manualEntry,
    required this.autoEntry,
    required this.orientationEntry,
    required this.fullScreenRotationSource,
    required this.fullScreenAllowed,
    required this.gravityFollowSystemLock,
    required this.triggerEnter,
    required this.triggerExit,
    required this.enterTriggerSource,
    required this.exitTriggerSource,
    required this.triggerContent,
    required this.angleDegrees,
    required this.autoExitCauses,
    required this.manualExitConfirmations,
    required this.exitMode,
    required this.controlsLockOrientation,
    required this.finalDirectionMask,
    required this.systemAutoRotate,
  });

  final AppInitialOrientation appInitial;
  final AppRotationMode appRotation;
  final WindowedPlayerRotationMode windowedRotation;
  final EntryOrientationPolicy manualEntry;
  final EntryOrientationPolicy autoEntry;
  final EntryOrientationPolicy orientationEntry;
  final FullScreenRotationSource fullScreenRotationSource;
  final FullScreenAllowedOrientation fullScreenAllowed;
  final bool gravityFollowSystemLock;
  final bool triggerEnter;
  final bool triggerExit;
  final OrientationTriggerSource enterTriggerSource;
  final OrientationTriggerSource exitTriggerSource;
  final OrientationTriggerContent triggerContent;
  final int angleDegrees;
  final int autoExitCauses;
  final int manualExitConfirmations;
  final ExitOrientationMode exitMode;
  final bool controlsLockOrientation;
  final int finalDirectionMask;
  final bool systemAutoRotate;

  int get effectiveFinalMask =>
      finalDirectionMask == 0 || finalDirectionMask == OrientationMask.all
      ? OrientationMask.all
      : finalDirectionMask;

  bool get gravityAllowed =>
      !gravityFollowSystemLock || systemAutoRotate;

  bool sourceUsesGravity(OrientationTriggerSource source) =>
      source != OrientationTriggerSource.system;

  bool sourceUsesSystem(OrientationTriggerSource source) =>
      source != OrientationTriggerSource.appGravity;

  bool contentAllows(bool isVertical) => switch (triggerContent) {
    OrientationTriggerContent.all => true,
    OrientationTriggerContent.landscapeVideo => !isVertical,
    OrientationTriggerContent.portraitVideo => isVertical,
  };

  bool exitAllowsCause(FullscreenEntryCause cause) =>
      autoExitCauses & FullscreenEntryCauseMask.of(cause) != 0;

  bool get manualExitConfirmationEnabled =>
      manualExitConfirmations > 0 &&
      triggerExit &&
      exitAllowsCause(FullscreenEntryCause.manual);

  EntryOrientationPolicy entryForCause(FullscreenEntryCause cause) =>
      switch (cause) {
        FullscreenEntryCause.manual => manualEntry,
        FullscreenEntryCause.playbackAuto => autoEntry,
        FullscreenEntryCause.orientation => orientationEntry,
      };

  int filterMask(int mask) => mask & effectiveFinalMask;
}


final class BrotherOrientationPlan {
  const BrotherOrientationPlan({
    required this.app,
    required this.windowed,
    required this.fullscreen,
    required this.fullscreenEnterOverrideMask,
    required this.fullscreenManualEnter,
    required this.fullscreenPlaybackEnter,
    required this.fullscreenOrientationEnter,
    required this.windowedResumeOverrideMask,
    required this.windowedManualResume,
    required this.windowedPlaybackResume,
    required this.windowedOrientationResume,
    required this.landscapeEnter,
    required this.portraitExit,
    required this.enterSignalMask,
    required this.enterSignalRequired,
    required this.exitSignalMask,
    required this.exitSignalRequired,
    required this.manualExitSignalMask,
    required this.manualExitSignalRequired,
    required this.enterTriggerContent,
    required this.exitTriggerContent,
    required this.autoExitCauses,
    required this.manualExitConfirmations,
    required this.controlsLockOrientation,
    required this.finalDirectionMask,
    required this.systemAutoRotate,
  });

  final BrotherPhaseConfig app;
  final BrotherPhaseConfig windowed;
  final BrotherPhaseConfig fullscreen;
  final int fullscreenEnterOverrideMask;
  final BrotherDirectionAction fullscreenManualEnter;
  final BrotherDirectionAction fullscreenPlaybackEnter;
  final BrotherDirectionAction fullscreenOrientationEnter;
  final int windowedResumeOverrideMask;
  final BrotherDirectionAction windowedManualResume;
  final BrotherDirectionAction windowedPlaybackResume;
  final BrotherDirectionAction windowedOrientationResume;
  final bool landscapeEnter;
  final bool portraitExit;
  final int enterSignalMask;
  final int enterSignalRequired;
  final int exitSignalMask;
  final int exitSignalRequired;
  final int manualExitSignalMask;
  final int manualExitSignalRequired;
  final OrientationTriggerContent enterTriggerContent;
  final OrientationTriggerContent exitTriggerContent;
  final int autoExitCauses;
  final int manualExitConfirmations;
  final bool controlsLockOrientation;
  final int finalDirectionMask;
  final bool systemAutoRotate;

  int get effectiveFinalMask =>
      finalDirectionMask == 0 || finalDirectionMask == OrientationMask.all
      ? OrientationMask.all
      : finalDirectionMask;

  BrotherPhaseConfig phase(BrotherOrientationPhase phase) => switch (phase) {
    BrotherOrientationPhase.app => app,
    BrotherOrientationPhase.windowed => windowed,
    BrotherOrientationPhase.fullscreen => fullscreen,
  };

  BrotherDirectionAction fullscreenEntryFor(FullscreenEntryCause cause) {
    final bit = FullscreenEntryCauseMask.of(cause);
    if (fullscreenEnterOverrideMask & bit == 0) return fullscreen.enterAction;
    return switch (cause) {
      FullscreenEntryCause.manual => fullscreenManualEnter,
      FullscreenEntryCause.playbackAuto => fullscreenPlaybackEnter,
      FullscreenEntryCause.orientation => fullscreenOrientationEnter,
    };
  }

  BrotherDirectionAction windowedResumeFor(FullscreenExitCause cause) {
    final bit = FullscreenExitCauseMask.of(cause);
    if (windowedResumeOverrideMask & bit == 0) return windowed.resumeAction;
    return switch (cause) {
      FullscreenExitCause.manual => windowedManualResume,
      FullscreenExitCause.playbackAuto => windowedPlaybackResume,
      FullscreenExitCause.orientation => windowedOrientationResume,
    };
  }

  bool enterContentAllows(bool isVertical) => switch (enterTriggerContent) {
    OrientationTriggerContent.all => true,
    OrientationTriggerContent.landscapeVideo => !isVertical,
    OrientationTriggerContent.portraitVideo => isVertical,
  };

  bool exitContentAllows(bool isVertical) => switch (exitTriggerContent) {
    OrientationTriggerContent.all => true,
    OrientationTriggerContent.landscapeVideo => !isVertical,
    OrientationTriggerContent.portraitVideo => isVertical,
  };

  bool exitAllowsEntryCause(FullscreenEntryCause cause) =>
      autoExitCauses & FullscreenEntryCauseMask.of(cause) != 0;

  int filterMask(int mask) => mask & effectiveFinalMask;
}

abstract final class OrientationPolicy {
  static OrientationPlan _plan = const OrientationPlan(
    appInitial: AppInitialOrientation.system,
    appRotation: AppRotationMode.followSystem,
    windowedRotation: WindowedPlayerRotationMode.inheritApp,
    manualEntry: EntryOrientationPolicy.video,
    autoEntry: EntryOrientationPolicy.video,
    orientationEntry: EntryOrientationPolicy.video,
    fullScreenRotationSource: FullScreenRotationSource.followSystem,
    fullScreenAllowed: FullScreenAllowedOrientation.all,
    gravityFollowSystemLock: true,
    triggerEnter: false,
    triggerExit: false,
    enterTriggerSource: OrientationTriggerSource.system,
    exitTriggerSource: OrientationTriggerSource.system,
    triggerContent: OrientationTriggerContent.all,
    angleDegrees: 30,
    autoExitCauses: FullscreenEntryCauseMask.all,
    manualExitConfirmations: 1,
    exitMode: ExitOrientationMode.restoreApp,
    controlsLockOrientation: true,
    finalDirectionMask: 0,
    systemAutoRotate: true,
  );

  static int _startupDirectionBit = OrientationMask.portraitUp;
  static final _finalGuard = _FinalOrientationGuard();
  static final _brotherGuard = _BrotherOrientationGuard();
  static bool _brotherEnabled = false;
  static BrotherOrientationPlan _brotherPlan = const BrotherOrientationPlan(
    app: BrotherPhaseConfig(
      enterAction: BrotherDirectionAction.systemCurrent,
      resumeAction: BrotherDirectionAction.keepCurrent,
      runtimeMode: BrotherRuntimeMode.unspecified,
      runtimeActivation: BrotherRuntimeActivation.immediate,
      allowedBasis: BrotherAllowedBasis.fixed,
      allowedMask: OrientationMask.all,
      gravityFollowSystemLock: true,
      angleDegrees: 30,
    ),
    windowed: BrotherPhaseConfig(
      enterAction: BrotherDirectionAction.keepCurrent,
      resumeAction: BrotherDirectionAction.keepCurrent,
      runtimeMode: BrotherRuntimeMode.inheritRequest,
      runtimeActivation: BrotherRuntimeActivation.immediate,
      allowedBasis: BrotherAllowedBasis.fixed,
      allowedMask: OrientationMask.all,
      gravityFollowSystemLock: true,
      angleDegrees: 30,
    ),
    fullscreen: BrotherPhaseConfig(
      enterAction: BrotherDirectionAction.video,
      resumeAction: BrotherDirectionAction.keepCurrent,
      runtimeMode: BrotherRuntimeMode.locked,
      runtimeActivation: BrotherRuntimeActivation.immediate,
      allowedBasis: BrotherAllowedBasis.fixed,
      allowedMask: OrientationMask.all,
      gravityFollowSystemLock: true,
      angleDegrees: 30,
    ),
    fullscreenEnterOverrideMask: FullscreenEntryCauseMask.all,
    fullscreenManualEnter: BrotherDirectionAction.video,
    fullscreenPlaybackEnter: BrotherDirectionAction.video,
    fullscreenOrientationEnter: BrotherDirectionAction.triggerDirection,
    windowedResumeOverrideMask: 0,
    windowedManualResume: BrotherDirectionAction.keepCurrent,
    windowedPlaybackResume: BrotherDirectionAction.keepCurrent,
    windowedOrientationResume: BrotherDirectionAction.triggerDirection,
    landscapeEnter: false,
    portraitExit: false,
    enterSignalMask: BrotherOrientationSignalMask.window,
    enterSignalRequired: 1,
    exitSignalMask: BrotherOrientationSignalMask.window,
    exitSignalRequired: 1,
    manualExitSignalMask: BrotherOrientationSignalMask.proposedSystem,
    manualExitSignalRequired: 1,
    enterTriggerContent: OrientationTriggerContent.all,
    exitTriggerContent: OrientationTriggerContent.all,
    autoExitCauses: FullscreenEntryCauseMask.orientation,
    manualExitConfirmations: 0,
    controlsLockOrientation: true,
    finalDirectionMask: 0,
    systemAutoRotate: true,
  );

  static OrientationPlan get plan => _plan;
  static BrotherOrientationPlan get brotherPlan => _brotherPlan;
  static bool get isBrotherTech => _brotherEnabled;
  static int get finalDirectionMask =>
      isBrotherTech ? _brotherPlan.finalDirectionMask : _plan.finalDirectionMask;
  static int get effectiveFinalMask =>
      finalDirectionMask == 0 || finalDirectionMask == OrientationMask.all
      ? OrientationMask.all
      : finalDirectionMask;

  static void setStartupDirection(int directionBit) {
    _startupDirectionBit = directionBit;
  }

  static Future<void> applyDirection(int directionBit) async {
    if (directionBit & effectiveFinalMask == 0) return;
    await _applyDirectionBit(directionBit);
  }

  static Future<void> initialize() async {
    await _initializeLegacyDefaults();
    await compile();
    if (isBrotherTech) {
      _startupDirectionBit =
          await OrientationPlatform.currentOrientationBit() ??
          _currentWindowAxisBit();
      return;
    }
    if (_plan.appInitial == AppInitialOrientation.system &&
        _plan.appRotation == AppRotationMode.lockInitial) {
      _startupDirectionBit =
          await OrientationPlatform.currentOrientationBit() ??
          _currentWindowAxisBit();
    }
  }

  static int _currentWindowAxisBit() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return OrientationMask.portraitUp;
    final size = views.first.physicalSize;
    return size.width > size.height
        ? OrientationMask.landscapeLeft
        : OrientationMask.portraitUp;
  }

  static EntryOrientationPolicy _simpleEntry(FullScreenMode mode) =>
      switch (mode) {
        FullScreenMode.none || FullScreenMode.gravity =>
          EntryOrientationPolicy.keepCurrent,
        FullScreenMode.vertical => EntryOrientationPolicy.portrait,
        FullScreenMode.horizontal => EntryOrientationPolicy.landscape,
        FullScreenMode.auto => EntryOrientationPolicy.video,
        FullScreenMode.ratio => EntryOrientationPolicy.ratio,
      };

  static Future<void> compile() async {
    final mode = Pref.orientationPolicyMode;
    _brotherEnabled = mode == OrientationPolicyMode.brotherTech;
    if (_brotherEnabled) {
      await _compileBrotherTech();
      _finalGuard.update();
      return;
    }
    _brotherGuard.update(0);
    final advanced = mode == OrientationPolicyMode.advanced;

    final appInitial = advanced
        ? Pref.advancedAppInitialOrientation
        : Pref.appInitialOrientation;
    final appRotation = advanced
        ? Pref.advancedAppRotationMode
        : Pref.appRotationMode;
    final windowedRotation = advanced
        ? Pref.advancedWindowedPlayerRotationMode
        : WindowedPlayerRotationMode.inheritApp;
    final simpleEntry = advanced ? null : _simpleEntry(Pref.fullScreenMode);
    final manualEntry = advanced
        ? Pref.advancedManualEntryOrientation
        : simpleEntry!;
    final autoEntry = advanced
        ? Pref.advancedAutoEntryOrientation
        : simpleEntry!;
    final orientationEntry = advanced
        ? Pref.advancedOrientationEntryOrientation
        : simpleEntry!;
    final fullScreenRotationSource = advanced
        ? Pref.advancedFullScreenRotationSource
        : Pref.fullScreenRotationSource;
    final fullScreenAllowed = advanced
        ? Pref.advancedFullScreenAllowedOrientation
        : Pref.fullScreenAllowedOrientation;
    final gravityFollowSystemLock = advanced
        ? Pref.advancedGravityFollowSystemLock
        : Pref.gravityFollowSystemLock;
    final simpleTrigger =
        advanced ? null : Pref.orientationFullscreenTrigger;
    final triggerEnter = advanced
        ? Pref.advancedLandscapeEnter
        : simpleTrigger == OrientationFullscreenTrigger.landscapeEnter ||
              simpleTrigger == OrientationFullscreenTrigger.both;
    final triggerExit = advanced
        ? Pref.advancedPortraitExit
        : simpleTrigger == OrientationFullscreenTrigger.portraitExit ||
              simpleTrigger == OrientationFullscreenTrigger.both;
    final enterTriggerSource = advanced
        ? Pref.advancedEnterTriggerSource
        : Pref.orientationTriggerSource;
    final exitTriggerSource = advanced
        ? Pref.advancedExitTriggerSource
        : Pref.orientationTriggerSource;
    final triggerContent = advanced
        ? Pref.advancedTriggerContent
        : OrientationTriggerContent.all;
    final angleDegrees = advanced ? Pref.advancedAngleDegrees : Pref.angleDegrees;
    final autoExitCauses = advanced
        ? Pref.advancedAutoExitCauses
        : FullscreenEntryCauseMask.all;
    final manualExitConfirmations = advanced
        ? Pref.advancedManualExitConfirmations
        : 1;
    final exitMode = advanced
        ? Pref.advancedExitOrientationMode
        : Pref.exitOrientationMode;

    final gravityNeeded =
        triggerEnter &&
            enterTriggerSource != OrientationTriggerSource.system ||
        triggerExit &&
            autoExitCauses != 0 &&
            exitTriggerSource != OrientationTriggerSource.system ||
        fullScreenRotationSource == FullScreenRotationSource.appGravity &&
            fullScreenAllowed != FullScreenAllowedOrientation.entryExact;
    final systemAutoRotate = gravityFollowSystemLock && gravityNeeded
        ? await OrientationPlatform.systemAutoRotate()
        : true;

    _plan = OrientationPlan(
      appInitial: appInitial,
      appRotation: appRotation,
      windowedRotation: windowedRotation,
      manualEntry: manualEntry,
      autoEntry: autoEntry,
      orientationEntry: orientationEntry,
      fullScreenRotationSource: fullScreenRotationSource,
      fullScreenAllowed: fullScreenAllowed,
      gravityFollowSystemLock: gravityFollowSystemLock,
      triggerEnter: triggerEnter,
      triggerExit: triggerExit,
      enterTriggerSource: enterTriggerSource,
      exitTriggerSource: exitTriggerSource,
      triggerContent: triggerContent,
      angleDegrees: angleDegrees,
      autoExitCauses: autoExitCauses,
      manualExitConfirmations: manualExitConfirmations,
      exitMode: exitMode,
      controlsLockOrientation: Pref.controlsLockOrientation,
      finalDirectionMask: Pref.finalDirectionMask,
      systemAutoRotate: systemAutoRotate,
    );
    _finalGuard.update();
  }

  static Future<void> _compileBrotherTech() async {
    final app = Pref.brotherAppPhase;
    final windowed = Pref.brotherWindowedPhase;
    final fullscreen = Pref.brotherFullscreenPhase;
    final gravityNeeded =
        app.runtimeMode == BrotherRuntimeMode.appGravity ||
        windowed.runtimeMode == BrotherRuntimeMode.appGravity ||
        fullscreen.runtimeMode == BrotherRuntimeMode.appGravity ||
        Pref.brotherLandscapeEnter &&
            Pref.brotherEnterSignalMask &
                    BrotherOrientationSignalMask.appGravity !=
                0 ||
        Pref.brotherPortraitExit &&
            Pref.brotherExitSignalMask &
                    BrotherOrientationSignalMask.appGravity !=
                0 ||
        Pref.brotherManualExitConfirmations > 0 &&
            Pref.brotherManualExitSignalMask &
                    BrotherOrientationSignalMask.appGravity !=
                0;
    final gravityUsesSystemGate =
        app.gravityFollowSystemLock ||
        windowed.gravityFollowSystemLock ||
        fullscreen.gravityFollowSystemLock;
    final systemAutoRotate = gravityNeeded && gravityUsesSystemGate
        ? await OrientationPlatform.systemAutoRotate()
        : true;

    _brotherPlan = BrotherOrientationPlan(
      app: app,
      windowed: windowed,
      fullscreen: fullscreen,
      fullscreenEnterOverrideMask: Pref.brotherFullscreenEnterOverrideMask,
      fullscreenManualEnter: Pref.brotherFullscreenManualEnter,
      fullscreenPlaybackEnter: Pref.brotherFullscreenPlaybackEnter,
      fullscreenOrientationEnter: Pref.brotherFullscreenOrientationEnter,
      windowedResumeOverrideMask: Pref.brotherWindowedResumeOverrideMask,
      windowedManualResume: Pref.brotherWindowedManualResume,
      windowedPlaybackResume: Pref.brotherWindowedPlaybackResume,
      windowedOrientationResume: Pref.brotherWindowedOrientationResume,
      landscapeEnter: Pref.brotherLandscapeEnter,
      portraitExit: Pref.brotherPortraitExit,
      enterSignalMask: Pref.brotherEnterSignalMask &
          BrotherOrientationSignalMask.all,
      enterSignalRequired: Pref.brotherEnterSignalRequired,
      exitSignalMask:
          Pref.brotherExitSignalMask & BrotherOrientationSignalMask.all,
      exitSignalRequired: Pref.brotherExitSignalRequired,
      manualExitSignalMask:
          Pref.brotherManualExitSignalMask & BrotherOrientationSignalMask.all,
      manualExitSignalRequired: Pref.brotherManualExitSignalRequired,
      enterTriggerContent: Pref.brotherEnterTriggerContent,
      exitTriggerContent: Pref.brotherExitTriggerContent,
      autoExitCauses: Pref.brotherAutoExitCauses,
      manualExitConfirmations: Pref.brotherManualExitConfirmations,
      controlsLockOrientation: Pref.controlsLockOrientation,
      finalDirectionMask: Pref.finalDirectionMask,
      systemAutoRotate: systemAutoRotate,
    );
  }

  static Future<void> _initializeLegacyDefaults() async {
    if (GStorage.setting.containsKey(SettingBoxKey.orientationConfigVersion)) {
      return;
    }
    final horizontal = Pref.horizontalScreen;
    final oldMode = Pref.fullScreenMode;
    await GStorage.setting.putAll({
      SettingBoxKey.orientationConfigVersion: 1,
      SettingBoxKey.orientationPolicyMode: OrientationPolicyMode.simple.index,
      SettingBoxKey.appInitialOrientation:
          (horizontal
                  ? AppInitialOrientation.system
                  : AppInitialOrientation.portrait)
              .index,
      SettingBoxKey.appRotationMode:
          (horizontal
                  ? AppRotationMode.followSystem
                  : AppRotationMode.lockInitial)
              .index,
      SettingBoxKey.fullScreenRotationSource:
          (oldMode == FullScreenMode.gravity || !horizontal
                  ? FullScreenRotationSource.appGravity
                  : FullScreenRotationSource.followSystem)
              .index,
      SettingBoxKey.fullScreenAllowedOrientation:
          FullScreenAllowedOrientation.all.index,
      SettingBoxKey.gravityFollowSystemLock: oldMode != FullScreenMode.gravity,
      SettingBoxKey.orientationFullscreenTrigger:
          (horizontal
                  ? OrientationFullscreenTrigger.off
                  : OrientationFullscreenTrigger.both)
              .index,
      SettingBoxKey.orientationTriggerSource:
          OrientationTriggerSource.appGravity.index,
      SettingBoxKey.exitOrientationMode: ExitOrientationMode.restoreApp.index,
      SettingBoxKey.finalDirectionMask: 0,
      if (oldMode == FullScreenMode.gravity)
        SettingBoxKey.fullScreenMode: FullScreenMode.none.index,
    });
  }

  static int orientationBit(DeviceOrientation orientation) => switch (orientation) {
    DeviceOrientation.portraitUp => OrientationMask.portraitUp,
    DeviceOrientation.portraitDown => OrientationMask.portraitDown,
    DeviceOrientation.landscapeLeft => OrientationMask.landscapeLeft,
    DeviceOrientation.landscapeRight => OrientationMask.landscapeRight,
  };

  static Future<void> applyStartup() async {
    if (isBrotherTech) {
      await applyBrotherApp(resume: false);
      return;
    }
    final plan = _plan;
    if (plan.appInitial == AppInitialOrientation.system) {
      if (plan.appRotation == AppRotationMode.lockInitial) {
        await _applyDirectionBit(_startupDirectionBit);
      } else {
        await applyAppRuntime();
      }
      return;
    }

    final requested = switch (plan.appInitial) {
      AppInitialOrientation.system => 0,
      AppInitialOrientation.portrait => OrientationMask.portrait,
      AppInitialOrientation.landscape => OrientationMask.landscape,
      AppInitialOrientation.portraitUp => OrientationMask.portraitUp,
      AppInitialOrientation.portraitDown => OrientationMask.portraitDown,
      AppInitialOrientation.landscapeLeft => OrientationMask.landscapeLeft,
      AppInitialOrientation.landscapeRight => OrientationMask.landscapeRight,
    };
    final mask = plan.filterMask(requested);
    if (mask != 0) {
      _startupDirectionBit = switch (plan.appInitial) {
        AppInitialOrientation.portrait =>
          mask == OrientationMask.portraitDown
              ? OrientationMask.portraitDown
              : OrientationMask.portraitUp,
        AppInitialOrientation.landscape =>
          mask == OrientationMask.landscapeRight
              ? OrientationMask.landscapeRight
              : OrientationMask.landscapeLeft,
        _ => mask & -mask,
      };
      await _applyDirectionBit(_startupDirectionBit);
    }
    if (plan.appRotation == AppRotationMode.lockInitial) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyAppRuntime();
    });
  }

  static Future<void> restoreApp() async {
    if (isBrotherTech) {
      await applyBrotherApp(resume: true);
      return;
    }
    if (_plan.appRotation == AppRotationMode.lockInitial) {
      await _applyDirectionBit(_startupDirectionBit);
    } else {
      await applyAppRuntime();
    }
  }

  static Future<void> applyBrotherApp({required bool resume}) async {
    final phase = _brotherPlan.app;
    await applyBrotherDirectionAction(
      resume ? phase.resumeAction : phase.enterAction,
    );
    final allowed = await resolveBrotherAllowedMask(phase);
    setBrotherActiveAllowedMask(allowed);
    await applyBrotherRuntime(phase, allowedMask: allowed);
  }

  static Future<int> resolveBrotherAllowedMask(
    BrotherPhaseConfig phase, {
    int? entryDirectionBit,
  }) async {
    final base = switch (phase.allowedBasis) {
      BrotherAllowedBasis.fixed => phase.allowedMask,
      BrotherAllowedBasis.entryAxis => switch (
          entryDirectionBit ??
              await OrientationPlatform.currentOrientationBit() ??
              _currentWindowAxisBit()
        ) {
          final bit when bit & OrientationMask.landscape != 0 =>
            OrientationMask.landscape,
          _ => OrientationMask.portrait,
        },
      BrotherAllowedBasis.entryExact =>
        entryDirectionBit ??
            await OrientationPlatform.currentOrientationBit() ??
            _currentWindowAxisBit(),
    };
    return base & effectiveFinalMask;
  }

  static Future<void> applyBrotherDirectionAction(
    BrotherDirectionAction action, {
    bool? videoVertical,
    double? screenRatio,
    DeviceOrientation? triggerOrientation,
  }) async {
    final requested = switch (action) {
      BrotherDirectionAction.keepCurrent => 0,
      BrotherDirectionAction.systemCurrent =>
        await OrientationPlatform.currentOrientationBit() ??
            _currentWindowAxisBit(),
      BrotherDirectionAction.startupDirection => _startupDirectionBit,
      BrotherDirectionAction.video => videoVertical == null
          ? 0
          : (videoVertical ? OrientationMask.portrait : OrientationMask.landscape),
      BrotherDirectionAction.ratio =>
        videoVertical == null || screenRatio == null
            ? 0
            : (videoVertical || screenRatio < 1.7777777777777777
                  ? OrientationMask.portrait
                  : OrientationMask.landscape),
      BrotherDirectionAction.portrait => OrientationMask.portrait,
      BrotherDirectionAction.landscape => OrientationMask.landscape,
      BrotherDirectionAction.portraitUp => OrientationMask.portraitUp,
      BrotherDirectionAction.portraitDown => OrientationMask.portraitDown,
      BrotherDirectionAction.landscapeLeft => OrientationMask.landscapeLeft,
      BrotherDirectionAction.landscapeRight => OrientationMask.landscapeRight,
      BrotherDirectionAction.triggerDirection => triggerOrientation == null
          ? 0
          : orientationBit(triggerOrientation),
    };
    if (requested == 0) return;
    final filtered = requested & effectiveFinalMask;
    if (filtered == 0) return;
    if (requested == OrientationMask.portrait) {
      await _applyDirectionBit(
        filtered == OrientationMask.portraitDown
            ? OrientationMask.portraitDown
            : OrientationMask.portraitUp,
      );
    } else if (requested == OrientationMask.landscape) {
      await _applyDirectionBit(
        filtered == OrientationMask.landscapeRight
            ? OrientationMask.landscapeRight
            : OrientationMask.landscapeLeft,
      );
    } else {
      await _applyDirectionBit(filtered & -filtered);
    }
  }

  static void setBrotherActiveAllowedMask(int mask) {
    if (_brotherEnabled) _brotherGuard.update(mask);
  }

  static Future<void> applyBrotherRuntime(
    BrotherPhaseConfig phase, {
    required int allowedMask,
  }) async {
    if (allowedMask == 0) return;
    switch (phase.runtimeMode) {
      case BrotherRuntimeMode.inheritRequest:
      case BrotherRuntimeMode.appGravity:
        return;
      case BrotherRuntimeMode.followSystemAllowed:
        await applySystemPolicy(
          ignoreSystemLock: false,
          allowedMask: allowedMask,
          filterEnabled: allowedMask != OrientationMask.all,
        );
        return;
      case BrotherRuntimeMode.alwaysAutoAllowed:
        await applySystemPolicy(
          ignoreSystemLock: true,
          allowedMask: allowedMask,
          filterEnabled: allowedMask != OrientationMask.all,
        );
        return;
      case BrotherRuntimeMode.systemGate:
        if (await OrientationPlatform.systemAutoRotate()) {
          if (allowedMask == OrientationMask.all) {
            await fullSensorMode();
          } else {
            await applyAutoOrientationMask(
              allowedMask,
              ignoreSystemLock: true,
            );
          }
        } else {
          await lockedMode();
        }
        return;
      default:
        final request = switch (phase.runtimeMode) {
          BrotherRuntimeMode.unspecified =>
            AndroidRequestedOrientation.unspecified,
          BrotherRuntimeMode.landscape => AndroidRequestedOrientation.landscape,
          BrotherRuntimeMode.portrait => AndroidRequestedOrientation.portrait,
          BrotherRuntimeMode.user => AndroidRequestedOrientation.user,
          BrotherRuntimeMode.behind => AndroidRequestedOrientation.behind,
          BrotherRuntimeMode.sensor => AndroidRequestedOrientation.sensor,
          BrotherRuntimeMode.noSensor => AndroidRequestedOrientation.noSensor,
          BrotherRuntimeMode.sensorLandscape =>
            AndroidRequestedOrientation.sensorLandscape,
          BrotherRuntimeMode.sensorPortrait =>
            AndroidRequestedOrientation.sensorPortrait,
          BrotherRuntimeMode.reverseLandscape =>
            AndroidRequestedOrientation.reverseLandscape,
          BrotherRuntimeMode.reversePortrait =>
            AndroidRequestedOrientation.reversePortrait,
          BrotherRuntimeMode.fullSensor =>
            AndroidRequestedOrientation.fullSensor,
          BrotherRuntimeMode.userLandscape =>
            AndroidRequestedOrientation.userLandscape,
          BrotherRuntimeMode.userPortrait =>
            AndroidRequestedOrientation.userPortrait,
          BrotherRuntimeMode.fullUser => AndroidRequestedOrientation.fullUser,
          BrotherRuntimeMode.locked => AndroidRequestedOrientation.locked,
          BrotherRuntimeMode.inheritRequest ||
          BrotherRuntimeMode.followSystemAllowed ||
          BrotherRuntimeMode.alwaysAutoAllowed ||
          BrotherRuntimeMode.systemGate ||
          BrotherRuntimeMode.appGravity => null,
        };
        if (request != null) await androidRequestedOrientationMode(request);
    }
  }

  static Future<void> applyWindowedRuntime(
    WindowedPlayerRotationMode mode,
  ) async {
    switch (mode) {
      case WindowedPlayerRotationMode.inheritApp:
        await restoreApp();
      case WindowedPlayerRotationMode.keepCurrent:
        await lockedMode();
      case WindowedPlayerRotationMode.followSystem:
        await applySystemPolicy(
          ignoreSystemLock: false,
          allowedMask: _plan.effectiveFinalMask,
          filterEnabled: _plan.finalDirectionMask != 0 &&
              _plan.finalDirectionMask != OrientationMask.all,
        );
      case WindowedPlayerRotationMode.alwaysAuto:
        await applySystemPolicy(
          ignoreSystemLock: true,
          allowedMask: _plan.effectiveFinalMask,
          filterEnabled: _plan.finalDirectionMask != 0 &&
              _plan.finalDirectionMask != OrientationMask.all,
        );
    }
  }

  static Future<void> _applyDirectionBit(int bit) async {
    switch (bit) {
      case OrientationMask.portraitDown:
        await portraitDownMode();
      case OrientationMask.landscapeLeft:
        await landscapeLeftMode();
      case OrientationMask.landscapeRight:
        await landscapeRightMode();
      default:
        await portraitUpMode();
    }
  }

  static Future<void> applyAppRuntime() async {
    final plan = _plan;
    switch (plan.appRotation) {
      case AppRotationMode.lockInitial:
        return;
      case AppRotationMode.followSystem:
        await applySystemPolicy(
          ignoreSystemLock: false,
          allowedMask: plan.effectiveFinalMask,
          filterEnabled: plan.finalDirectionMask != 0 &&
              plan.finalDirectionMask != OrientationMask.all,
        );
      case AppRotationMode.alwaysAuto:
        await applySystemPolicy(
          ignoreSystemLock: true,
          allowedMask: plan.effectiveFinalMask,
          filterEnabled: plan.finalDirectionMask != 0 &&
              plan.finalDirectionMask != OrientationMask.all,
        );
    }
  }

  static Future<void> applySystemPolicy({
    required bool ignoreSystemLock,
    required int allowedMask,
    required bool filterEnabled,
  }) async {
    if (!filterEnabled) {
      if (ignoreSystemLock) {
        await fullSensorMode();
      } else {
        await followSystemMode();
      }
      return;
    }
    await applyAutoOrientationMask(
      allowedMask,
      ignoreSystemLock: ignoreSystemLock,
    );
  }
}


final class _BrotherOrientationGuard with WidgetsBindingObserver {
  int _mask = OrientationMask.all;
  bool _active = false;
  bool _checking = false;

  void update(int mask) {
    _mask = mask;
    final active =
        Platform.isAndroid &&
        mask != 0 &&
        mask != OrientationMask.all;
    if (active == _active) return;
    _active = active;
    if (active) {
      WidgetsBinding.instance.addObserver(this);
    } else {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void didChangeMetrics() {
    if (!_active || _checking) return;
    _check();
  }

  Future<void> _check() async {
    _checking = true;
    try {
      final current = await OrientationPlatform.currentOrientationBit();
      if (current == null || _mask & current != 0) return;
      final axis = current & OrientationMask.portrait != 0
          ? OrientationMask.portrait
          : OrientationMask.landscape;
      final sameAxis = _mask & axis;
      final target = _firstBit(sameAxis != 0 ? sameAxis : _mask);
      if (target != 0) await OrientationPolicy._applyDirectionBit(target);
    } finally {
      _checking = false;
    }
  }

  int _firstBit(int mask) {
    if (mask & OrientationMask.portraitUp != 0) {
      return OrientationMask.portraitUp;
    }
    if (mask & OrientationMask.landscapeLeft != 0) {
      return OrientationMask.landscapeLeft;
    }
    if (mask & OrientationMask.landscapeRight != 0) {
      return OrientationMask.landscapeRight;
    }
    if (mask & OrientationMask.portraitDown != 0) {
      return OrientationMask.portraitDown;
    }
    return 0;
  }
}

final class _FinalOrientationGuard with WidgetsBindingObserver {
  bool _active = false;
  bool _checking = false;

  void update() {
    final mask = OrientationPolicy.finalDirectionMask;
    final nativeMask =
        mask == OrientationMask.portraitUp ||
        mask == OrientationMask.portraitDown ||
        mask == OrientationMask.landscapeLeft ||
        mask == OrientationMask.landscapeRight ||
        mask == OrientationMask.portrait ||
        mask == OrientationMask.landscape ||
        mask == 13 ||
        mask == OrientationMask.all;
    final active = Platform.isAndroid && mask != 0 && !nativeMask;
    if (active == _active) return;
    _active = active;
    if (active) {
      WidgetsBinding.instance.addObserver(this);
    } else {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void didChangeMetrics() {
    if (!_active || _checking) return;
    _check();
  }

  Future<void> _check() async {
    _checking = true;
    try {
      final current = await OrientationPlatform.currentOrientationBit();
      if (current == null) return;
      final mask = OrientationPolicy.finalDirectionMask;
      if (mask == 0 ||
          mask == OrientationMask.all ||
          mask & current != 0) {
        return;
      }
      final axis = current & OrientationMask.portrait != 0
          ? OrientationMask.portrait
          : OrientationMask.landscape;
      final sameAxis = mask & axis;
      final target = sameAxis != 0
          ? _firstBit(sameAxis)
          : _firstBit(mask);
      if (target != 0) {
        await OrientationPolicy._applyDirectionBit(target);
      }
    } finally {
      _checking = false;
    }
  }

  int _firstBit(int mask) {
    if (mask & OrientationMask.portraitUp != 0) {
      return OrientationMask.portraitUp;
    }
    if (mask & OrientationMask.landscapeLeft != 0) {
      return OrientationMask.landscapeLeft;
    }
    if (mask & OrientationMask.landscapeRight != 0) {
      return OrientationMask.landscapeRight;
    }
    if (mask & OrientationMask.portraitDown != 0) {
      return OrientationMask.portraitDown;
    }
    return 0;
  }
}
