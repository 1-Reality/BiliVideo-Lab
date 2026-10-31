import 'dart:io' show Platform;

import 'package:PiliBro/common/widgets/custom_icon.dart';
import 'package:PiliBro/common/widgets/image_grid/image_grid_view.dart';
import 'package:PiliBro/models/common/audio_normalization.dart';
import 'package:PiliBro/models/common/super_chat_type.dart';
import 'package:PiliBro/models/common/super_resolution_type.dart';
import 'package:PiliBro/models/common/video/subtitle_pref_type.dart';
import 'package:PiliBro/pages/setting/models/model.dart';
import 'package:PiliBro/pages/setting/pages/fullscreen_sc.dart';
import 'package:PiliBro/pages/setting/widgets/dual_slider_dialog.dart';
import 'package:PiliBro/pages/setting/widgets/multi_select_dialog.dart';
import 'package:PiliBro/pages/setting/widgets/select_dialog.dart';
import 'package:PiliBro/pages/setting/widgets/slider_dialog.dart';
import 'package:PiliBro/plugin/pl_player/models/auto_fullscreen_mode.dart';
import 'package:PiliBro/plugin/pl_player/models/bottom_progress_behavior.dart';
import 'package:PiliBro/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliBro/utils/extension/num_ext.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

List<SettingsModel> get playSettings => [
  NormalModel(
    onTap: (context, setState) => Get.toNamed('/playSpeedSet'),
    leading: const Icon(Icons.speed_outlined),
    title: '倍速设置',
    subtitle: '设置视频播放速度，高熵信息生活，节约时间就是延长生命！',
  ),
  NormalModel(
    onTap: (context, setState) => Get.toNamed('/gestureSettings'),
    leading: const Icon(Icons.swipe_outlined),
    title: '手势',
    subtitle: '上下、左右滑动的分区与动作：亮度、音量、倍速、进度、全屏',
  ),
  NormalModel(
    onTap: (context, setState) => Get.toNamed('/orientationSettings'),
    leading: const Icon(Icons.screen_rotation_outlined),
    title: '方向（横竖屏）设置',
    subtitle: '应用方向、全屏方向与方向感应',
  ),
  SplitModel(
    normalModel: const NormalModel.split(
      title: '音视频快捷切换 · 音频与后台',
      subtitle: '开关：底部播放条；点击：听视频模式、后台播放、画中画、音频服务、音量均衡等',
      leading: Icon(Icons.headphones_outlined),
    ),
    switchModel: SwitchModel.split(
      setKey: SettingBoxKey.showAudioMiniPlayer,
      defaultVal: true,
      needReboot: true,
      onTap: (context) => Get.toNamed('/audioSettings'),
    ),
  ),
  NormalModel(
    title: '超分辨率',
    leading: const Icon(Icons.stay_current_landscape_outlined),
    getSubtitle: () =>
        '当前:「${Pref.superResolutionType.label}」\n默认设置对番剧生效, 其他视频默认关闭\n超分辨率需要启用硬件解码, 若启用硬件解码后仍然不生效, 尝试切换硬件解码器为 copy系',
    onTap: _showSuperResolutionDialog,
  ),
  const SwitchModel(
    title: '自动播放',
    subtitle: '进入详情页自动播放',
    leading: Icon(Icons.motion_photos_auto_outlined),
    setKey: SettingBoxKey.autoPlayEnable,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '评论区进入不自动播放',
    subtitle: '从评论区上下文查看视频详情页时，不自动播放：治好完播强迫症',
    leading: Icon(Icons.comment_outlined),
    setKey: SettingBoxKey.replyNoAutoPlay,
    defaultVal: false,
  ),
  NormalModel(
    title: '顶栏按钮',
    leading: const Icon(Icons.view_week_outlined),
    getSubtitle: () =>
        '播放器顶部太挤（窄屏、曲面屏）时，勾掉用不到的。当前显示 '
        '${_headerButtons.keys.where((k) => GStorage.setting.get(k, defaultValue: true) as bool).length}/${_headerButtons.length} 个',
    onTap: _showHeaderButtonsDialog,
  ),
  const SwitchModel(
    title: '全屏显示锁定按钮',
    leading: Icon(Icons.lock_outline),
    setKey: SettingBoxKey.showFsLockBtn,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '全屏显示截图按钮',
    leading: Icon(Icons.photo_camera_outlined),
    setKey: SettingBoxKey.showFsScreenshotBtn,
    defaultVal: true,
  ),
  SwitchModel(
    title: '全屏显示电池电量',
    leading: const Icon(Icons.battery_3_bar),
    setKey: SettingBoxKey.showBatteryLevel,
    defaultVal: PlatformUtils.isMobile,
  ),
  const SwitchModel(
    title: '双击快退/快进',
    subtitle: '左侧双击快退/右侧双击快进，关闭则双击均为暂停/播放',
    leading: Icon(Icons.touch_app_outlined),
    setKey: SettingBoxKey.enableQuickDouble,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '滚轮调节音量',
    leading: Icon(Icons.mouse_outlined),
    setKey: SettingBoxKey.enableScrollVolume,
    defaultVal: true,
  ),
  if (Platform.isAndroid)
    const SwitchModel(
      title: '调节系统亮度',
      leading: Icon(Icons.brightness_6_outlined),
      setKey: SettingBoxKey.setSystemBrightness,
      defaultVal: false,
    ),
  const SwitchModel(
    title: '提前初始化播放器',
    subtitle: '相对减少手动播放加载时间',
    leading: Icon(Icons.play_circle_outlined),
    setKey: SettingBoxKey.preInitPlayer,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '滑动跳转预览视频缩略图',
    leading: Icon(Icons.preview_outlined),
    setKey: SettingBoxKey.showSeekPreview,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '显示高能进度条',
    subtitle: '高能进度条反应了在时域上，单位时间内弹幕发送量的变化趋势',
    leading: Icon(Icons.show_chart),
    setKey: SettingBoxKey.showDmChart,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '启用双指缩小视频',
    leading: Icon(Icons.pinch),
    setKey: SettingBoxKey.enableShrinkVideoSize,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '启用拖拽字幕调整底部边距',
    leading: Icon(MdiIcons.dragVariant),
    setKey: SettingBoxKey.enableDragSubtitle,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '视频页显示相关视频',
    leading: Icon(MdiIcons.motionPlayOutline),
    setKey: SettingBoxKey.showRelatedVideo,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '默认展开视频简介',
    leading: Icon(Icons.expand_more),
    setKey: SettingBoxKey.alwaysExpandIntroPanel,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '横屏自动展开视频简介',
    leading: Icon(Icons.expand_more),
    setKey: SettingBoxKey.expandIntroPanelH,
    defaultVal: true,
  ),
  SwitchModel(
    title: '横屏分P|合集列表显示在Tab栏',
    leading: const Icon(Icons.format_list_numbered_rtl_sharp),
    setKey: SettingBoxKey.horizontalSeasonPanel,
    defaultVal: Pref.horizontalScreen,
  ),
  SwitchModel(
    title: '横屏播放页在侧栏打开UP主页',
    leading: const Icon(Icons.account_circle_outlined),
    setKey: SettingBoxKey.horizontalMemberPage,
    defaultVal: Pref.horizontalScreen,
  ),
  SwitchModel(
    title: '横屏在侧栏打开图片预览',
    leading: const Icon(Icons.photo_outlined),
    setKey: SettingBoxKey.horizontalPreview,
    defaultVal: false,
    onChanged: (value) => ImageGridView.horizontalPreview = value,
  ),
  const SwitchModel(
    title: '显示视频警告争议信息',
    leading: Icon(Icons.warning_amber_rounded),
    setKey: SettingBoxKey.showArgueMsg,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '显示视频分段信息',
    leading: Icon(CustomIcons.view_headline_rotate_90),
    setKey: SettingBoxKey.showViewPoints,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '显示继续播放分P提示',
    leading: Icon(Icons.local_parking),
    setKey: SettingBoxKey.continuePlayingPart,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '分P/合集：倒序播放从首集开始播放',
    subtitle: '开启则自动切换为倒序首集，否则保持当前集',
    leading: Icon(MdiIcons.sort),
    setKey: SettingBoxKey.reverseFromFirst,
    defaultVal: true,
  ),
  getVideoFilterSelectModel(
    title: '双击快进/快退时长',
    suffix: 's',
    key: SettingBoxKey.fastForBackwardDuration,
    values: [5, 10, 15],
    defaultValue: 10,
    isFilter: false,
  ),
  const SwitchModel(
    title: '滑动快进/快退使用相对时长',
    leading: Icon(Icons.swap_horiz_outlined),
    setKey: SettingBoxKey.useRelativeSlide,
    defaultVal: false,
  ),
  getVideoFilterSelectModel(
    title: '滑动快进/快退时长',
    subtitle: '从播放器一端滑到另一端的快进/快退时长',
    suffix: Pref.useRelativeSlide ? '%' : 's',
    key: SettingBoxKey.sliderDuration,
    values: [25, 50, 90, 100],
    defaultValue: 90,
    isFilter: false,
  ),
  NormalModel(
    title: '自动启用字幕',
    leading: const Icon(Icons.closed_caption_outlined),
    getSubtitle: () => '当前选择偏好：${Pref.subtitlePreference.desc}',
    onTap: _showSubtitleDialog,
  ),
  NormalModel(
    title: 'AI 字幕粉丝数经验限值',
    leading: const Icon(Icons.people_outline),
    getSubtitle: () => Pref.subtitleFollowerThreshold == 0
        ? '当前关闭；仅用于“静音时自动启用”偏好'
        : 'UP 主粉丝少于 ${Pref.subtitleFollowerThreshold} 时，非静音也启用 AI 字幕',
    onTap: _showSubtitleFollowerThresholdDialog,
  ),
  const SwitchModel(
    title: '启用键盘控制',
    leading: Icon(Icons.keyboard_alt_outlined),
    setKey: SettingBoxKey.keyboardControl,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '播放器确认键进入全屏',
    subtitle: '关闭时为播放/暂停；用于方向键或遥控器焦点操作',
    leading: Icon(Icons.keyboard_return),
    setKey: SettingBoxKey.playerConfirmFullscreen,
    defaultVal: false,
  ),
  NormalModel(
    title: 'SuperChat (醒目留言) 显示类型',
    leading: const Icon(Icons.live_tv),
    getSubtitle: () => '当前:「${Pref.superChatType.label}」',
    onTap: _showSuperChatDialog,
  ),
  NormalModel(
    title: '全屏 SuperChat 设置',
    subtitle: '全屏 SuperChat (醒目留言) 大小、不透明度、缩放设置',
    leading: const Icon(Icons.open_in_full),
    onTap: (_, _) => Get.to(const FullScreenSc()),
  ),
  const SwitchModel(
    title: '竖屏扩大展示',
    subtitle: '小屏竖屏视频宽高比由16:9扩大至1:1（不支持收起）；横屏适配时，扩大至9:16',
    leading: Icon(Icons.expand_outlined),
    setKey: SettingBoxKey.enableVerticalExpand,
    defaultVal: false,
  ),
  PopupModel(
    title: '自动全屏',
    leading: const Icon(Icons.fullscreen_outlined),
    value: () => Pref.autoFullscreenMode,
    items: AutoFullscreenMode.values,
    onSelected: (value, setState) => GStorage.setting
        .put(SettingBoxKey.autoFullscreenMode, value.index)
        .whenComplete(setState),
  ),
  PopupModel(
    title: '推荐视频自动全屏',
    leading: const Icon(Icons.fullscreen_outlined),
    value: () => Pref.relatedAutoFullscreenMode,
    items: AutoFullscreenMode.values,
    onSelected: (value, setState) => GStorage.setting
        .put(SettingBoxKey.relatedAutoFullscreenMode, value.index)
        .whenComplete(setState),
  ),
  const SwitchModel(
    title: '退回上一个推荐视频时还原播放状态',
    subtitle: '离开时在播就接着播、暂停就停着；关闭则按自动播放开关',
    leading: Icon(Icons.undo_outlined),
    setKey: SettingBoxKey.relatedBackRestore,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '自动退出全屏',
    subtitle: '视频结束播放时退出全屏',
    leading: Icon(Icons.fullscreen_exit_outlined),
    setKey: SettingBoxKey.enableAutoExit,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '延长播放控件显示时间',
    subtitle: '开启后延长至30秒，便于屏幕阅读器滑动切换控件焦点',
    leading: Icon(Icons.timer_outlined),
    setKey: SettingBoxKey.enableLongShowControl,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '全屏展示点赞/投币/收藏等操作按钮',
    leading: Icon(MdiIcons.dotsHorizontalCircleOutline),
    setKey: SettingBoxKey.showFSActionItem,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '观看人数',
    subtitle: '展示同时在看人数',
    leading: Icon(Icons.people_outlined),
    setKey: SettingBoxKey.enableOnlineTotal,
    defaultVal: true,
  ),
  NormalModel(
    title: '底部进度条展示',
    leading: const Icon(Icons.border_bottom_outlined),
    getSubtitle: () => '当前展示方式：${Pref.btmProgressBehavior.label}',
    onTap: _showProgressBehaviorDialog,
  ),
  const SwitchModel(
    title: '进度条固定在底部（非全屏）',
    subtitle: '关闭后随控制栏上移',
    leading: Icon(Icons.vertical_align_bottom),
    setKey: SettingBoxKey.fixedBottomProgress,
    defaultVal: true,
    needReboot: true,
  ),
  const SwitchModel(
    title: '进度条固定在底部（全屏）',
    subtitle: '关闭后随控制栏上移',
    leading: Icon(Icons.vertical_align_bottom),
    setKey: SettingBoxKey.fixedBottomProgressFs,
    defaultVal: false,
    needReboot: true,
  ),
  NormalModel(
    title: '播放器左右留白（dp）',
    leading: const Icon(Icons.space_bar_outlined),
    getSubtitle: () =>
        '进度条${Pref.progressBarSideSpace}dp 按钮${Pref.bottomControlSideSpace}dp',
    onTap: _showPlayerSpaceDialog,
  ),
  PopupModel(
    title: '播放顺序',
    leading: const Icon(Icons.repeat),
    value: () => Pref.playRepeat,
    items: PlayRepeat.values,
    onSelected: (value, setState) => GStorage.video
        .put(VideoBoxKey.playRepeat, value.index)
        .whenComplete(setState),
  ),
  const SwitchModel(
    title: '播放器设置仅对当前生效',
    subtitle: '弹幕、字幕及部分设置中没有的设置除外',
    leading: Icon(Icons.video_settings_outlined),
    setKey: SettingBoxKey.tempPlayerConf,
    defaultVal: true,
  ),
];

