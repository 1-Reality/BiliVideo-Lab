import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/video.dart';
import 'package:PiliBro/pages/common/common_list_controller.dart';

class ZoneController extends CommonListController {
  ZoneController({this.rid, this.seasonType});

  int? rid;
  int? seasonType;

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  Future<LoadingState> customGetData() {
    if (rid != null) {
      return VideoHttp.getRankVideoList(rid!);
    }
    if (seasonType == 1) {
      return VideoHttp.pgcRankList(seasonType: seasonType!);
    }
    return VideoHttp.pgcSeasonRankList(seasonType: seasonType!);
  }
}
