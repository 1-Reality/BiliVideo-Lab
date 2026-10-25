import 'dart:io' show Platform;

import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/models/common/focus_reaction.dart';
import 'package:PiliBro/pages/setting/models/model.dart';
import 'package:PiliBro/pages/setting/widgets/duck_volume_dialog.dart';
import 'package:PiliBro/services/service_locator.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

/// 后台播放与声音：每一项对应底层的一处判断。常用里是视频和听视频共用的
/// 音频焦点与耳机，视频和听视频的前后台各管各的。锁屏与焦点只在安卓上分得出来
class BackgroundSettingsPage extends StatelessWidget {
  const BackgroundSettingsPage({super.key});

  static List<SettingsModel> get _common => [
    SwitchModel(
      title: '后台音频服务',
      subtitle: '通知栏和锁屏上显示播放控件，画中画里也能暂停和播放',
      leading: const Icon(Icons.volume_up_outlined),
      setKey: SettingBoxKey.enableBackgroundPlay,
      defaultVal: true,
      onChanged: (value) =>
          videoPlayerServiceHandler!.enableBackgroundPlay = value,
    ),
    if (Platform.isAndroid) ...[
      const SwitchModel(
        title: '开始播放时打断其他 App',
        subtitle:
            '开：申请音频焦点，正在出声的其他 App 会停下，之后它们再出声时按下面两项处理；'
            '来电和语音助手总是暂停，结束后恢复。关：不申请焦点，和其他 App 一起响，下面两项不起作用',
        leading: Icon(Icons.campaign_outlined),
        setKey: SettingBoxKey.focusTakeover,
        defaultVal: true,
      ),
      PopupModel<FocusReaction>(
        title: '其他 App 短暂发声时（导航、提示音）',
        leading: const Icon(Icons.notifications_active_outlined),
        value: () => Pref.focusOnDuck,
        items: FocusReaction.values,
        onSelected: (value, setState) => GStorage.setting
            .put(SettingBoxKey.focusOnDuck, value.index)
            .whenComplete(setState),
      ),
      PopupModel<FocusReaction>(
        title: '其他 App 开始长期播放时',
        leading: const Icon(Icons.queue_music_outlined),
        value: () => Pref.focusOnLoss,
        items: FocusReaction.values,
        onSelected: (value, setState) => GStorage.setting
            .put(SettingBoxKey.focusOnLoss, value.index)
            .whenComplete(setState),
      ),
      NormalModel(
        title: '压低到',
        leading: const Icon(Icons.volume_down_outlined),
        getSubtitle: () =>
            '原音量的 ${Pref.duckPercent}%；长期播放选了压低时，保持到你下次按播放',
        onTap: _setDuckPercent,
      ),
      const SwitchModel(
        title: '拔出耳机时暂停',
        subtitle: '有线耳机拔出、蓝牙耳机断开时暂停，免得声音突然从外放出来',
        leading: Icon(Icons.headset_off_outlined),
        setKey: SettingBoxKey.pauseOnNoisy,
        defaultVal: true,
      ),
    ],
  ];

  static List<SettingsModel> get _video => [
    const SwitchModel(
      title: '后台播放',
      subtitle: '回到桌面或切到其他 App 时继续播放；播放器菜单里的同名开关改的也是它',
      leading: Icon(Icons.motion_photos_pause_outlined),
      setKey: SettingBoxKey.continuePlayInBackground,
    ),
    if (Platform.isAndroid)
      SwitchModel(
        title: '锁屏播放',
        subtitle: '锁屏时继续播放；没单独设过时跟随后台播放',
        leading: const Icon(Icons.screen_lock_portrait_outlined),
        setKey: SettingBoxKey.lockPlayVideo,
        defaultVal: Pref.continuePlayInBackground,
      ),
    const SwitchModel(
      title: '仅播放音频时退出转为听视频',
      subtitle: '视频页开着「仅播放音频」时退出，声音不停，交给听视频接着放',
      leading: Icon(Icons.headphones_outlined),
      setKey: SettingBoxKey.listenContinueOnExit,
      defaultVal: true,
    ),
  ];

  static List<SettingsModel> get _listen => [
    const SwitchModel(
      title: '后台播放',
      subtitle: '回到桌面或切到其他 App 时继续播放',
      leading: Icon(Icons.motion_photos_pause_outlined),
      setKey: SettingBoxKey.audioBackgroundPlay,
      defaultVal: true,
    ),
    if (Platform.isAndroid)
      const SwitchModel(
        title: '锁屏播放',
        subtitle: '锁屏时继续播放',
        leading: Icon(Icons.screen_lock_portrait_outlined),
        setKey: SettingBoxKey.audioLockPlay,
        defaultVal: true,
      ),
    const SwitchModel(
      title: '离开听视频页后继续播放',
      subtitle: '返回首页或其他页面时声音不停，底部播放条可以点回来；关掉则离开即停',
      leading: Icon(Icons.exit_to_app_outlined),
      setKey: SettingBoxKey.audioContinueOnLeave,
      defaultVal: true,
    ),
  ];

  static Future<void> _setDuckPercent(
    BuildContext context,
    VoidCallback setState,
  ) async {
    final result = await showDuckVolumeDialog(context, Pref.duckPercent);
    if (result == null) return;
    await GStorage.setting.put(SettingBoxKey.duckPercent, result);
    setState();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    Widget list(List<SettingsModel> items) => ListView.builder(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index].widget,
    );
    return DefaultTabController(
      length: 3,
      child: SimpleScaffold(
        appBar: AppBar(
          title: const Text('后台播放与声音'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TabBar(
                dividerHeight: 0,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
                labelColor: colorScheme.onSecondaryContainer,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                splashBorderRadius: const BorderRadius.all(Radius.circular(20)),
                tabs: const [
                  Tab(height: 36, text: '常用'),
                  Tab(height: 36, text: '视频'),
                  Tab(height: 36, text: '听视频'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [list(_common), list(_video), list(_listen)],
        ),
      ),
    );
  }
}