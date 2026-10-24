import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliBro/grpc/bilibili/metadata/device.pb.dart';
import 'package:PiliBro/grpc/bilibili/metadata/locale.pb.dart';
import 'package:PiliBro/grpc/bilibili/metadata/network.pb.dart' as network;
import 'package:PiliBro/utils/id_utils.dart';
import 'package:PiliBro/utils/login_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';

/// 向 B 站自报的设备：小米 13 Ultra（ishtar），参数取自作者手中这台的「全部参数与信息」。
/// 只填机型、系统这类公开信息，不碰 IMEI、MAC、AndroidID、OAID
abstract final class BiliDevice {
  static const brand = 'Xiaomi';
  static const model = '2304FPN6DC';
  static const device = 'ishtar';
  static const osVer = '16';
  // 截图没有 Build ID，按小米 Android 16 的格式填
  static const buildId = 'BP2A.250605.031.A3';
  static const displayId = 'OS3.0.308.0.WMACNXM';
  static const radio = 'MPSS.DE.3.0-CN-bcb273a2c6';
  static const kernel = '5.15.194-android13-8-00019-gf4321180a397-ab15212794';
  static const fingerprint =
      '$brand/$device/$device:$osVer/$buildId/$displayId:user/release-keys';
  static const channel = 'xiaomi';
  static const screenWidth = 1440;
  static const screenHeight = 3200;
  static const densityDpi = 560;

  static String get buvid => LoginUtils.buvid;

  /// 设备指纹：md5(buvid + 机型 + 基带) + 时间 + 16 位随机 + 2 位校验，首次生成后存下
  static final String fp =
      GStorage.localCache.get(LocalCacheKey.fp) as String? ?? _newFp();

  static String _newFp() {
    final now = DateTime.now();
    String two(int v) => v < 10 ? '0$v' : '$v';
    final raw =
        '${md5.convert(utf8.encode('$buvid$model$radio'))}'
        '${now.year}${two(now.month)}${two(now.day)}'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}'
        '${_hex(16)}';
    var veri = 0;
    for (var i = 0; i < 62; i += 2) {
      veri += int.parse(raw.substring(i, i + 2), radix: 16);
    }
    final value = '$raw${(veri & 255).toRadixString(16).padLeft(2, '0')}';
    GStorage.localCache.put(LocalCacheKey.fp, value);
    return value;
  }

  static String _hex(int length) => String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => '0123456789abcdef'.codeUnitAt(Utils.random.nextInt(16)),
    ),
  );

  /// 每次启动换一个，与官方客户端一样是 8 位十六进制
  static final String sessionId = _hex(8);

  /// 首次安装时间（秒），首次生成后存下
  static final int fts =
      GStorage.localCache.get(LocalCacheKey.fts) as int? ?? _newFts();

  static int _newFts() {
    final value = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    GStorage.localCache.put(LocalCacheKey.fts, value);
    return value;
  }

  /// x-bili-trace-id：前 13 字节随机，后 3 字节放秒级时间戳的高 3 字节
  static String traceId() {
    final bytes = Uint8List(16);
    for (var i = 0; i < 13; i++) {
      bytes[i] = Utils.random.nextInt(256);
    }
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    bytes[13] = ts >> 24;
    bytes[14] = ts >> 16;
    bytes[15] = ts >> 8;
    final hex = [
      for (final b in bytes) b.toRadixString(16).padLeft(2, '0'),
    ].join();
    return '$hex:${hex.substring(16)}:0:0';
  }

  static final String localeBin = base64Encode(
    Locale(
      cLocale: LocaleIds(language: 'zh', script: 'Hans', region: 'CN'),
      sLocale: LocaleIds(language: 'zh', script: 'Hans', region: 'CN'),
      timezone: 'Asia/Shanghai',
      utcOffset: '+08:00',
    ).writeToBuffer(),
  );

  static final String networkBin = base64Encode(
    network.Network(
      type: network.NetworkType.WIFI,
      tf: network.TFType.TF_UNKNOWN,
      oid: '46000',
    ).writeToBuffer(),
  );

  static String deviceBin(BiliApp app) => base64Encode(
    Device(
      appId: app.appId,
      build: app.build,
      buvid: buvid,
      mobiApp: app.mobiApp,
      platform: 'android',
      channel: channel,
      brand: brand,
      model: model,
      osver: osVer,
      fpLocal: fp,
      fpRemote: fp,
      versionName: app.version,
      fp: fp,
      fts: Int64(fts),
    ).writeToBuffer(),
  );

  /// App 端 REST 请求的公共请求头，按官方顺序；trace-id 由拦截器每次请求现生成
  static Map<String, String> appHeaders(BiliApp app, int mid) => {
    'accept': '*/*',
    'app-key': app.keyName,
    'bili-http-engine': 'ignet',
    'buvid': buvid,
    'env': 'prod',
    'fp_local': fp,
    'fp_remote': fp,
    'session_id': sessionId,
    'user-agent': app.userAgent,
    if (mid > 0) 'x-bili-aurora-eid': IdUtils.genAuroraEid(mid),
    'x-bili-locale-bin': localeBin,
    'x-bili-metadata-ip-region': 'CN',
    if (mid > 0) 'x-bili-mid': '$mid',
    'x-bili-network-bin': networkBin,
  };
}