Future<void> _showSubtitleDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<SubtitlePrefType>(
    context: context,
    builder: (context) => SelectDialog<SubtitlePrefType>(
      title: '字幕选择偏好',
      value: Pref.subtitlePreference,
      values: SubtitlePrefType.values.map((e) => (e, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.subtitlePreference,
      res.index,
    );
    setState();
  }
}

Future<void> _showSubtitleFollowerThresholdDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  var value = Pref.subtitleFollowerThreshold.toString();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('AI 字幕粉丝数粗判阈值'),
      content: TextFormField(
        autofocus: true,
        initialValue: value,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          suffixText: '粉丝',
          helperText: '设置为 0 关闭',
        ),
        onChanged: (text) => value = text,
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('取消')),
        TextButton(
          onPressed: () async {
            final threshold = int.tryParse(value);
            if (threshold == null) {
              SmartDialog.showToast('输入域无效');
              return;
            }
            Get.back();
            await GStorage.setting.put(
              SettingBoxKey.subtitleFollowerThreshold,
              threshold,
            );
            setState();
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

Future<void> _showSuperChatDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<SuperChatType>(
    context: context,
    builder: (context) => SelectDialog<SuperChatType>(
      title: 'SuperChat (醒目留言) 显示类型',
      value: Pref.superChatType,
      values: SuperChatType.values.map((e) => (e, e.label)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.superChatType, res.index);
    setState();
  }
}

Future<void> _showPlayerSpaceDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<(double, double)>(
    context: context,
    builder: (context) => DualSliderDialog(
      title: const Text('播放器左右留白'),
      value1: Pref.progressBarSideSpace,
      value2: Pref.bottomControlSideSpace,
      description1: const Text('进度条左右边距（默认20dp）'),
      description2: const Text('底部按钮左右边距（默认10dp）'),
      min: 0,
      max: 24,
      divisions: 24,
      suffix: 'dp',
      precise: 0,
      enableInput: true,
    ),
  );
  if (res != null) {
    await GStorage.setting.putAll({
      SettingBoxKey.progressBarSideSpace: res.$1,
      SettingBoxKey.bottomControlSideSpace: res.$2,
    });
    SmartDialog.showToast('重启生效');
    setState();
  }
}

Future<void> _showProgressBehaviorDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<BtmProgressBehavior>(
    context: context,
    builder: (context) => SelectDialog<BtmProgressBehavior>(
      title: '底部进度条展示',
      value: Pref.btmProgressBehavior,
      values: BtmProgressBehavior.values.map((e) => (e, e.label)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.btmProgressBehavior,
      res.index,
    );
    setState();
  }
}

Future<void> showPlayerVolumeDialog(
  BuildContext context,
  VoidCallback setState, {
  ValueChanged<double>? onChanged,
}) {
  return showVolumeDialog(
    context,
    title: const Text('播放器音量'),
    value: Pref.playerVolume,
    onChanged: (value) => GStorage.setting
        .put(SettingBoxKey.playerVolume, value)
        .whenComplete(() {
          setState();
          onChanged?.call(value);
        }),
  );
}

Future<void> showMaxVolumeDialog(
  BuildContext context,
  VoidCallback setState,
) {
  return showVolumeDialog(
    context,
    title: const Text('最高音量'),
    value: Pref.maxVolume * 100,
    onChanged: (rawValue) {
      final maxVolume = (rawValue * 0.01).toPrecision(2);
      if (Pref.desktopVolume > maxVolume) {
        GStorage.setting.put(SettingBoxKey.desktopVolume, maxVolume);
      }
      GStorage.setting
          .put(SettingBoxKey.maxVolume, maxVolume)
          .whenComplete(setState);
    },
  );
}

const kMinVolume = 100.0;
const kMaxVolume = 300.0;

Future<void> showVolumeDialog(
  BuildContext context, {
  required Widget title,
  required double value,
  required ValueChanged<double> onChanged,
}) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: title,
      min: kMinVolume,
      max: kMaxVolume,
      divisions: 40,
      precise: 0,
      value: value,
      suffix: '%',
    ),
  );
  if (res != null) {
    onChanged(res);
  }
}

