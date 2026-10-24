import 'dart:convert';

import 'package:PiliBro/http/api.dart';
import 'package:PiliBro/http/init.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/models_new/login_devices/data.dart';
import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/accounts/account.dart';
import 'package:PiliBro/utils/app_sign.dart';
import 'package:PiliBro/utils/bili_device.dart';
import 'package:PiliBro/utils/bili_session.dart';
import 'package:PiliBro/utils/login_utils.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';

abstract final class LoginHttp {
  static final String deviceId = LoginUtils.genDeviceId();
  static String get buvid => LoginUtils.buvid;
  /// 短信、密码登录用短信 key，拿到的 token 归粉版
  static Map<String, String> get headers => {
    ...BiliDevice.appHeaders(BiliApp.sms, 0),
    ...BiliSession.dynamicHeaders,
    'content-type': 'application/x-www-form-urlencoded; charset=utf-8',
  };

  static const _deviceName = '${BiliDevice.brand}${BiliDevice.model}';
  static const _devicePlatform =
      'Android${BiliDevice.osVer}${BiliDevice.brand}${BiliDevice.model}';

  @pragma('vm:notify-debugger-on-exception')
  static Future<LoadingState<({String authCode, String url})>>
  getHDcode() async {
    final params = {
      // 'local_id': 'Y952A395BB157D305D8A8340FC2AAECECE17',
      'local_id': '0',
      'platform': 'android',
      'mobi_app': 'android_hd',
    };
    AppSign.appSign(params);
    final res = await Request().post(Api.getTVCode, queryParameters: params);

    if (res.data['code'] == 0) {
      try {
        final Map<String, dynamic> data = res.data['data'];
        return Success((authCode: data['auth_code'], url: data['url']));
      } catch (e, s) {
        return Error('$e\n\n$s');
      }
    } else {
      return Error(res.data['message']);
    }
  }

  /// 用账号的 cookie 换一份 HD token：申请电视端授权码，以本人身份确认，再取回 token
  static Future<LoadingState<void>> cookieToHdToken(
    LoginAccount account,
  ) async {
    final code = await getHDcode();
    if (code case final Error error) return error;
    final authCode = code.data.authCode;
    final res = await Request().post(
      Api.qrcodeConfirm,
      data: {
        'auth_code': authCode,
        'build': BiliApp.hd.build,
        'csrf': account.csrf,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        extra: {'account': account},
      ),
    );
    if (res.data['code'] != 0) return Error(res.data['message']);
    final poll = await codePoll(authCode);
    if (!poll['status']) return Error(poll['msg']);
    account.hdAccessKey = poll['data']['access_token'];
    await account.onChange();
    return const Success(null);
  }

  static Future codePoll(String authCode) async {
    final params = {
      'auth_code': authCode,
      'local_id': '0',
    };
    AppSign.appSign(params);
    final res = await Request().post(Api.qrcodePoll, queryParameters: params);
    return {
      'status': res.data['code'] == 0,
      'code': res.data['code'],
      'data': res.data['data'],
      'msg': res.data['message'],
    };
  }

  // static Future queryCaptcha() async {
  //   final res = await Request().get(Api.getCaptcha);
  //   if (res.data['code'] == 0) {
  //     return {
  //       'status': true,
  //       'data': CaptchaDataModel.fromJson(res.data['data']),
  //     };
  //   } else {
  //     return {'status': false, 'data': res.data['message']};
  //   }
  // }

