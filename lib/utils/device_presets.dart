import 'dart:io' show Platform;

import 'package:PiliBro/plugin/pl_player/models/auto_fullscreen_mode.dart';
import 'package:PiliBro/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliBro/plugin/pl_player/models/hwdec_type.dart';
import 'package:PiliBro/plugin/pl_player/models/orientation_mode.dart';
import 'package:PiliBro/utils/device_utils.dart';
import 'package:PiliBro/utils/orientation_policy.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';

abstract final class DevicePresets {
  static Future<void> applyPhone({bool applyNow = true}) async {
    await GStorage.setting.deleteAll(const [
      SettingBoxKey.advancedAppInitialOrientation,
      SettingBoxKey.advancedAppRotationMode,
      SettingBoxKey.advancedWindowedPlayerRotationMode,
      SettingBoxKey.advancedLandscapeEnter,
      SettingBoxKey.advancedPortraitExit,
      SettingBoxKey.advancedEnterTriggerSource,
      SettingBoxKey.advancedExitTriggerSource,
      SettingBoxKey.advancedTriggerContent,
      SettingBoxKey.advancedManualEntryOrientation,
      SettingBoxKey.advancedAutoEntryOrientation,
      SettingBoxKey.advancedOrientationEntryOrientation,
      SettingBoxKey.advancedFullScreenRotationSource,
      SettingBoxKey.advancedFullScreenAllowedOrientation,
      SettingBoxKey.advancedGravityFollowSystemLock,
      SettingBoxKey.advancedAngleDegrees,
      SettingBoxKey.advancedAutoExitCauses,
      SettingBoxKey.advancedManualExitConfirmations,
      SettingBoxKey.advancedExitOrientationMode,
      SettingBoxKey.brotherAppPhase,
      SettingBoxKey.brotherWindowedPhase,
      SettingBoxKey.brotherFullscreenPhase,
      SettingBoxKey.brotherFullscreenEnterOverrideMask,
      SettingBoxKey.brotherFullscreenManualEnter,
      SettingBoxKey.brotherFullscreenPlaybackEnter,
      SettingBoxKey.brotherFullscreenOrientationEnter,
      SettingBoxKey.brotherWindowedResumeOverrideMask,
      SettingBoxKey.brotherWindowedManualResume,
      SettingBoxKey.brotherWindowedPlaybackResume,
      SettingBoxKey.brotherWindowedOrientationResume,
      SettingBoxKey.brotherLandscapeEnter,
      SettingBoxKey.brotherPortraitExit,
      SettingBoxKey.brotherEnterSignalMask,
      SettingBoxKey.brotherEnterSignalRequired,
      SettingBoxKey.brotherExitSignalMask,
      SettingBoxKey.brotherExitSignalRequired,
      SettingBoxKey.brotherManualExitSignalMask,
      SettingBoxKey.brotherManualExitSignalRequired,
      SettingBoxKey.brotherEnterTriggerContent,
      SettingBoxKey.brotherExitTriggerContent,
      SettingBoxKey.brotherAutoExitCauses,
      SettingBoxKey.brotherManualExitConfirmations,
    ]);
    await _apply(
    {
      SettingBoxKey.orientationPolicyMode:
          Platform.isAndroid && DeviceUtils.sdkInt >= 34
              ? OrientationPolicyMode.brotherTech.index
              : OrientationPolicyMode.advanced.index,
      SettingBoxKey.horizontalScreen: false,
      SettingBoxKey.keyboardControl: true,
      SettingBoxKey.autoFullscreenMode: AutoFullscreenMode.off.index,
      SettingBoxKey.appInitialOrientation: AppInitialOrientation.system.index,
      SettingBoxKey.appRotationMode: AppRotationMode.followSystem.index,
      SettingBoxKey.fullScreenMode: FullScreenMode.auto.index,
      SettingBoxKey.fullScreenRotationSource:
          FullScreenRotationSource.keepCurrent.index,
      SettingBoxKey.fullScreenAllowedOrientation:
          FullScreenAllowedOrientation.all.index,
      SettingBoxKey.gravityFollowSystemLock: false,
      SettingBoxKey.orientationFullscreenTrigger:
          OrientationFullscreenTrigger.both.index,
      SettingBoxKey.orientationTriggerSource:
          OrientationTriggerSource.system.index,
      SettingBoxKey.angleDegrees: 45,
      SettingBoxKey.exitOrientationMode: ExitOrientationMode.restoreApp.index,
      SettingBoxKey.finalDirectionMask: 0,


    },
    applyNow: applyNow,
    );
  }

