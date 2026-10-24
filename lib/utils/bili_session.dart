import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliBro/grpc/grpc_req.dart';
import 'package:PiliBro/http/constants.dart';
import 'package:PiliBro/http/init.dart';
import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/accounts/account.dart';
import 'package:PiliBro/utils/app_sign.dart';
import 'package:PiliBro/utils/bili_device.dart';
import 'package:PiliBro/utils/login_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';

/// 官方客户端在设备上维持的会话凭据：x-bili-ticket、guestid，以及新装时向服务端换取的 buvid。
/// 全部在首帧之后后台获取并存下，请求时只读缓存；拿不到就不带，不影响其他请求
abstract final class BiliSession {
  static String ticket =
      GStorage.localCache.get(LocalCacheKey.biliTicket) as String? ?? '';
  static int _ticketExpireAt =
      GStorage.localCache.get(LocalCacheKey.biliTicketExpireAt) as int? ?? 0;
  static String guestId =
      GStorage.localCache.get(LocalCacheKey.guestId) as String? ?? '';

  // 下次允许去换 ticket 的时间，失败后十分钟内不再重试
  static int _nextTryAt = 0;

  // 开机时长：假定开机三天后启动的本应用
  static final _uptime = Stopwatch()..start();

  // 离过期不到半小时就后台换新
  static const _refreshAheadMs = 1800000;

  static void init() {
    if (LoginUtils.freshBuvid) unawaited(_fetchBuvid());
    if (guestId.isEmpty) unawaited(_fetchGuestId());
    checkTicket();
  }

  /// 每个请求现补的头：trace-id、ticket、guestid；顺手看一眼 ticket 是否该换
  static Map<String, String> get dynamicHeaders {
    checkTicket();
    return {
      'x-bili-trace-id': BiliDevice.traceId(),
      if (ticket.isNotEmpty) 'x-bili-ticket': ticket,
      if (guestId.isNotEmpty) 'guestid': guestId,
    };
  }

