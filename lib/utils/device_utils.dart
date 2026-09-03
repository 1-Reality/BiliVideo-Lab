import 'package:PiliBro/utils/android/bindings.g.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, Size;

abstract final class DeviceUtils {
  static final int sdkInt = AndroidHelper.sdkInt();

  static bool get isTablet {
    return size.shortestSide >= 600;
  }

  static Size get size {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return view.physicalSize * (1 / view.devicePixelRatio);
  }

  static String get platformName => PlatformUtils.isDesktop
      ? 'desktop'
      : isTablet
      ? 'pad'
      : 'phone';
}
