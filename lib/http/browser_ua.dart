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

  static const mob =
      'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Mobile Safari/537.36';

  static const biliApp =
      'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Mobile Safari/537.36 os/android build/8430300 osVer/10 sdkInt/29 network/2 BiliApp/8430300 mobi_app/android_q channel/master innerVer/8430300';
}