Future<void> _showSuperResolutionDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<SuperResolutionType>(
    context: context,
    builder: (context) => SelectDialog<SuperResolutionType>(
      title: '超分辨率',
      value: Pref.superResolutionType,
      values: SuperResolutionType.values.map((e) => (e, e.label)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.superResolutionType,
      res.index,
    );
    setState();
  }
}

Future<void> audioNormalization(
  BuildContext context,
  VoidCallback setState, {
  bool fallback = false,
}) async {
  final key = fallback
      ? SettingBoxKey.fallbackNormalization
      : SettingBoxKey.audioNormalization;
  final res = await showDialog<String>(
    context: context,
    builder: (context) {
      String audioNormalization = fallback
          ? Pref.fallbackNormalization
          : Pref.audioNormalization;
      Set<String> values = {
        '0',
        '1',
        if (!fallback) '2',
        audioNormalization,
        '3',
      };
      return SelectDialog<String>(
        title: fallback ? '服务器无loudnorm配置时使用' : '音量均衡',
        value: audioNormalization,
        values: values
            .map(
              (e) => (
                e,
                switch (e) {
                  '0' => AudioNormalization.disable.title,
                  '1' => AudioNormalization.dynaudnorm.title,
                  '2' => AudioNormalization.loudnorm.title,
                  '3' => AudioNormalization.custom.title,
                  _ => e,
                },
              ),
            )
            .toList(),
      );
    },
  );
  if (res != null && context.mounted) {
    if (res == '3') {
      String param = '';
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('自定义参数'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              const Text('等同于 --af=lavfi=[参数]，接在倍速音调补偿之后'),
              TextField(
                autofocus: true,
                onChanged: (value) => param = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text(
                '取消',
                style: TextStyle(color: ColorScheme.of(context).outline),
              ),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                GStorage.setting.put(key, param);
                if (!fallback &&
                    AudioNormalization.loudnormRegExp.hasMatch(param)) {
                  audioNormalization(context, setState, fallback: true);
                }
                setState();
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } else {
      GStorage.setting.put(key, res);
      if (res == '2') {
        audioNormalization(context, setState, fallback: true);
      }
      setState();
    }
  }
}

const _headerButtons = {
  SettingBoxKey.headerBtnHome: '返回主页',
  SettingBoxKey.headerBtnMiniWindow: '应用内小窗',
  SettingBoxKey.headerBtnListen: '听音频',
  SettingBoxKey.headerBtnCast: '投屏',
  SettingBoxKey.headerBtnSponsor: '空降助手',
  SettingBoxKey.headerBtnDmSettings: '弹幕设置',
  SettingBoxKey.headerBtnPip: '画中画',
};

Future<void> _showHeaderButtonsDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<Set<String>>(
    context: context,
    builder: (context) => MultiSelectDialog<String>(
      title: '顶栏显示哪些按钮',
      initValues: _headerButtons.keys.where(
        (k) => GStorage.setting.get(k, defaultValue: true) as bool,
      ),
      values: _headerButtons,
    ),
  );
  if (res == null) return;
  await GStorage.setting.putAll({
    for (final k in _headerButtons.keys) k: res.contains(k),
  });
  setState();
}
