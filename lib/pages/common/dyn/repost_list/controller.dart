import 'package:PiliBro/grpc/bilibili/app/dynamic/v2.pb.dart'
    show RepostListRsp, DynamicItem;
import 'package:PiliBro/grpc/dyn.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/pages/common/common_list_controller.dart';
import 'package:get/get.dart';

class DynRepostController
    extends CommonListController<RepostListRsp, DynamicItem> {
  DynRepostController(this.id, {int count = -1}) : count = RxInt(count);
  final String id;

  String? _offset;
  final RxInt count;

  @override
  List<DynamicItem>? getDataList(RepostListRsp response) {
    _offset = response.offset;
    count.value = response.totalCount.toInt();
    if (!response.hasMore) {
      isEnd = true;
    }
    return response.list;
  }

  @override
  Future<LoadingState<RepostListRsp>> customGetData() =>
      DynGrpc.repostList(dynamicId: id, offset: _offset);

  @override
  Future<void> onRefresh() {
    _offset = null;
    return super.onRefresh();
  }
}