  // 获取salt与PubKey
  static Future getWebKey() async {
    final res = await Request().get(Api.getWebKey);
    //data: {'disable_rcmd': 0, 'local_id': LoginUtils.generateBuvid()});
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false, 'data': {}, 'msg': res.data['message']};
    }
  }

  static Future sendSmsCode({
    required Object cid,
    required String tel,
    // String? deviceTouristId,
    String? geeChallenge,
    String? geeSeccode,
    String? geeValidate,
    String? recaptchaToken,
  }) async {
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = {
      ...BiliApp.sms.commonParams,
      'buvid': buvid,
      'cid': cid,
      // if (deviceTouristId != null) 'device_tourist_id': deviceTouristId,
      'disable_rcmd': '0',
      'gee_challenge': ?geeChallenge,
      'gee_seccode': ?geeSeccode,
      'gee_validate': ?geeValidate,
      'local_id': buvid,
      // https://chinggg.github.io/post/appre/
      'login_session_id': md5
          .convert(ascii.encode(buvid + timestamp.toString()))
          .toString(),
      'recaptcha_token': ?recaptchaToken,
      'tel': tel,
      'ts': (timestamp ~/ 1000).toString(),
    };
    AppSign.appSign(data, BiliApp.sms);

    final res = await Request().post(
      Api.appSmsCode,
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: headers,
      ),
    );

    if (res.data['code'] == 0 && res.data['data']['recaptcha_url'] == "") {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {
        'status': false,
        'code': res.data['code'],
        'msg': res.data['message'],
        'data': res.data['data'],
      };
    }
  }

  // static Future getGuestId(String key) async {
  //   dynamic publicKey = RSAKeyParser().parse(key);
  //   final params = {
  //     'appkey': Constants.appKey,
  //     'build': '2001100',
  //     'buvid': buvid,
  //     'c_locale': 'zh_CN',
  //     'channel': 'master',
  //     'deviceInfo': 'xxxxxx',
  //     'disable_rcmd': '0',
  //     'dt': Uri.encodeComponent(Encrypter(RSA(publicKey: publicKey))
  //         .encrypt(generateRandomString(16))
  //         .base64),
  //     'local_id': buvid,
  //     'mobi_app': 'android_hd',
  //     'platform': 'android',
  //     's_locale': 'zh_CN',
  //     'statistics': Constants.statistics,
  //     'ts': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
  //   };
  //   String sign = AppSign.appSign(
  //     params,
  //     Constants.appKey,
  //     Constants.appSec,
  //   );
  //   final res = await Request().post(Api.getGuestId,
  //       queryParameters: {...params, 'sign': sign},
  //       options: Options(
  //         contentType: Headers.formUrlEncodedContentType,
  //         headers: headers,
  //       ));
  //   print("getGuestId: $res");
  //   if (res.data['code'] == 0) {
  //     return {'status': true, 'data': res.data['data']};
  //   } else {
  //     return {'status': false, 'msg': res.data['message']};
  //   }
  // }

  // app端密码登录
  static Future loginByPwd({
    required String username,
    required String password,
    required String key,
    required String salt,
    String? geeChallenge,
    String? geeSeccode,
    String? geeValidate,
    String? recaptchaToken,
  }) async {
    dynamic publicKey = RSAKeyParser().parse(key);
    String passwordEncrypted = Encrypter(
      RSA(publicKey: publicKey),
    ).encrypt(salt + password).base64;

    final data = <String, dynamic>{
      ...BiliApp.sms.commonParams,
      'bili_local_id': deviceId,
      'buvid': buvid,
      'device': 'phone',
      'device_id': deviceId,
      //'device_meta': '',
      'device_name': _deviceName,
      'device_platform': _devicePlatform,
      'disable_rcmd': '0',
      'dt': Uri.encodeComponent(
        Encrypter(
          RSA(publicKey: publicKey),
        ).encrypt(Utils.generateRandomString(16)).base64,
      ),
      'from_pv': 'main.homepage.avatar-nologin.all.click',
      'from_url': Uri.encodeComponent('bilibili://pegasus/promo'),
      'gee_challenge': ?geeChallenge,
      'gee_seccode': ?geeSeccode,
      'gee_validate': ?geeValidate,
      'local_id': buvid, //LoginUtils.generateBuvid(),
      'password': passwordEncrypted,
      'permission': 'ALL',
      'recaptcha_token': ?recaptchaToken,
      'username': username,
    };
    AppSign.appSign(data, BiliApp.sms);
    final res = await Request().post(
      Api.loginByPwdApi,
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: headers,
        //responseType: ResponseType.plain
      ),
    );

    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': res.data['data'],
        'msg': res.data['message'],
      };
    } else {
      return {
        'status': false,
        'code': res.data['code'],
        'msg': res.data['message'],
        'data': res.data['data'],
      };
    }
  }

  // app端短信验证码登录
  static Future loginBySms({
    required String captchaKey,
    required String tel,
    required String code,
    required Object cid,
    required String key,
  }) async {
    dynamic publicKey = RSAKeyParser().parse(key);
    final data = <String, dynamic>{
      ...BiliApp.sms.commonParams,
      'bili_local_id': deviceId,
      'buvid': buvid,
      'captcha_key': captchaKey,
      'cid': cid,
      'code': code,
      'device': 'phone',
      'device_id': deviceId,
      //'device_meta': '',
      'device_name': _deviceName,
      'device_platform': _devicePlatform,
      // 'device_tourist_id': '',
      'disable_rcmd': '0',
      'dt': Uri.encodeComponent(
        Encrypter(
          RSA(publicKey: publicKey),
        ).encrypt(Utils.generateRandomString(16)).base64,
      ),
      'from_pv': 'main.my-information.my-login.0.click',
      'from_url': Uri.encodeComponent('bilibili://user_center/mine'),
      'local_id': buvid,
      'tel': tel,
    };
    AppSign.appSign(data, BiliApp.sms);
    final res = await Request().post(
      Api.logInByAppSms,
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: headers,
        //responseType: ResponseType.plain
      ),
    );

    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {
        'status': false,
        'code': res.data['code'],
        'msg': res.data['message'],
        'data': res.data['data'],
      };
    }
  }

  // 密码登录时风控验证手机
  static Future safeCenterGetInfo({
    required String tmpCode,
  }) async {
    final res = await Request().get(
      Api.safeCenterGetInfo,
      queryParameters: {
        'tmp_code': tmpCode,
      },
    );
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {
        'status': false,
        'code': res.data['code'],
        'msg': res.data['message'],
        'data': res.data['data'],
      };
    }
  }

  // 风控验证手机前的极验验证码
  static Future preCapture() async {
    final res = await Request().post(Api.preCapture);

    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {
        'status': false,
        'code': res.data['code'],
        'msg': res.data['message'],
        'data': res.data['data'],
      };
    }
  }

  // 风控验证手机：发送短信验证码
  static Future safeCenterSmsCode({
    String? smsType,
    required String tmpCode,
    String? geeChallenge,
    String? geeSeccode,
    String? geeValidate,
    String? recaptchaToken,
    required String refererUrl,
  }) async {
    Map<String, String> data = {
      'disable_rcmd': '0',
      'sms_type': smsType ?? 'loginTelCheck',
      'tmp_code': tmpCode,
      'gee_challenge': ?geeChallenge,
      'gee_seccode': ?geeSeccode,
      'gee_validate': ?geeValidate,
      'recaptcha_token': ?recaptchaToken,
    };
    AppSign.appSign(data, BiliApp.sms);
    final res = await Request().post(
      Api.safeCenterSmsCode,
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          "Referer": refererUrl,
        },
      ),
    );

    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {
        'status': false,
        'code': res.data['code'],
        'msg': res.data['message'],
        'data': res.data['data'],
      };
    }
  }

  // 风控验证手机：提交短信验证码
  static Future safeCenterSmsVerify({
    String? type,
    required String code,
    required String tmpCode,
    required String requestId,
    required String source,
    required String captchaKey,
    required String refererUrl,
  }) async {
    Map<String, String> data = {
      'type': type ?? 'loginTelCheck',
      'code': code,
      'tmp_code': tmpCode,
      'request_id': requestId,
      'source': source,
      'captcha_key': captchaKey,
    };
    AppSign.appSign(data, BiliApp.sms);
    final res = await Request().post(
      Api.safeCenterSmsVerify,
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          "Referer": refererUrl,
        },
      ),
    );

    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {
        'status': false,
        'code': res.data['code'],
        'msg': res.data['message'],
        'data': res.data['data'],
      };
    }
  }

  // 风控验证手机：用oauthCode换回accessToken
  static Future oauth2AccessToken({
    required String code,
  }) async {
    final data = <String, dynamic>{
      'build': BiliApp.sms.build,
      'buvid': buvid,
      'code': code,
      'disable_rcmd': '0',
      'grant_type': 'authorization_code',
      'local_id': buvid,
      'mobi_app': BiliApp.sms.mobiApp,
      'platform': 'android',
    };
    AppSign.appSign(data, BiliApp.sms);
    final res = await Request().post(
      Api.oauth2AccessToken,
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: headers,
      ),
    );

    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {
        'status': false,
        'code': res.data['code'],
        'msg': res.data['message'],
        'data': res.data['data'],
      };
    }
  }

  static Future<LoadingState<void>> logout(LoginAccount account) async {
    final res = await Request().post(
      Api.logout,
      data: {'biliCSRF': account.csrf},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        extra: {'account': account},
      ),
    );
    if (res.data['code'] == 0) {
      return const Success(null);
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<LoginDevicesData>> loginDevices() async {
    final account = Accounts.main;
    final buvid = LoginUtils.buvid;
    final app = account.app;
    final params = {
      'local_id': buvid,
      'buvid': buvid,
      'device_name': _deviceName,
      'device_platform': _devicePlatform,
      'csrf': account.csrf,
      'mobi_app': app.mobiApp,
      'platform': 'android',
      'access_key': account.accessKey,
      'statistics': app.statistics,
    };
    AppSign.appSign(params, app);
    final res = await Request().get(
      Api.loginDevices,
      queryParameters: params,
    );
    if (res.data['code'] == 0) {
      return Success(LoginDevicesData.fromJson(res.data['data']));
    } else {
      return Error(res.data['message']);
    }
  }
}
