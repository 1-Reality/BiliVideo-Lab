import 'package:PiliBro/utils/bili_device.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/storage_pref.dart';

abstract final class BrowserUa {
  static String get platform {
    switch (Pref.webviewUaType) {
      case 1:
        return bili;
      case 2:
        if (Pref.webviewUaCustom case final ua when ua.isNotEmpty) return ua;
      case 3:
        return biliApp;
      case 4:
        return biliWeb;
    }
    return PlatformUtils.isMobile ? mob : pc;
  }

  static const pc =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Safari/605.1.15';

  static const _webkit =
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.7339.207 Mobile Safari/537.36';

  static const mob =
      'Mozilla/5.0 (Linux; Android ${BiliDevice.osVer}; ${BiliDevice.model}) $_webkit';

  /// 旧版 8.43 的结构，机型 Redmi K80 Ultra，内核新 Chrome
  static const bili =
      'Mozilla/5.0 (Linux; Android 15; 25053RT47C) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.7339.207 Mobile Safari/537.36 os/android build/8430300 osVer/15 '
      'sdkInt/35 network/2 BiliApp/8430300 mobi_app/android_q channel/master innerVer/8430300';

  /// 粉版 App 内置 WebView。mobi_app/android 会让创作中心被引导到 App
  static const biliApp =
      'Mozilla/5.0 (Linux; Android ${BiliDevice.osVer}; ${BiliDevice.model} '
      'Build/${BiliDevice.buildId}; wv) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Version/4.0 Chrome/140.0.7339.207 Mobile Safari/537.36 os/android '
      'model/${BiliDevice.model} build/$phoneBuild osVer/${BiliDevice.osVer} '
      'sdkInt/36 network/2 BiliApp/$phoneBuild mobi_app/android '
      'channel/${BiliDevice.channel} innerVer/$phoneBuild';

  /// 与 biliApp 只差两处：去掉 Mobile，mobi_app 用 android_q
  static const biliWeb =
      'Mozilla/5.0 (Linux; Android ${BiliDevice.osVer}; ${BiliDevice.model} '
      'Build/${BiliDevice.buildId}; wv) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Version/4.0 Chrome/140.0.7339.207 Safari/537.36 os/android '
      'model/${BiliDevice.model} build/$phoneBuild osVer/${BiliDevice.osVer} '
      'sdkInt/36 network/2 BiliApp/$phoneBuild mobi_app/android_q '
      'channel/${BiliDevice.channel} innerVer/$phoneBuild';
}