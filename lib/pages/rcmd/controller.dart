import 'dart:collection';

import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/video.dart';
import 'package:PiliBro/models/common/rcmd_source.dart';
import 'package:PiliBro/models/home/rcmd/result.dart';
import 'package:PiliBro/models/model_rec_video_item.dart';
import 'package:PiliBro/pages/common/common_list_controller.dart';
import 'package:PiliBro/pages/rcmd/interest_choose.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// 混合推荐里的一端：缓冲区不足一批时才再请求
class _Feed {
  _Feed(RcmdSource source, this.weight)
    : cursor = source.app == null ? null : RcmdAppCursor(source.app!);

  final int weight;

  /// App 端的翻页游标，Web 端为空
  final RcmdAppCursor? cursor;
  final buffer = Queue<BaseRcmdVideoItemModel>();

  /// 平滑加权轮转的当前值
  int current = 0;

  /// 本轮刷新后请求过几次，Web 端当作 fresh_idx
  int fetched = 0;
}

class RcmdController extends CommonListController {
  late bool enableSaveLastData = Pref.enableSaveLastData;
  late List<_Feed> _feeds = _parse(Pref.rcmdSources);

  // 混合推荐每批条数与跨页去重
  static const _batch = 20;
  final _seen = <int>{};

  int? lastRefreshAt;
  late bool savedRcmdTip = Pref.savedRcmdTip;

  @override
  bool get isEnd => false;

  @override
  void onInit() {
    super.onInit();
    page = 0;
    queryData();
  }

  static List<_Feed> _parse(int sources) => [
    for (final source in RcmdSource.values)
      if (sources & source.bit != 0) _Feed(source, source.weightOf(sources)),
  ];

  /// 改推荐来源：存下，首页已打开就按新来源重刷
  static void saveSources(int sources) {
    GStorage.setting.put(SettingBoxKey.rcmdSources, sources);
    if (Get.isRegistered<RcmdController>()) {
      Get.find<RcmdController>()
        .._feeds = _parse(sources)
        ..onRefresh();
    }
  }

  Future<LoadingState<List<BaseRcmdVideoItemModel>>> _fetch(
    _Feed feed,
    int n,
  ) async {
    final cursor = feed.cursor;
    if (cursor == null) return VideoHttp.rcmdVideoList(freshIdx: n);
    final res = await VideoHttp.rcmdVideoListApp(
      cursor,
      refresh: n == 0,
      keepOld: enableSaveLastData,
    );
    if (cursor.interestChoose case final choose?) {
      cursor.interestChoose = null;
      // 留一份，设置里「再次进行 OOBE」时直接拿来弹
      GStorage.localCache.put(LocalCacheKey.rcmdInterestChoose, choose);
      _askInterest(cursor, choose);
    }
    return res;
  }

  void _askInterest(RcmdAppCursor cursor, Map<String, dynamic> choose) {
    if (Get.context case final context?) {
      showInterestChoose(context, choose).then((interest) {
        if (interest == null) return;
        GStorage.setting.put(SettingBoxKey.rcmdInterestDone, true);
        // 跳过时返回空表
        if (interest.isEmpty) return;
        cursor.interest = interest;
        onRefresh();
      });
    }
  }

  /// 重新选择兴趣：以新设备、未登录的身份请求一次推荐，拿新用户才有的兴趣选择
  /// 当场弹，选完带着结果用自己的身份重刷 App 推荐；拿不到就用存过的那份。
  /// 已完成标记先清掉，之后服务端再下发时还会再问
  static Future<void> redoInterest() async {
    GStorage.setting.put(SettingBoxKey.rcmdInterestDone, false);
    final controller = Get.isRegistered<RcmdController>()
        ? Get.find<RcmdController>()
        : null;
    final cursor = controller?._feeds
        .map((feed) => feed.cursor)
        .nonNulls
        .firstOrNull;
    if (controller == null || cursor == null) {
      SmartDialog.showToast(
        controller == null
            ? '已重置，下次 App 推荐下发兴趣选择时会弹出'
            : '兴趣偏好只对 App 推荐生效，请先勾选手机或平板推荐',
      );
      return;
    }
    SmartDialog.showLoading(msg: '获取兴趣选择');
    final probe = RcmdAppCursor(cursor.app);
    await VideoHttp.rcmdVideoListApp(
      probe,
      refresh: true,
      keepOld: false,
      newDevice: true,
    );
    SmartDialog.dismiss();
    final choose =
        probe.interestChoose ??
        GStorage.localCache.get(LocalCacheKey.rcmdInterestChoose);
    if (choose is! Map) {
      SmartDialog.showToast('没拿到兴趣选择，已重置，下次 App 推荐下发时会弹出');
      return;
    }
    if (probe.interestChoose != null) {
      GStorage.localCache.put(LocalCacheKey.rcmdInterestChoose, choose);
    }
    controller._askInterest(cursor, Map<String, dynamic>.from(choose));
  }

  @override
  Future<LoadingState> customGetData() async {
    if (_feeds.length == 1) return _fetch(_feeds.first, page);
    if (page == 0) {
      _seen.clear();
      for (final feed in _feeds) {
        feed
          ..buffer.clear()
          ..current = 0
          ..fetched = 0;
      }
    }
    // 缓冲不足一批的端才请求；一端失败就只用其余几端
    final hungry = [
      for (final feed in _feeds)
        if (feed.buffer.length < _batch) feed,
    ];
    final results = await Future.wait([
      for (final feed in hungry) _fetch(feed, feed.fetched),
    ]);
    LoadingState? error;
    for (var i = 0; i < hungry.length; i++) {
      if (results[i] case Success(:final response)) {
        hungry[i]
          ..buffer.addAll(response)
          ..fetched += 1;
      } else {
        error ??= results[i];
      }
    }
    // 平滑加权轮转：每出一张，有货的各端加上自己的权重，最大的出牌并减去这些权重之和
    final list = <BaseRcmdVideoItemModel>[];
    while (list.length < _batch) {
      _Feed? next;
      var total = 0;
      for (final feed in _feeds) {
        if (feed.buffer.isEmpty) continue;
        feed.current += feed.weight;
        total += feed.weight;
        if (next == null || feed.current > next.current) next = feed;
      }
      if (next == null) break;
      next.current -= total;
      final item = next.buffer.removeFirst();
      if (_seen.add(item.aid ?? 0)) list.add(item);
    }
    return list.isEmpty && error != null ? error : Success(list);
  }

  @override
  bool handleError(String? errMsg) {
    return enableSaveLastData;
  }

  @override
  void handleListResponse(List dataList) {
    if (enableSaveLastData && page == 0) {
      if (loadingState.value case Success(:final response)) {
        if (response != null && response.isNotEmpty) {
          if (savedRcmdTip) {
            lastRefreshAt = dataList.length;
          }
          if (response.length > 200) {
            dataList.addAll(response.take(50));
          } else {
            dataList.addAll(response);
          }
        }
      }
    }
  }

  @override
  Future<void> onRefresh() {
    page = 0;
    isEnd = false;
    return queryData();
  }
}
