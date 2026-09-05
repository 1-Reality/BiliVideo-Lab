import 'package:PiliBro/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliBro/plugin/pl_player/models/orientation_mode.dart';
import 'package:PiliBro/utils/orientation_policy.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';

abstract final class DevicePresets {
  static Future<void> applyPhone({bool applyNow = true}) => _apply(
    {
      SettingBoxKey.horizontalScreen: false,
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
          OrientationTriggerSource.appGravity.index,
      SettingBoxKey.angleDegrees: 45,
      SettingBoxKey.exitOrientationMode: ExitOrientationMode.restoreApp.index,
      SettingBoxKey.finalDirectionMask: 0,
    },
    applyNow: applyNow,
  );

  static Future<void> applyTablet({bool applyNow = true}) => _apply(
    {
      SettingBoxKey.horizontalScreen: true,
      SettingBoxKey.appInitialOrientation: AppInitialOrientation.system.index,
      SettingBoxKey.appRotationMode: AppRotationMode.alwaysAuto.index,
      SettingBoxKey.fullScreenMode: FullScreenMode.none.index,
      SettingBoxKey.fullScreenRotationSource:
          FullScreenRotationSource.followSystem.index,
      SettingBoxKey.fullScreenAllowedOrientation:
          FullScreenAllowedOrientation.all.index,
      SettingBoxKey.gravityFollowSystemLock: true,
      SettingBoxKey.orientationFullscreenTrigger:
          OrientationFullscreenTrigger.off.index,
      SettingBoxKey.orientationTriggerSource:
          OrientationTriggerSource.system.index,
      SettingBoxKey.angleDegrees: 30,
      SettingBoxKey.exitOrientationMode: ExitOrientationMode.keepPlayer.index,
      SettingBoxKey.finalDirectionMask: 0,
    },
    applyNow: applyNow,
  );

  static Future<void> applyFoldable({bool applyNow = true}) => _apply(
    {
      SettingBoxKey.horizontalScreen: true,
      SettingBoxKey.appInitialOrientation: AppInitialOrientation.system.index,
      SettingBoxKey.appRotationMode: AppRotationMode.lockInitial.index,
      SettingBoxKey.fullScreenMode: FullScreenMode.ratio.index,
      SettingBoxKey.fullScreenRotationSource:
          FullScreenRotationSource.appGravity.index,
      SettingBoxKey.fullScreenAllowedOrientation:
          FullScreenAllowedOrientation.all.index,
      SettingBoxKey.gravityFollowSystemLock: false,
      SettingBoxKey.orientationFullscreenTrigger:
          OrientationFullscreenTrigger.both.index,
      SettingBoxKey.orientationTriggerSource:
          OrientationTriggerSource.appGravity.index,
      SettingBoxKey.angleDegrees: 55,
      SettingBoxKey.exitOrientationMode: ExitOrientationMode.restoreApp.index,
      SettingBoxKey.finalDirectionMask: 0,
    },
    applyNow: applyNow,
  );

  static Future<void> restoreTabletDefaults() async {
    await GStorage.setting.delete(SettingBoxKey.keyboardControl);
    await applyTablet();
  }

  static Future<void> applyTelevision() => _apply(
    {
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
    },
    applyNow: false,
  );

  static Future<void> _apply(
    Map<String, Object> values, {
    required bool applyNow,
  }) async {
    await GStorage.setting.putAll(values);
    await OrientationPolicy.compile();
    if (applyNow) await OrientationPolicy.applyStartup();
  }
}
