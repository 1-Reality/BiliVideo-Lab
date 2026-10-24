import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/video.dart';
import 'package:PiliBro/models/common/rcmd_source.dart';
import 'package:PiliBro/models/model_rec_video_item.dart';
import 'package:PiliBro/pages/common/common_list_controller.dart';
import 'package:PiliBro/pages/rcmd/interest_choose.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:get/get.dart';

class RcmdController extends CommonListController {
  late bool enableSaveLastData = Pref.enableSaveLastData;
  final RcmdSource source = Pref.rcmdSource;

  // App 端翻页游标；混合模式里 Web 端用基类的 page
  final cursor = RcmdAppCursor();
  // 混合模式跨页去重
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

  Future<LoadingState<List<BaseRcmdVideoItemModel>>> _app(bool refresh) async {
    final res = await VideoHttp.rcmdVideoListApp(
      cursor,
      refresh: refresh,
      keepOld: enableSaveLastData,
    );
    if (cursor.interestChoose case final choose?) {
      cursor.interestChoose = null;
      if (Get.context case final context?) {
        showInterestChoose(context, choose).then((interest) {
          if (interest == null) return;
          GStorage.setting.put(SettingBoxKey.rcmdInterestDone, true);
          cursor.interest = interest;
          onRefresh();
        });
      }
    }
    return res;
  }

  @override
  Future<LoadingState> customGetData() async {
    final refresh = page == 0;
    if (source == RcmdSource.web) {
      return VideoHttp.rcmdVideoList(freshIdx: page);
    }
    if (source == RcmdSource.app) return _app(refresh);
    final results = await Future.wait([
      VideoHttp.rcmdVideoList(freshIdx: page),
      _app(refresh),
    ]);
    // 一端失败就只展示另一端
    final web = results[0].dataOrNull ?? const [];
    final app = results[1].dataOrNull ?? const [];
    if (web.isEmpty && app.isEmpty) return results[0];
    // 交错排列（App 在前）、跨页按 aid 去重
    if (refresh) _seen.clear();
    final length = web.length > app.length ? web.length : app.length;
    return Success([
      for (var i = 0; i < length; i++) ...[
        if (i < app.length && _seen.add(app[i].aid ?? 0)) app[i],
        if (i < web.length && _seen.add(web[i].aid ?? 0)) web[i],
      ],
    ]);
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
