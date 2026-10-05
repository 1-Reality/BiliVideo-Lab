import 'dart:async' show Completer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:gt3_flutter_plugin/gt3_flutter_plugin.dart';

abstract final class GeetestPlugin {
  static Future geetest(String gt, String challenge) {
    final completer = Completer();
    void complete([result]) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    final registerData = Gt3RegisterData(
      challenge: challenge,
      gt: gt,
      success: true,
    );

    Gt3FlutterPlugin()
      ..addEventHandler(
        onShow: (Map<String, dynamic> message) {},
        onClose: (Map<String, dynamic> message) {
          SmartDialog.showToast('关闭验证');
          complete();
        },
        onResult: (Map<String, dynamic> message) {
          if (kDebugMode) debugPrint("Captcha result: $message");
          final String code = message["code"];
          if (code == "1") {
            complete(message['result']);
            return;
          }
          if (kDebugMode) debugPrint("Captcha result code : $code");
          complete();
        },
        onError: (Map<String, dynamic> message) {
          SmartDialog.showToast("Captcha onError: $message");
          final String code = message["code"];
          if (Platform.isAndroid) {
            if (code == "-2") {
            } else if (code == "-1") {
            } else if (code == "201") {
            } else if (code == "202") {
            } else if (code == "204") {
            } else if (code == "204_1") {
            } else if (code == "204_2") {
            } else if (code == "206") {
            } else if (code == "207") {
            } else if (code == "208") {
            }
          }
          if (Platform.isIOS) {
            if (code == "-1009") {
            } else if (code == "-1004") {
            } else if (code == "-1002") {
            } else if (code == "-1001") {
            } else if (code == "-999") {
            } else if (code == "-21") {
            } else if (code == "-20") {
            } else if (code == "-10") {
            } else if (code == "-2") {
            } else if (code == "-1") {
            }
          }
          complete();
        },
      )
      ..startCaptcha(registerData);

    return completer.future;
  }
}
