import 'package:PiliBro/grpc/bilibili/app/dynamic/v2.pb.dart';
import 'package:PiliBro/grpc/bilibili/app/interfaces/v1.pb.dart'
    show SearchArchiveReply, SearchArchiveReq;
import 'package:PiliBro/grpc/bilibili/pagination.pb.dart';
import 'package:PiliBro/grpc/grpc_req.dart';
import 'package:PiliBro/grpc/url.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:fixnum/fixnum.dart';

abstract final class SpaceGrpc {
  static Future<LoadingState<OpusSpaceFlowResp>> opusSpaceFlow({
    required int hostMid,
    String? next,
    required String filterType,
  }) {
    return GrpcReq.request(
      GrpcUrl.opusSpaceFlow,
      OpusSpaceFlowReq(
        hostMid: Int64(hostMid),
        pagination: Pagination(pageSize: 20, next: next),
        filterType: filterType,
      ),
      OpusSpaceFlowResp.fromBuffer,
    );
  }

  static Future<LoadingState<SearchArchiveReply>> searchArchive({
    required String keyword,
    required Int64 mid,
    required int pn,
    required Int64 ps,
  }) {
    return GrpcReq.request(
      GrpcUrl.searchArchive,
      SearchArchiveReq(
        keyword: keyword,
        mid: mid,
        pn: Int64(pn),
        ps: ps,
      ),
      SearchArchiveReply.fromBuffer,
    );
  }
}
