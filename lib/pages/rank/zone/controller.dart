import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/video.dart';
import 'package:PiliBro/pages/common/common_list_controller.dart';

class ZoneController extends CommonListController {
  ZoneController({this.rid, this.seasonType});

  final int? rid;
  final int? seasonType;

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  Future<LoadingState> customGetData() => rid != null
      ? VideoHttp.getRankVideoList(rid!)
      : seasonType == 1
      ? VideoHttp.pgcRankList(seasonType: seasonType!)
      : VideoHttp.pgcSeasonRankList(seasonType: seasonType!);
}
