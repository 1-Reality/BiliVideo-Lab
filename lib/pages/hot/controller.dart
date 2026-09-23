import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/video.dart';
import 'package:PiliBro/models/model_hot_video_item.dart';
import 'package:PiliBro/pages/common/common_list_controller.dart';

class HotController
    extends CommonListController<List<HotVideoItemModel>, HotVideoItemModel> {
  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  Future<LoadingState<List<HotVideoItemModel>>> customGetData() =>
      VideoHttp.hotVideoList(
        pn: page,
        ps: 20,
      );
}
