import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/login.dart';
import 'package:PiliBro/http/video.dart';
import 'package:PiliBro/models/common/account_type.dart';
import 'package:PiliBro/models/common/rcmd_filter_scope.dart';
import 'package:PiliBro/models/common/rcmd_source.dart';
import 'package:PiliBro/pages/rcmd/controller.dart';
import 'package:PiliBro/pages/setting/models/model.dart';
import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/accounts/account.dart';
import 'package:PiliBro/utils/bili_device.dart';
import 'package:PiliBro/utils/recommend_filter.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

List<SettingsModel> get recommendSettings => [
  for (final source in RcmdSource.values) _sourceModel(source),
  NormalModel(
    title: '推荐权重（比值）',
    leading: const Icon(Icons.balance_outlined),
    getSubtitle: () {
      final sources = Pref.rcmdSources;
      return [
        for (final source in RcmdSource.values)
          if (sources & source.bit != 0)
            '${source.label} ${source.weightOf(sources)}',
      ].join(' · ');
    },
    onTap: (context, setState) {
      var sources = Pref.rcmdSources;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('推荐权重（输入数值比例）'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final source in RcmdSource.values)
                TextFormField(
                  initialValue: '${source.weightOf(sources)}',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(labelText: source.label),
                  onChanged: (value) => sources = source.withWeight(
                    sources,
                    (int.tryParse(value) ?? 1).clamp(1, 255),
                  ),
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
                RcmdController.saveSources(sources);
                setState();
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    },
  ),
  const NormalModel(
    title: '再次进行 OOBE',
    subtitle: '重新选择兴趣偏好（性别、年龄、喜欢的分区），选完带着结果重刷 App 推荐',
    leading: Icon(Icons.interests_outlined),
    onTap: _redoInterest,
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
  const SwitchModel(
    title: '向 B 站反馈推荐点击',
    subtitle: '从 App 推荐点开的视频，在打开和离开时按官方 App 的方式各报一次，附上它来自哪张推荐卡，让推荐更懂你的口味',
    leading: Icon(Icons.ads_click_outlined),
    setKey: SettingBoxKey.rcmdReportClick,
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
    onChanged: (value) {
      RecommendFilter.minLikeRatioForRecommend = value;
      RecommendFilter.compile();
    },
  ),
  getBanWordModel(
    title: '标题关键词过滤',
    key: SettingBoxKey.banWordForRecommend,
    onChanged: (value) {
      RecommendFilter.rcmdRegExp = value;
      RecommendFilter.enableFilter = value.pattern.isNotEmpty;
      RecommendFilter.compile();
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
    onChanged: (value) {
      RecommendFilter.minDurationForRcmd = value;
      RecommendFilter.compile();
    },
  ),
  getVideoFilterSelectModel(
    title: '播放量',
    key: SettingBoxKey.minPlayForRcmd,
    values: [0, 50, 100, 500, 1000],
    onChanged: (value) {
      RecommendFilter.minPlayForRcmd = value;
      RecommendFilter.compile();
    },
  ),
  SwitchModel(
    title: '已关注UP豁免推荐过滤',
    subtitle: '推荐中已关注用户发布的内容不会被过滤',
    leading: const Icon(Icons.favorite_border_outlined),
    setKey: SettingBoxKey.exemptFilterForFollowed,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.exemptFilterForFollowed = value,
  ),
  PopupModel<RcmdFilterScope>(
    title: '过滤器作用范围',
    leading: const Icon(Icons.explore_outlined),
    value: () => Pref.rcmdFilterScope,
    items: RcmdFilterScope.values,
    onSelected: (value, setState) => GStorage.setting
        .put(SettingBoxKey.rcmdFilterScope, value.index)
        .whenComplete(() {
          RecommendFilter.compile();
          setState();
        }),
  ),
  const NormalModel(
    title: '致谢',
    subtitle: '推荐请求的参数、翻页、身份与混合推荐参考了 bbspace、BiliPai、PiliNara、Pro 与 '
        'Bili.Copilot，谢谢这些项目。也感谢Sonnet4.6和Opus5.5的妙手',
    leading: Icon(Icons.favorite_outline),
  ),
];
NormalModel _sourceModel(RcmdSource source) => NormalModel(
  title: source.label,
  leading: Icon(switch (source) {
    RcmdSource.web => Icons.language,
    RcmdSource.phone => Icons.smartphone_outlined,
    RcmdSource.hd => Icons.tablet_android_outlined,
  }),
  getSubtitle: () {
    final account = Accounts.get(AccountType.recommend);
    if (account is! LoginAccount) return '未登录';
    final app = source.app;
    if (app == null || account.tokenOf(app) != null) return '已登录';
    return app == BiliApp.hd ? '勾选时用登录换取 token' : '无 token，以未登录身份取流';
  },
  getTrailing: (theme) => IgnorePointer(
    child: Checkbox(
      value: Pref.rcmdSources & source.bit != 0,
      onChanged: (_) {},
    ),
  ),
  onTap: (context, setState) async {
    final sources = Pref.rcmdSources;
    // 至少留一端
    if (sources & 7 == source.bit) return;
    if (source.app case final app? when sources & source.bit == 0) {
      if (VideoHttp.rcmdIdentity(app) == null) {
        if (Accounts.get(AccountType.recommend)
            case final LoginAccount account when app == BiliApp.hd) {
          SmartDialog.showLoading(msg: '正在换取 token');
          final res = await LoginHttp.cookieToHdToken(account);
          SmartDialog.dismiss();
          if (res case Error(:final errMsg)) SmartDialog.showToast('$errMsg');
        }
        if (VideoHttp.rcmdIdentity(app) == null) {
          SmartDialog.showToast('推荐将变得不个性化');
        }
      }
    }
    RcmdController.saveSources(sources ^ source.bit);
    setState();
  },
);

void _redoInterest(BuildContext context, VoidCallback setState) =>
    RcmdController.redoInterest();