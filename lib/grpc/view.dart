import 'package:PiliBro/grpc/bilibili/app/viewunite/v1.pb.dart'
    show ViewReq, ViewReply;
import 'package:PiliBro/grpc/grpc_req.dart';
import 'package:PiliBro/grpc/url.dart';
import 'package:PiliBro/http/loading_state.dart';

abstract final class ViewGrpc {
  static Future<LoadingState<ViewReply>> view({
    required String bvid,
  }) {
    return GrpcReq.request(
      GrpcUrl.view,
      ViewReq(bvid: bvid),
      ViewReply.fromBuffer,
    );
  }
}
