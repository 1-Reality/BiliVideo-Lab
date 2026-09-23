import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/user.dart';
import 'package:PiliBro/models_new/space_setting/data.dart';
import 'package:PiliBro/models_new/space_setting/privacy.dart';
import 'package:PiliBro/pages/common/common_data_controller.dart';

class SpaceSettingController
    extends CommonDataController<SpaceSettingData, Privacy?> {
  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  bool? hasMod;

  @override
  bool customHandleResponse(
    bool isRefresh,
    Success<SpaceSettingData> response,
  ) {
    loadingState.value = Success(response.response.privacy);
    return true;
  }

  @override
  Future<LoadingState<SpaceSettingData>> customGetData() =>
      UserHttp.spaceSetting();

  Future<void> onMod() async {
    if (hasMod ?? false) {
      if (loadingState.value case Success(:final response?)) {
        final res = await UserHttp.spaceSettingMod(
          {
            for (final e in response.list1) e.key: e.value,
            for (final e in response.list2) e.key: e.value,
            for (final e in response.list3) e.key: e.value,
          },
        );
        if (!res.isSuccess) {
          res.toast();
        }
      }
    }
  }
}
