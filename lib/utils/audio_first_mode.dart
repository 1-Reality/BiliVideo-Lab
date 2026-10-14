import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:get/get.dart';

/// Optional entry preference. The normal video path is unchanged when disabled.
abstract final class AudioFirstMode {
  static final enabled = Pref.enableAudioFirst.obs;
  static final audio = Pref.preferAudioEntry.obs;

  static bool get openAudio => enabled.value && audio.value;

  // The SwitchModel already persists the setting.
  static void onEnabledChanged(bool value) => enabled.value = value;

  /// From the audio page. Turning it on also enables the quick switch, since
  /// the preference has no effect otherwise.
  static void setDefaultAudio(bool value) {
    if (value && !enabled.value) {
      enabled.value = true;
      GStorage.setting.put(SettingBoxKey.enableAudioFirst, true);
    }
    audio.value = value;
    GStorage.setting.put(SettingBoxKey.preferAudioEntry, value);
  }

  static void toggle() {
    audio.toggle();
    GStorage.setting.put(SettingBoxKey.preferAudioEntry, audio.value);
  }
}
