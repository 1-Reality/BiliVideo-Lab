import 'dart:io' show Platform;

import 'package:PiliBro/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliBro/plugin/pl_player/models/orientation_mode.dart';
import 'package:PiliBro/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliBro/plugin/pl_player/utils/orientation_platform.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart' show WidgetsBinding;

final class OrientationPlan {
  const OrientationPlan({
    required this.appInitial,
    required this.appRotation,
    required this.enterFullScreen,
    required this.fullScreenRotationSource,
    required this.fullScreenAllowed,
    required this.gravityFollowSystemLock,
    required this.fullScreenTrigger,
    required this.triggerSource,
    required this.angleDegrees,
    required this.exitMode,
    required this.finalDirectionMask,
    required this.systemAutoRotate,
  });

  final AppInitialOrientation appInitial;
  final AppRotationMode appRotation;
  final FullScreenMode enterFullScreen;
  final FullScreenRotationSource fullScreenRotationSource;
  final FullScreenAllowedOrientation fullScreenAllowed;
  final bool gravityFollowSystemLock;
  final OrientationFullscreenTrigger fullScreenTrigger;
  final OrientationTriggerSource triggerSource;
  final int angleDegrees;
  final ExitOrientationMode exitMode;
  final int finalDirectionMask;
  final bool systemAutoRotate;

  int get effectiveFinalMask =>
      finalDirectionMask == 0 || finalDirectionMask == OrientationMask.all
      ? OrientationMask.all
      : finalDirectionMask;

  bool get gravityAllowed =>
      !gravityFollowSystemLock || systemAutoRotate;

  bool get triggerEnter =>
      fullScreenTrigger == OrientationFullscreenTrigger.landscapeEnter ||
      fullScreenTrigger == OrientationFullscreenTrigger.both;

  bool get triggerExit =>
      fullScreenTrigger == OrientationFullscreenTrigger.portraitExit ||
      fullScreenTrigger == OrientationFullscreenTrigger.both;

  bool get triggerUsesGravity =>
      triggerSource != OrientationTriggerSource.system;

  bool get triggerUsesSystem =>
      triggerSource != OrientationTriggerSource.appGravity;

  int filterMask(int mask) => mask & effectiveFinalMask;
}

abstract final class OrientationPolicy {
  static OrientationPlan _plan = const OrientationPlan(
    appInitial: AppInitialOrientation.system,
    appRotation: AppRotationMode.followSystem,
    enterFullScreen: FullScreenMode.auto,
    fullScreenRotationSource: FullScreenRotationSource.followSystem,
    fullScreenAllowed: FullScreenAllowedOrientation.all,
    gravityFollowSystemLock: true,
    fullScreenTrigger: OrientationFullscreenTrigger.off,
    triggerSource: OrientationTriggerSource.system,
    angleDegrees: 30,
    exitMode: ExitOrientationMode.restoreApp,
    finalDirectionMask: 0,
    systemAutoRotate: true,
  );

  static int _startupDirectionBit = OrientationMask.portraitUp;

  static OrientationPlan get plan => _plan;

  static Future<void> initialize() async {
    await _initializeLegacyDefaults();
    _startupDirectionBit =
        await OrientationPlatform.currentOrientationBit() ??
        _currentWindowAxisBit();
    await compile();
  }

  static int _currentWindowAxisBit() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return OrientationMask.portraitUp;
    final size = views.first.physicalSize;
    return size.width > size.height
        ? OrientationMask.landscapeLeft
        : OrientationMask.portraitUp;
  }

  static Future<void> compile() async {
    _plan = OrientationPlan(
      appInitial: Pref.appInitialOrientation,
      appRotation: Pref.appRotationMode,
      enterFullScreen: Pref.fullScreenMode,
      fullScreenRotationSource: Pref.fullScreenRotationSource,
      fullScreenAllowed: Pref.fullScreenAllowedOrientation,
      gravityFollowSystemLock: Pref.gravityFollowSystemLock,
      fullScreenTrigger: Pref.orientationFullscreenTrigger,
      triggerSource: Pref.orientationTriggerSource,
      angleDegrees: Pref.angleDegrees,
      exitMode: Pref.exitOrientationMode,
      finalDirectionMask: Pref.finalDirectionMask,
      systemAutoRotate: await OrientationPlatform.systemAutoRotate(),
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
    final plan = _plan;
    if (plan.appInitial == AppInitialOrientation.system) {
      if (plan.appRotation == AppRotationMode.lockInitial) {
        await _applyDirectionBit(_startupDirectionBit);
      } else {
        await applyAppRuntime();
      }
      return;
    }

    final mask = plan.filterMask(
      plan.appInitial == AppInitialOrientation.portrait
          ? OrientationMask.portrait
          : OrientationMask.landscape,
    );
    if (mask != 0) {
      _startupDirectionBit = plan.appInitial == AppInitialOrientation.portrait
          ? (mask == OrientationMask.portraitDown
                ? OrientationMask.portraitDown
                : OrientationMask.portraitUp)
          : (mask == OrientationMask.landscapeRight
                ? OrientationMask.landscapeRight
                : OrientationMask.landscapeLeft);
      await _applyDirectionBit(_startupDirectionBit);
    }
    if (plan.appRotation == AppRotationMode.lockInitial) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyAppRuntime();
    });
  }

  static Future<void> restoreApp() async {
    if (_plan.appRotation == AppRotationMode.lockInitial) {
      await _applyDirectionBit(_startupDirectionBit);
    } else {
      await applyAppRuntime();
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
