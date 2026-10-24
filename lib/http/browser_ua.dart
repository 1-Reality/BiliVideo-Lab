import 'package:PiliBro/utils/bili_device.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/storage_pref.dart';

abstract final class BrowserUa {
  static String get platform {
    switch (Pref.webviewUaType) {
      case 1:
        return biliApp;
      case 2:
        if (Pref.webviewUaCustom case final ua when ua.isNotEmpty) return ua;
    }
    return PlatformUtils.isMobile ? mob : pc;
  }

  static const pc =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Safari/605.1.15';

  static const _webkit =
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.7339.207 Mobile Safari/537.36';

  static const mob =
      'Mozilla/5.0 (Linux; Android ${BiliDevice.osVer}; ${BiliDevice.model}) $_webkit';

  /// App 内置浏览器：旧版 8.43 的结构，机型换 Redmi K80 Ultra，内核用新 Chrome
  static const biliApp =
      'Mozilla/5.0 (Linux; Android 15; 25053RT47C) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.7339.207 Mobile Safari/537.36 os/android build/8430300 osVer/15 '
      'sdkInt/35 network/2 BiliApp/8430300 mobi_app/android_q channel/master innerVer/8430300';
}