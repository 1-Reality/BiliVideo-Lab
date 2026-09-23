import 'package:PiliBro/grpc/bilibili/main/community/reply/v1.pb.dart'
    show MainListReply, ReplyInfo;
import 'package:PiliBro/grpc/reply.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/pages/common/reply_controller.dart';
import 'package:get/get.dart';

class MainReplyController extends ReplyController<MainListReply> {
  late final int oid;
  late final int replyType;

  @override
  int get sourceId => oid;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    oid = args['oid'];
    replyType = args['replyType'];

    queryData();
  }

  @override
  Future<LoadingState<MainListReply>> customGetData() => ReplyGrpc.mainList(
    type: replyType,
    oid: oid,
    mode: mode,
    cursorNext: cursorNext,
    offset: paginationReply?.nextOffset,
  );

  @override
  List<ReplyInfo>? getDataList(MainListReply response) => response.replies;
}