  static void checkTicket() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= _nextTryAt && _ticketExpireAt - now < _refreshAheadMs) {
      _nextTryAt = now + 600000;
      unawaited(_fetchTicket());
    }
  }

  static Future<void> _fetchTicket() async {
    final account = Accounts.main;
    final mid = account.mid;
    final deviceBytes = base64Decode(
      account.grpcHeaders['x-bili-device-bin']!,
    );
    final fingerprint = _androidDeviceInfo(account.app, mid);
    final sign = Hmac(sha256, utf8.encode('Ezlc3tgtl')).convert([
      ...deviceBytes,
      ...utf8.encode('x-exbadbasket'),
      ...utf8.encode('x-fingerprint'),
      ...fingerprint,
    ]).bytes;
    final request = (_Pb()
          ..message(
            1,
            (_Pb()
                  ..string(1, 'x-fingerprint')
                  ..bytes(2, fingerprint))
                .toBytes(),
          )
          ..message(
            1,
            (_Pb()
                  ..string(1, 'x-exbadbasket')
                  ..bytes(2, const [], force: true))
                .toBytes(),
          )
          ..string(2, 'ec01')
          ..bytes(3, sign))
        .toBytes();
    final res = await Request().post<Uint8List>(
      '${HttpString.appBaseUrl}/bilibili.api.ticket.v1.Ticket/GetTicket',
      data: GrpcReq.compressProtobuf(request),
      options: Options(
        contentType: 'application/grpc',
        responseType: ResponseType.bytes,
        extra: {'account': account},
      ),
    );
    if (res.headers.value('Grpc-Status') != '0') return;
    final data = res.data;
    if (data is! Uint8List) return;
    final fields = _Pb.read(GrpcReq.decompressProtobuf(data));
    final value = fields[1];
    if (value is! List<int>) return;
    final createdAt = fields[2] as int? ?? 0;
    final ttl = fields[3] as int? ?? 0;
    ticket = utf8.decode(value);
    _ticketExpireAt =
        (createdAt > 0
            ? createdAt * 1000
            : DateTime.now().millisecondsSinceEpoch) +
        ttl * 1000;
    await GStorage.localCache.putAll({
      LocalCacheKey.biliTicket: ticket,
      LocalCacheKey.biliTicketExpireAt: _ticketExpireAt,
    });
  }

  /// ticket 接口要的设备指纹：只填机型、系统、电量这类公开或无害的信息，
  /// 标识类字段（IMEI、MAC、AndroidID、DRM ID、序列号）一律留空
  static Uint8List _androidDeviceInfo(BiliApp app, int mid) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final guid =
        GStorage.localCache.get(LocalCacheKey.deviceGuid) as String? ??
        _newGuid();
    const totalMem = 16106127360; // 16 GB 版本
    return (_Pb()
          ..string(1, '0.2.4')
          ..string(2, '${app.appId}')
          ..string(3, app.version)
          ..string(4, '${app.build}')
          ..string(5, mid > 0 ? '$mid' : '')
          ..string(6, BiliDevice.channel)
          ..int64(7, BiliDevice.fts)
          ..string(8, BiliDevice.fp)
          ..string(10, 'tv.danmaku.bili')
          ..string(12, BiliDevice.radio)
          ..string(13, BiliDevice.osVer)
          ..int64(14, now)
          ..int64(15, 8)
          ..string(16, BiliDevice.model)
          ..string(17, BiliDevice.brand)
          ..string(
            18,
            '${BiliDevice.screenWidth},${BiliDevice.screenHeight},'
            '${BiliDevice.densityDpi}',
          )
          ..string(19, 'Qualcomm Technologies, Inc KALAMA')
          ..int64(21, 259200000 + _uptime.elapsedMilliseconds)
          ..string(22, '000')
          ..string(23, '46000')
          ..string(24, 'WIFI')
          ..int64(25, totalMem)
          ..int64(27, 3187200)
          ..string(28, 'Qualcomm')
          ..int64(30, 128)
          ..map(31, {
            'ro.product.device': BiliDevice.device,
            'ro.build.fingerprint': BiliDevice.fingerprint,
            'ro.product.manufacturer': BiliDevice.brand,
            'ro.build.display.id': BiliDevice.displayId,
          })
          ..string(35, 'android')
          ..int64(42, 512000000000)
          ..string(43, 'false')
          ..string(45, '/data/user/0/tv.danmaku.bili/files')
          ..string(46, '0')
          ..string(47, '[]')
          ..string(50, '[]')
          ..string(51, guid)
          ..string(56, '00000000-0000-0000-0000-000000000000')
          ..string(60, '[]')
          ..string(62, '[]')
          ..int64(63, 84)
          ..string(64, 'BATTERY_STATUS_DISCHARGING')
          ..string(67, BiliDevice.displayId)
          ..string(68, 'CN')
          ..int64(70, totalMem ~/ 3)
          ..string(71, '47600000000')
          ..string(74, BiliDevice.kernel)
          ..string(75, 'zh')
          ..int64(82, totalMem)
          ..string(83, '84')
          ..string(85, '128')
          ..string(86, '${app.appId}')
          ..int64(91, 1)
          ..int64(92, 1)
          ..int64(93, 1)
          ..int64(94, 1)
          ..int64(95, 1)
          ..string(96, 'touchid')
          ..int64(97, now)
          ..string(108, 'OS3.0.308.0')
          ..boolean(112, true)
          ..string(113, 'Li-poly')
          ..int64(114, 300)
          ..int64(115, 4100)
          ..int64(117, 2))
        .toBytes();
  }

  static String _newGuid() {
    final bytes = List.generate(16, (_) => Utils.random.nextInt(256));
    bytes[6] = bytes[6] & 0x0f | 0x40;
    bytes[8] = bytes[8] & 0x3f | 0x80;
    final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')]
        .join();
    final value =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    GStorage.localCache.put(LocalCacheKey.deviceGuid, value);
    return value;
  }

  /// passport 的 dt：随机 16 位 AES 密钥用 RSA 公钥加密；载荷用同一密钥 AES-CBC 加密后转大写十六进制
  static Future<(String, String)?> _encryptPayload(String payload) async {
    final res = await Request().get(
      '${HttpString.passBaseUrl}/x/passport-login/web/key',
      options: Options(extra: {'account': const NoAccount()}),
    );
    if (res.data['code'] != 0) return null;
    const letters =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final aesKey = String.fromCharCodes(
      Iterable.generate(
        16,
        (_) => letters.codeUnitAt(Utils.random.nextInt(letters.length)),
      ),
    );
    final key = Key.fromUtf8(aesKey);
    final encrypted = Encrypter(
      AES(key, mode: AESMode.cbc),
    ).encrypt(payload, iv: IV(key.bytes)).bytes;
    final dynamic publicKey = RSAKeyParser().parse(res.data['data']['key']);
    final dt = Encrypter(RSA(publicKey: publicKey)).encrypt(aesKey).base64;
    return (
      dt,
      [
        for (final b in encrypted) b.toRadixString(16).padLeft(2, '0'),
      ].join().toUpperCase(),
    );
  }

  static Future<void> _fetchGuestId() async {
    final payload = await _encryptPayload(
      jsonEncode({
        'DeviceType': 'Android',
        'Buvid': BiliDevice.buvid,
        'fts': '${BiliDevice.fts}',
        'BuildHost': 'android-build',
        'BuildDisplay': BiliDevice.displayId,
        'BuildFingerprint': BiliDevice.fingerprint,
        'BuildBrand': BiliDevice.brand,
      }),
    );
    if (payload == null) return;
    const app = BiliApp.phone;
    final params = <String, dynamic>{
      ...app.commonParams,
      'buvid': BiliDevice.buvid,
      'device_info': payload.$2,
      'disable_rcmd': 0,
      'dt': payload.$1,
      'local_id': BiliDevice.buvid,
    };
    AppSign.appSign(params, app);
    final res = await Request().post(
      '${HttpString.passBaseUrl}/x/passport-user/guest/reg',
      data: params,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {...BiliDevice.appHeaders(app, 0), ...dynamicHeaders},
        extra: {'account': const NoAccount()},
      ),
    );
    if (res.data['code'] == 0) {
      guestId = '${res.data['data']['guest_id']}';
      GStorage.localCache.put(LocalCacheKey.guestId, guestId);
    }
  }

  /// 新装时用本地 buvid 向服务端换取正式 buvid，下次启动起生效；老用户的 buvid 不动
  static Future<void> _fetchBuvid() async {
    const app = BiliApp.phone;
    final local = BiliDevice.buvid;
    final params = <String, dynamic>{
      'androidId': '',
      'brand': BiliDevice.brand,
      'build': app.build,
      'buvid': local,
      'channel': BiliDevice.channel,
      'drmId': '',
      'fawkesAppKey': app.keyName,
      'first': 1,
      'firstStart': 1,
      'imei': '',
      'internalVersionCode': app.build,
      'mac': '',
      'model': BiliDevice.model,
      'neuronAppId': app.appId,
      'neuronPlatformId': 3,
      'oaid': '',
      'versionCode': app.build,
      'versionName': app.version,
    };
    AppSign.appSign(params, app);
    final res = await Request().post(
      '${HttpString.appBaseUrl}/x/polymer/buvid/get',
      data: params,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {...BiliDevice.appHeaders(app, 0), ...dynamicHeaders},
        extra: {'account': const NoAccount()},
      ),
    );
    if (res.data['code'] == 0) {
      final String? remote = res.data['data']?['buvid'];
      if (remote != null && remote.isNotEmpty) {
        GStorage.localCache.put(LocalCacheKey.buvid, remote);
      }
    }
  }
}