  static Future<void> applyTablet({bool applyNow = true}) => _apply(
    {
      SettingBoxKey.orientationPolicyMode: OrientationPolicyMode.advanced.index,
      SettingBoxKey.horizontalScreen: true,
      SettingBoxKey.keyboardControl: true,
      SettingBoxKey.autoFullscreenMode: AutoFullscreenMode.off.index,
      SettingBoxKey.appInitialOrientation: AppInitialOrientation.system.index,
      SettingBoxKey.appRotationMode: AppRotationMode.alwaysAuto.index,
      SettingBoxKey.fullScreenMode: FullScreenMode.none.index,
      SettingBoxKey.fullScreenRotationSource:
          FullScreenRotationSource.appGravity.index,
      SettingBoxKey.fullScreenAllowedOrientation:
          FullScreenAllowedOrientation.all.index,
      SettingBoxKey.gravityFollowSystemLock: true,
      SettingBoxKey.orientationFullscreenTrigger:
          OrientationFullscreenTrigger.off.index,
      SettingBoxKey.orientationTriggerSource:
          OrientationTriggerSource.system.index,
      SettingBoxKey.angleDegrees: 30,
      SettingBoxKey.exitOrientationMode: ExitOrientationMode.lockPlayer.index,
      SettingBoxKey.finalDirectionMask: 0,
      SettingBoxKey.advancedEnterTriggerSource:
          OrientationTriggerSource.appGravity.index,
      SettingBoxKey.advancedExitTriggerSource:
          OrientationTriggerSource.appGravity.index,
      SettingBoxKey.advancedManualEntryOrientation:
          EntryOrientationPolicy.keepCurrent.index,
      SettingBoxKey.advancedFullScreenRotationSource:
          FullScreenRotationSource.followSystem.index,
      if (Platform.isAndroid)
        SettingBoxKey.hardwareDecoding: HwDecType.embedWithFallback,
    },
    applyNow: applyNow,
  );

  static Future<void> applyFoldable({bool applyNow = true}) => _apply(
    {
      SettingBoxKey.orientationPolicyMode: OrientationPolicyMode.simple.index,
      SettingBoxKey.horizontalScreen: true,
      SettingBoxKey.keyboardControl: true,
      SettingBoxKey.autoFullscreenMode: AutoFullscreenMode.off.index,
      SettingBoxKey.appInitialOrientation: AppInitialOrientation.system.index,
      SettingBoxKey.appRotationMode: AppRotationMode.followSystem.index,
      SettingBoxKey.fullScreenMode: FullScreenMode.ratio.index,
      SettingBoxKey.fullScreenRotationSource:
          FullScreenRotationSource.followSystem.index,
      SettingBoxKey.fullScreenAllowedOrientation:
          FullScreenAllowedOrientation.all.index,
      SettingBoxKey.gravityFollowSystemLock: false,
      SettingBoxKey.orientationFullscreenTrigger:
          OrientationFullscreenTrigger.both.index,
      SettingBoxKey.orientationTriggerSource:
          OrientationTriggerSource.appGravity.index,
      SettingBoxKey.angleDegrees: 55,
      SettingBoxKey.exitOrientationMode: ExitOrientationMode.keepPlayer.index,
      SettingBoxKey.finalDirectionMask: 0,
    },
    applyNow: applyNow,
  );

  static Future<void> restoreTabletDefaults() async {
    await GStorage.setting.delete(SettingBoxKey.keyboardControl);
    await applyTablet();
  }

  static Future<void> applyTelevision() async {
    await _apply(
      {
        SettingBoxKey.orientationPolicyMode: OrientationPolicyMode.simple.index,
        SettingBoxKey.horizontalScreen: true,
        SettingBoxKey.keyboardControl: false,
        SettingBoxKey.appInitialOrientation:
            AppInitialOrientation.landscape.index,
        SettingBoxKey.appRotationMode: AppRotationMode.lockInitial.index,
        SettingBoxKey.fullScreenMode: FullScreenMode.none.index,
        SettingBoxKey.fullScreenRotationSource:
            FullScreenRotationSource.keepCurrent.index,
        SettingBoxKey.fullScreenAllowedOrientation:
            FullScreenAllowedOrientation.entryExact.index,
        SettingBoxKey.gravityFollowSystemLock: false,
        SettingBoxKey.orientationFullscreenTrigger:
            OrientationFullscreenTrigger.off.index,
        SettingBoxKey.orientationTriggerSource:
            OrientationTriggerSource.system.index,
        SettingBoxKey.exitOrientationMode: ExitOrientationMode.restoreApp.index,
        SettingBoxKey.finalDirectionMask: 0,
        SettingBoxKey.defaultShowComment: false,
        SettingBoxKey.autoFullscreenMode: AutoFullscreenMode.always.index,
        if (Platform.isAndroid)
          SettingBoxKey.hardwareDecoding: HwDecType.embedWithFallback,
      },
      applyNow: false,
    );

    await GStorage.setting.putAll({
      if (Pref.bufferSize > 96) SettingBoxKey.bufferSize: 96.0,
      if (Pref.bufferSizeWeak > 32) SettingBoxKey.bufferSizeWeak: 32.0,
      if (Pref.bufferSec > 108) SettingBoxKey.bufferSec: 108.0,
      if (Pref.bufferSecWeak > 30) SettingBoxKey.bufferSecWeak: 30.0,
    });
  }

  static Future<void> _apply(
    Map<String, Object> values, {
    required bool applyNow,
  }) async {
    await GStorage.setting.putAll(values);
    await OrientationPolicy.compile();
    if (applyNow) await OrientationPolicy.applyStartup();
  }
}
