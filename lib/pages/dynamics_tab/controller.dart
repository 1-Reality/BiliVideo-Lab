import 'package:PiliBro/http/dynamics.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/msg.dart';
import 'package:PiliBro/models/common/dynamic/dynamics_type.dart';
import 'package:PiliBro/models/dynamics/result.dart';
import 'package:PiliBro/pages/common/common_list_controller.dart';
import 'package:PiliBro/pages/dynamics/controller.dart';
import 'package:PiliBro/pages/main/controller.dart';
import 'package:PiliBro/services/account_service.dart';
import 'package:PiliBro/utils/extension/scroll_controller_ext.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class DynamicsTabController
    extends CommonListController<DynamicsDataModel, DynamicItemModel>
    with AccountMixin {
  DynamicsTabController({required this.dynamicsType});
  final DynamicsTabType dynamicsType;

  String? offset;

  late final mainController = Get.find<MainController>();
  final dynamicsController = Get.find<DynamicsController>();

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  Future<void> onRefresh() {
    if (dynamicsType == .all) {
      mainController.setDynCount();
    }
    offset = null;
    return super.onRefresh();
  }

  @override
  List<DynamicItemModel>? getDataList(DynamicsDataModel response) {
    offset = response.offset;
    return response.items;
  }

  @override
  Future<LoadingState<DynamicsDataModel>> customGetData() =>
      DynamicsHttp.followDynamic(
        offset: offset,
        type: dynamicsType,
        hostMid: dynamicsController.hostMid,
        tempBannedList: dynamicsController.tempBannedList,
      );

  Future<void> onRemove(int index, dynamic dynamicId) async {
    final res = await MsgHttp.removeDynamic(dynIdStr: dynamicId);
    if (res.isSuccess) {
      loadingState
        ..value.data!.removeAt(index)
        ..refresh();
      SmartDialog.showToast('删除成功');
    } else {
      res.toast();
    }
  }

  @override
  Future<void> onReload() {
    scrollController.jumpToTop();
    return super.onReload();
  }

  void onBlock(int index) {
    if (dynamicsType != .up) {
      loadingState
        ..value.data!.removeAt(index)
        ..refresh();
    }
  }

  void onUnfold(DynamicItemModel item, int index) {
    try {
      final list = loadingState.value.data!;
      final ids = item.modules.moduleFold!.ids!;
      final end = index + ids.length + 1;
      for (var i = index + 1; i < end; i++) {
        list[i].visible = true;
      }
      item.modules.moduleFold = null;
      loadingState.refresh();
    } catch (_) {}
  }

  @override
  void onChangeAccount(bool isLogin) => onReload();
}
