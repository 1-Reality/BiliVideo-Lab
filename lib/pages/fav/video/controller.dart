import 'package:PiliBro/http/fav.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/models_new/fav/fav_folder/data.dart';
import 'package:PiliBro/models_new/fav/fav_folder/list.dart';
import 'package:PiliBro/pages/common/common_list_controller.dart';
import 'package:PiliBro/utils/accounts.dart';

class FavController extends CommonListController<FavFolderData, FavFolderInfo> {
  late final account = Accounts.main;

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  Future<void> queryData([bool isRefresh = true]) {
    if (!account.isLogin) {
      loadingState.value = const Error('账号未登录');
      return Future.syncValue(null);
    }
    return super.queryData(isRefresh);
  }

  @override
  List<FavFolderInfo>? getDataList(FavFolderData response) {
    if (response.hasMore == false) {
      isEnd = true;
    }
    return response.list;
  }

  @override
  Future<LoadingState<FavFolderData>> customGetData() => FavHttp.userfavFolder(
    pn: page,
    ps: 20,
    mid: account.mid,
  );
}