const phoneVersion = '8.62.0';
const phoneBuild = 8620300;
const hdVersion = '2.3.1';
const hdBuild = 2031100;
const _phoneStatistics =
    '{"appId":1,"platform":3,"version":"$phoneVersion","abtest":""}';
const _hdStatistics =
    '{"appId":5,"platform":3,"version":"$hdVersion","abtest":""}';
const phoneUserAgent =
    'Mozilla/5.0 BiliDroid/$phoneVersion (bbcallen@gmail.com) '
    'os/android model/${BiliDevice.model} mobi_app/android build/$phoneBuild '
    'channel/${BiliDevice.channel} innerVer/$phoneBuild '
    'osVer/${BiliDevice.osVer} network/2';
const hdUserAgent =
    'Mozilla/5.0 BiliDroid/$hdVersion (bbcallen@gmail.com) '
    'os/android model/${BiliDevice.model} mobi_app/android_hd build/$hdBuild '
    'channel/${BiliDevice.channel} innerVer/$hdBuild '
    'osVer/${BiliDevice.osVer} network/2';

/// 客户端身份。key、build、mobi_app、statistics、UA 成套出现，签名用哪套就自报哪套
enum BiliApp {
  /// 粉版手机客户端
  phone(
    appKey: '1d8b6e7d45233436',
    appSec: '560c52ccd288fed045859ed18bffd973',
    keyName: 'android64',
    mobiApp: 'android',
    build: phoneBuild,
    version: phoneVersion,
    appId: 1,
    statistics: _phoneStatistics,
    userAgent: phoneUserAgent,
  ),

  /// HD 平板客户端
  hd(
    appKey: 'dfca71928277209b',
    appSec: 'b5475a8825547a4fc26c7d518eaaa02e',
    keyName: 'android_hd',
    mobiApp: 'android_hd',
    build: hdBuild,
    version: hdVersion,
    appId: 5,
    statistics: _hdStatistics,
    userAgent: hdUserAgent,
  ),

  /// 短信登录专用 key，拿到的 token 归粉版使用
  sms(
    appKey: '783bbb7264451d82',
    appSec: '2653583c8873dea268ab9386918b1d65',
    keyName: 'android64',
    mobiApp: 'android',
    build: phoneBuild,
    version: phoneVersion,
    appId: 1,
    statistics: _phoneStatistics,
    userAgent: phoneUserAgent,
  );

  final String appKey;
  final String appSec;
  final String keyName;
  final String mobiApp;
  final int build;
  final String version;
  final int appId;
  final String statistics;
  final String userAgent;

  const BiliApp({
    required this.appKey,
    required this.appSec,
    required this.keyName,
    required this.mobiApp,
    required this.build,
    required this.version,
    required this.appId,
    required this.statistics,
    required this.userAgent,
  });

  /// gRPC 请求用 Dalvik 开头的 UA
  String get grpcUserAgent =>
      'Dalvik/2.1.0 (Linux; U; Android ${BiliDevice.osVer}; '
      '${BiliDevice.model} Build/${BiliDevice.buildId}) $version '
      '${userAgent.substring(userAgent.indexOf('os/'))}';

  /// App 接口的公共参数
  Map<String, dynamic> get commonParams => {
    'build': build,
    'c_locale': 'zh-Hans_CN',
    'channel': BiliDevice.channel,
    'mobi_app': mobiApp,
    'platform': 'android',
    's_locale': 'zh-Hans_CN',
    'statistics': statistics,
  };
}