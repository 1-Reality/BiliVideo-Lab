import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/video.dart';
import 'package:PiliBro/models/model_hot_video_item.dart';
import 'package:PiliBro/pages/common/common_list_controller.dart';
import 'package:get/get.dart';

class RelatedController
    extends CommonListController<List<HotVideoItemModel>?, HotVideoItemModel> {
  RelatedController({this.autoQuery = true});
  String bvid = Get.arguments['bvid'];
  final bool autoQuery;

  @override
  void onInit() {
    super.onInit();
    if (autoQuery) {
      queryData();
    }
  }

  @override
  Future<LoadingState<List<HotVideoItemModel>?>> customGetData() =>
      VideoHttp.relatedVideoList(bvid: bvid);
}
