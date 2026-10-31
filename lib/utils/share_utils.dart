import 'dart:io' show Platform;

import 'package:PiliBro/http/constants.dart';
import 'package:PiliBro/utils/device_utils.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/rendering.dart' show Rect;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:share_plus/share_plus.dart';

abstract final class ShareUtils {
  static bool? _isIpad;
  static Future<bool> get isIpad async {
    return Platform.isIOS &&
        (_isIpad ??= (await DeviceInfoPlugin().iosInfo).model
            .toLowerCase()
            .contains('ipad'));
  }

  static Future<Rect?> get sharePositionOrigin async {
    if (await isIpad) {
      final screenSize = DeviceUtils.size;
      return Rect.fromLTRB(0, 0, screenSize.width, screenSize.height * 0.5);
    }
    return null;
  }

  /// [id] 形如 `av123` 或 `BV1xx`；[part] 为分 P 序号（从 1 起）
  static String videoUrl(String id, [int? part]) =>
      '${HttpString.baseUrl}/video/$id/${part != null ? '?p=$part' : ''}';

  /// 系统分享面板里的「分享视频」，所有入口共用同一份文案
  static Future<void> shareVideo(String? title, String? up, String url) =>
      shareText(up == null ? '$title - $url' : '$title UP主: $up - $url');

  static Future<void> shareText(String text) async {
    if (PlatformUtils.isDesktop) {
      Utils.copyText(text);
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: await sharePositionOrigin),
      );
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }
}
