import 'dart:convert';

import 'package:PiliBro/grpc/bilibili/metadata.pb.dart';
import 'package:PiliBro/grpc/bilibili/metadata/fawkes.pb.dart';
import 'package:PiliBro/utils/bili_device.dart';
import 'package:PiliBro/utils/id_utils.dart';
import 'package:PiliBro/utils/storage_pref.dart';

/// gRPC 公共请求头；trace-id 与 ticket 由拦截器每次请求补上
abstract final class GrpcHeaders {
  static String fawkes(BiliApp app) => base64Encode(
    FawkesReq(
      appkey: app.keyName,
      env: 'prod',
      sessionId: BiliDevice.sessionId,
    ).writeToBuffer(),
  );

  // 新版本客户端拿到的楼中楼正文不再带「回复 @某人 :」，靠客户端自己拼。
  // 评论接口照 PiliPlus 自报 HD 2.0.1，让服务器把前缀写回正文
  static bool replyLegacy = Pref.replyLegacyIdentity;
  static const _replyBuild = 2001100;
  static const _replyVersion = '2.0.1';

  /// 盖在 [newHeaders] 上，只用于评论列表的 gRPC。票要跟身份一套：有 HD token 就用它，
  /// 拿粉版 token 自报 HD 时服务器当成未登录，IP 属地之类只给登录用户的字段就没了
  static Map<String, String> replyHeaders(String? accessKey) => {
    if (accessKey != null) 'authorization': 'identify_v1 $accessKey',
    'x-bili-device-bin': BiliDevice.deviceBin(
      BiliApp.hd,
      build: _replyBuild,
      version: _replyVersion,
    ),
    'x-bili-metadata-bin': base64Encode(
      Metadata(
        accessKey: accessKey,
        mobiApp: BiliApp.hd.mobiApp,
        build: _replyBuild,
        channel: BiliDevice.channel,
        buvid: BiliDevice.buvid,
        platform: 'android',
      ).writeToBuffer(),
    ),
  };

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
