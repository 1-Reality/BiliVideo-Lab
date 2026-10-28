import 'dart:io' show Platform;

import 'package:PiliBro/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliBro/plugin/pl_player/models/hwdec_type.dart';
import 'package:PiliBro/plugin/pl_player/models/orientation_mode.dart';
import 'package:PiliBro/utils/device_utils.dart';
import 'package:PiliBro/utils/orientation_policy.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';

abstract final class DevicePresets {
  static Future<void> applyPhone({bool applyNow = true}) => _apply(
    {
      SettingBoxKey.orientationPolicyMode:
          Platform.isAndroid && DeviceUtils.sdkInt >= 34
              ? OrientationPolicyMode.brotherTech.index
              : OrientationPolicyMode.advanced.index,
      SettingBoxKey.horizontalScreen: false,
      SettingBoxKey.keyboardControl: true,
      SettingBoxKey.enableAutoEnter: false,
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

      // 高级模式旋转配置：为手机预先保存完整配置。
      SettingBoxKey.advancedAppInitialOrientation:
          AppInitialOrientation.system.index,
      SettingBoxKey.advancedAppRotationMode: AppRotationMode.followSystem.index,
      SettingBoxKey.advancedWindowedPlayerRotationMode:
          WindowedPlayerRotationMode.alwaysAuto.index,
      SettingBoxKey.advancedLandscapeEnter: true,
      SettingBoxKey.advancedPortraitExit: true,
      SettingBoxKey.advancedEnterTriggerSource:
          OrientationTriggerSource.system.index,
      SettingBoxKey.advancedExitTriggerSource:
          OrientationTriggerSource.system.index,
      SettingBoxKey.advancedTriggerContent:
          OrientationTriggerContent.landscapeVideo.index,
      SettingBoxKey.advancedManualEntryOrientation:
          EntryOrientationPolicy.video.index,
      SettingBoxKey.advancedAutoEntryOrientation:
          EntryOrientationPolicy.video.index,
      SettingBoxKey.advancedOrientationEntryOrientation:
          EntryOrientationPolicy.triggerDirection.index,
      SettingBoxKey.advancedFullScreenRotationSource:
          FullScreenRotationSource.alwaysAuto.index,
      SettingBoxKey.advancedFullScreenAllowedOrientation:
          FullScreenAllowedOrientation.all.index,
      SettingBoxKey.advancedGravityFollowSystemLock: false,
      SettingBoxKey.advancedAngleDegrees: 30,
      SettingBoxKey.advancedAutoExitCauses: 5,
      SettingBoxKey.advancedManualExitConfirmations: 0,
      SettingBoxKey.advancedExitOrientationMode:
          ExitOrientationMode.restoreApp.index,

      // 哥哥科技模式旋转配置：采用已实测的手机配置。
      SettingBoxKey.brotherAppPhase: [
        1, 0, 1, 0, 0, 15, true, 30, 16, 18, 1, 17,
      ],
      SettingBoxKey.brotherWindowedPhase: [
        0, 2, 18, 0, 0, 15, true, 30, -1, 17, 0, 16,
      ],
      SettingBoxKey.brotherFullscreenPhase: [
        3, 0, 16, 0, 0, 15, true, 30, -1, -1, 0, 16,
      ],
      SettingBoxKey.brotherFullscreenEnterOverrideMask: 0,
      SettingBoxKey.brotherFullscreenManualEnter:
          BrotherDirectionAction.video.index,
      SettingBoxKey.brotherFullscreenPlaybackEnter:
          BrotherDirectionAction.video.index,
      SettingBoxKey.brotherFullscreenOrientationEnter:
          BrotherDirectionAction.triggerDirection.index,
      SettingBoxKey.brotherWindowedResumeOverrideMask: 0,
      SettingBoxKey.brotherWindowedManualResume:
          BrotherDirectionAction.keepCurrent.index,
      SettingBoxKey.brotherWindowedPlaybackResume:
          BrotherDirectionAction.keepCurrent.index,
      SettingBoxKey.brotherWindowedOrientationResume:
          BrotherDirectionAction.triggerDirection.index,
      SettingBoxKey.brotherLandscapeEnter: true,
      SettingBoxKey.brotherPortraitExit: true,
      SettingBoxKey.brotherEnterSignalMask: 2,
      SettingBoxKey.brotherEnterSignalRequired: 1,
      SettingBoxKey.brotherExitSignalMask: 2,
      SettingBoxKey.brotherExitSignalRequired: 1,
      SettingBoxKey.brotherManualExitSignalMask: 1,
      SettingBoxKey.brotherManualExitSignalRequired: 0,
      SettingBoxKey.brotherEnterTriggerContent:
          OrientationTriggerContent.all.index,
      SettingBoxKey.brotherExitTriggerContent:
          OrientationTriggerContent.all.index,
      SettingBoxKey.brotherAutoExitCauses: 5,
      SettingBoxKey.brotherManualExitConfirmations: 0,
    },
    applyNow: applyNow,
  );

  static Future<void> applyTablet({bool applyNow = true}) => _apply(
    {
      SettingBoxKey.orientationPolicyMode: OrientationPolicyMode.simple.index,
      SettingBoxKey.horizontalScreen: true,
      SettingBoxKey.keyboardControl: true,
      SettingBoxKey.enableAutoEnter: false,
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
      SettingBoxKey.enableAutoEnter: false,
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
        SettingBoxKey.enableAutoEnter: true,
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
