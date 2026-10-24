import 'dart:convert';

import 'package:PiliBro/grpc/bilibili/metadata.pb.dart';
import 'package:PiliBro/grpc/bilibili/metadata/fawkes.pb.dart';
import 'package:PiliBro/utils/bili_device.dart';
import 'package:PiliBro/utils/id_utils.dart';

/// gRPC 公共请求头；trace-id 与 ticket 由拦截器每次请求补上
abstract final class GrpcHeaders {
  static String fawkes(BiliApp app) => base64Encode(
    FawkesReq(
      appkey: app.keyName,
      env: 'prod',
      sessionId: BiliDevice.sessionId,
    ).writeToBuffer(),
  );

  static Map<String, String> newHeaders(
    BiliApp app,
    int mid, [
    String? accessKey,
  ]) => {
    'grpc-encoding': 'gzip',
    'gzip-accept-encoding': 'gzip,identity',
    'user-agent': app.grpcUserAgent,
    'x-bili-gaia-vtoken': '',
    'x-bili-aurora-zone': '',
    'x-bili-aurora-eid': mid > 0 ? IdUtils.genAuroraEid(mid) : '',
    'x-bili-mid': mid > 0 ? '$mid' : '',
    'buvid': BiliDevice.buvid,
    'env': 'prod',
    'app-key': app.keyName,
    'bili-http-engine': 'ignet',
    // 'te': 'trailers', // dio not supported
    'x-bili-device-bin': BiliDevice.deviceBin(app),
    'x-bili-network-bin': BiliDevice.networkBin,
    'x-bili-locale-bin': BiliDevice.localeBin,
    'x-bili-exps-bin': '',
    'x-bili-restriction-bin': '',
    if (accessKey != null) 'authorization': 'identify_v1 $accessKey',
    'x-bili-fawkes-req-bin': fawkes(app),
    'x-bili-metadata-bin': base64Encode(
      Metadata(
        accessKey: accessKey,
        mobiApp: app.mobiApp,
        build: app.build,
        channel: BiliDevice.channel,
        buvid: BiliDevice.buvid,
        platform: 'android',
      ).writeToBuffer(),
    ),
  };
}
