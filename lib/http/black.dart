import 'package:PiliBro/http/api.dart';
import 'package:PiliBro/http/init.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/models_new/blacklist/data.dart';
import 'package:PiliBro/utils/accounts.dart';

abstract final class BlackHttp {
  static Future<LoadingState<BlackListData>> blackList({
    required int pn,
    int ps = 50,
  }) async {
    final res = await Request().get(
      Api.blackLst,
      queryParameters: {
        'pn': pn,
        'ps': ps,
        're_version': 0,
        'jsonp': 'jsonp',
        'csrf': Accounts.main.csrf,
      },
    );
    if (res.data['code'] == 0) {
      return Success(BlackListData.fromJson(res.data['data']));
    } else {
      return Error(res.data['message']);
    }
  }
}