/// 只够用的 protobuf 读写：proto3 默认值不写
class _Pb {
  final _out = BytesBuilder(copy: false);

  void _varint(int value) {
    // 负数按 64 位补码写 10 字节
    var v = value;
    for (var i = 0; i < 10; i++) {
      final byte = v & 0x7f;
      v = v >>> 7;
      if (v == 0) {
        _out.addByte(byte);
        return;
      }
      _out.addByte(byte | 0x80);
    }
  }

  void _tag(int field, int wire) => _varint(field << 3 | wire);

  void int64(int field, int value) {
    if (value == 0) return;
    _tag(field, 0);
    _varint(value);
  }

  void boolean(int field, bool value) => int64(field, value ? 1 : 0);

  void bytes(int field, List<int> value, {bool force = false}) {
    if (value.isEmpty && !force) return;
    _tag(field, 2);
    _varint(value.length);
    _out.add(value);
  }

  void string(int field, String value) => bytes(field, utf8.encode(value));

  void message(int field, List<int> value) => bytes(field, value, force: true);

  void map(int field, Map<String, String> value) {
    for (final e in value.entries) {
      message(
        field,
        (_Pb()
              ..string(1, e.key)
              ..string(2, e.value))
            .toBytes(),
      );
    }
  }

  Uint8List toBytes() => _out.takeBytes();

  /// 读出顶层字段：varint 为 int，长度分隔为字节
  static Map<int, Object> read(Uint8List data) {
    final fields = <int, Object>{};
    var pos = 0;
    int varint() {
      var result = 0;
      var shift = 0;
      while (true) {
        final b = data[pos++];
        result |= (b & 0x7f) << shift;
        if (b < 0x80) return result;
        shift += 7;
      }
    }

    while (pos < data.length) {
      final tag = varint();
      switch (tag & 7) {
        case 0:
          fields[tag >> 3] = varint();
        case 2:
          final length = varint();
          fields[tag >> 3] = Uint8List.sublistView(data, pos, pos + length);
          pos += length;
        case 1:
          pos += 8;
        case 5:
          pos += 4;
        default:
          return fields;
      }
    }
    return fields;
  }
}