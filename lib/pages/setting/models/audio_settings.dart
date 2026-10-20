import 'dart:io' show Platform;

import 'package:PiliBro/common/widgets/custom_icon.dart';
import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/models/common/audio_normalization.dart';
import 'package:PiliBro/pages/main/controller.dart';
import 'package:PiliBro/pages/setting/models/extra_settings.dart'
    show audioNormalization;
import 'package:PiliBro/pages/setting/models/model.dart';
import 'package:PiliBro/pages/setting/models/play_settings.dart'
    show showMaxVolumeDialog, showPlayerVolumeDialog;
import 'package:PiliBro/pages/setting/models/video_settings.dart'
    show showAudioOutputDialog;
import 'package:PiliBro/services/service_locator.dart';
import 'package:PiliBro/utils/audio_first_mode.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// The 音视频快捷切换 · 音频与后台 submenu: the listen-to-video mode switch,
/// the bottom playback bar (also the outer switch of that menu entry),
/// background playback and audio output. Audio CDN and audio quality stay with
/// the CDN and quality settings they belong to.
List<SettingsModel> get audioSettings => [
  const SwitchModel(
    title: '音视频快捷切换（听视频模式）',
    subtitle: '首页右上角可一键切换默认进入音频或视频；关闭后不构建该入口',
    leading: Icon(Icons.headphones_outlined),
    setKey: SettingBoxKey.enableAudioFirst,
    needReboot: true,
    onChanged: AudioFirstMode.onEnabledChanged,
  ),
  const SwitchModel(
    title: '底部播放条',
    subtitle: '离开视频或听视频页后，在首页底栏上方显示一条：点主体回到原模式，点音符切换视频/音频。与音视频快捷切换无关；关闭后既不记录也不构建',
    leading: Icon(Icons.call_to_action_outlined),
    setKey: SettingBoxKey.showAudioMiniPlayer,
    defaultVal: true,
    needReboot: true,
  ),
  if (PlatformUtils.isMobile)
    SwitchModel(
      title: '后台音频服务',
      subtitle: '避免画中画没有播放暂停功能',
      leading: const Icon(Icons.volume_up_outlined),
      setKey: SettingBoxKey.enableBackgroundPlay,
      defaultVal: true,
      onChanged: (value) =>
          videoPlayerServiceHandler!.enableBackgroundPlay = value,
    ),
  if (PlatformUtils.isMobile)
    const SwitchModel(
      title: '后台播放',
      subtitle: '进入后台时继续播放',
      leading: Icon(Icons.motion_photos_pause_outlined),
      setKey: SettingBoxKey.continuePlayInBackground,
      defaultVal: false,
    ),
  if (Platform.isAndroid) ...[
    SwitchModel(
      title: '后台画中画',
      subtitle: '进入后台时以小窗形式（PiP）播放',
      leading: const Icon(Icons.picture_in_picture_outlined),
      setKey: SettingBoxKey.autoPiP,
      defaultVal: false,
      onChanged: (val) {
        if (val && !videoPlayerServiceHandler!.enableBackgroundPlay) {
          SmartDialog.showToast('建议开启后台音频服务');
        }
      },
    ),
    const SwitchModel(
      title: '画中画不加载弹幕',
      subtitle: '当弹幕开关开启时，小窗屏蔽弹幕以获得较好的体验',
      leading: Icon(CustomIcons.dm_off),
      setKey: SettingBoxKey.pipNoDanmaku,
      defaultVal: true,
    ),
  ],
  if (PlatformUtils.isDesktop)
    SwitchModel(
      title: '最小化时暂停/还原时播放',
      leading: const Icon(Icons.pause_circle_outline),
      setKey: SettingBoxKey.pauseOnMinimize,
      defaultVal: false,
      onChanged: (value) {
        try {
          Get.find<MainController>().pauseOnMinimize = value;
        } catch (_) {}
      },
    ),
  if (PlatformUtils.isMobile)
    NormalModel(
      title: '播放器音量',
      leading: const Icon(Icons.volume_up),
      getSubtitle: () => '当前:「${Pref.playerVolume.round()}%」',
      onTap: showPlayerVolumeDialog,
    )
  else
    NormalModel(
      title: '最高音量',
      leading: const Icon(Icons.volume_up),
      getSubtitle: () => '当前:「${(Pref.maxVolume * 100).round()}%」',
      onTap: showMaxVolumeDialog,
    ),
  if (kDebugMode || Platform.isAndroid)
    NormalModel(
      title: '音量均衡',
      leading: const Icon(Icons.multitrack_audio),
      getSubtitle: () {
        final audioNormalization = AudioNormalization.getTitleFromConfig(
          Pref.audioNormalization,
        );
        String fallback = Pref.fallbackNormalization;
        if (fallback == '0') {
          fallback = '';
        } else {
          fallback =
              '，无参数时:「${AudioNormalization.getTitleFromConfig(fallback)}」';
        }
        return '当前:「$audioNormalization」$fallback';
      },
      onTap: audioNormalization,
    ),
  if (kDebugMode || Platform.isAndroid)
    NormalModel(
      title: '音频输出设备',
      leading: const Icon(Icons.speaker_outlined),
      getSubtitle: () => '当前：${Pref.audioOutput}',
      onTap: showAudioOutputDialog,
    ),
];

class AudioSettingsPage extends StatelessWidget {
  const AudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = audioSettings;
    return SimpleScaffold(
      appBar: AppBar(title: const Text('音频与后台')),
      body: ListView.builder(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
        ),
        itemCount: settings.length,
        itemBuilder: (context, index) => settings[index].widget,
      ),
    );
  }
}
