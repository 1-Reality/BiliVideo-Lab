import 'package:PiliBro/http/video.dart';
import 'package:PiliBro/models/common/rcmd_source.dart';
import 'package:PiliBro/pages/rcmd/controller.dart';
import 'package:PiliBro/pages/setting/models/model.dart';
import 'package:PiliBro/utils/recommend_filter.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

List<SettingsModel> get recommendSettings => [
  PopupModel<RcmdSource>(
    title: '首页推荐来源',
    leading: const Icon(Icons.model_training_outlined),
    value: () => Pref.rcmdSource,
    items: RcmdSource.values,
    onSelected: (value, setState) {
      SmartDialog.showToast('重启生效');
      GStorage.setting
          .put(SettingBoxKey.rcmdSource, value.index)
          .whenComplete(setState);
    },
  ),
  const SwitchModel(
    title: 'App 推荐使用平板身份',
    subtitle: '以 HD 平板客户端取流，与手机版是两套推荐。扫码登录拿到的正是平板 token，'
        '短信、密码登录拿到的是手机 token；身份与 token 不对口时以未登录身份取流',
    leading: Icon(Icons.tablet_android_outlined),
    setKey: SettingBoxKey.rcmdTablet,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '个性化推荐',
    subtitle: '关闭后 App 推荐不再按观看记录与兴趣推荐',
    leading: Icon(Icons.person_search_outlined),
    setKey: SettingBoxKey.rcmdPersonalized,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '匿名取推荐',
    subtitle: '推荐请求不带登录身份，看一看没有观看记录时的推荐；其他功能不受影响',
    leading: Icon(Icons.visibility_off_outlined),
    setKey: SettingBoxKey.rcmdAnonymous,
    defaultVal: false,
  ),
  getVideoFilterSelectModel(
    title: 'Web 推荐每批条数',
    key: SettingBoxKey.webRcmdPs,
    values: [10, 12, 20, 30],
    defaultValue: 20,
    isFilter: false,
  ),
  getVideoFilterSelectModel(
    title: 'Web 推荐相关度',
    key: SettingBoxKey.webRcmdFreshType,
    values: [1, 2, 3, 4],
    defaultValue: 4,
    isFilter: false,
  ),
  SwitchModel(
    title: '保留首页推荐刷新',
    subtitle: '下拉刷新时保留上次内容',
    leading: const Icon(Icons.refresh),
    setKey: SettingBoxKey.enableSaveLastData,
    defaultVal: true,
    onChanged: (value) {
      try {
        Get.find<RcmdController>()
          ..enableSaveLastData = value
          ..lastRefreshAt = null;
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    },
  ),
  SwitchModel(
    title: '显示上次看到位置提示',
    subtitle: '保留上次推荐时，在上次刷新位置显示提示',
    leading: const Icon(Icons.tips_and_updates_outlined),
    setKey: SettingBoxKey.savedRcmdTip,
    defaultVal: true,
    onChanged: (value) {
      try {
        Get.find<RcmdController>()
          ..savedRcmdTip = value
          ..lastRefreshAt = null;
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    },
  ),
  getVideoFilterSelectModel(
    title: '点赞率',
    suffix: '%',
    key: SettingBoxKey.minLikeRatioForRecommend,
    values: [0, 1, 2, 3, 4],
    onChanged: (value) => RecommendFilter.minLikeRatioForRecommend = value,
  ),
  getBanWordModel(
    title: '标题关键词过滤',
    key: SettingBoxKey.banWordForRecommend,
    onChanged: (value) {
      RecommendFilter.rcmdRegExp = value;
      RecommendFilter.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  getBanWordModel(
    title: 'App推荐/热门/排行榜: 视频分区关键词过滤',
    key: SettingBoxKey.banWordForZone,
    onChanged: (value) {
      VideoHttp.zoneRegExp = value;
      VideoHttp.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  getVideoFilterSelectModel(
    title: '视频时长',
    suffix: 's',
    key: SettingBoxKey.minDurationForRcmd,
    values: [0, 30, 60, 90, 120],
    onChanged: (value) => RecommendFilter.minDurationForRcmd = value,
  ),
  getVideoFilterSelectModel(
    title: '播放量',
    key: SettingBoxKey.minPlayForRcmd,
    values: [0, 50, 100, 500, 1000],
    onChanged: (value) => RecommendFilter.minPlayForRcmd = value,
  ),
  SwitchModel(
    title: '已关注UP豁免推荐过滤',
    subtitle: '推荐中已关注用户发布的内容不会被过滤',
    leading: const Icon(Icons.favorite_border_outlined),
    setKey: SettingBoxKey.exemptFilterForFollowed,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.exemptFilterForFollowed = value,
  ),
  SwitchModel(
    title: '过滤器也应用于详情页相关视频',
    subtitle: '其它（如热门视频、搜索等）均不受过滤器影响，无法豁免相关视频中的已关注UP',
    leading: const Icon(Icons.explore_outlined),
    setKey: SettingBoxKey.applyFilterToRelatedVideos,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.applyFilterToRelatedVideos = value,
  ),
  const NormalModel(
    title: '致谢',
    subtitle: '推荐请求的参数、翻页、身份与混合推荐参考了 bbspace、BiliPai、PiliNara 与 '
        'Bili.Copilot，谢谢这些项目',
    leading: Icon(Icons.favorite_outline),
  ),
];