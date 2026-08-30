import 'package:PiliBro/http/api.dart';
import 'package:PiliBro/http/init.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/models_new/match/match_info/contest.dart';
import 'package:PiliBro/models_new/match/match_info/data.dart';

abstract final class MatchHttp {
  static Future<LoadingState<MatchContest?>> matchInfo(Object cid) async {
    final res = await Request().get(
      Api.matchInfo,
      queryParameters: {
        'cid': cid,
        'platform': 2,
      },
    );
    if (res.data['code'] == 0) {
      return Success(MatchInfoData.fromJson(res.data['data']).contest);
    } else {
      return Error(res.data['message']);
    }
  }
}
