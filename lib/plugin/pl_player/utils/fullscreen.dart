import 'dart:async';
import 'dart:io' show Platform;

import 'package:PiliBro/plugin/pl_player/models/orientation_mode.dart';
import 'package:PiliBro/plugin/pl_player/utils/orientation_platform.dart';
import 'package:PiliBro/utils/device_utils.dart';
import 'package:flutter/services.dart'
    show SystemChrome, MethodChannel, SystemUiOverlay, DeviceOrientation;

bool _isDesktopFullScreen = false;

@pragma('vm:notify-debugger-on-exception')
Future<void> enterDesktopFullScreen({bool inAppFullScreen = false}) async {
  if (!inAppFullScreen && !_isDesktopFullScreen) {
    _isDesktopFullScreen = true;
    try {
      await const MethodChannel(
        'com.alexmercerind/media_kit_video',
      ).invokeMethod('Utils.EnterNativeFullscreen');
    } catch (_) {}
  }
}

@pragma('vm:notify-debugger-on-exception')
Future<void> exitDesktopFullScreen() async {
  if (_isDesktopFullScreen) {
    _isDesktopFullScreen = false;
    try {
      await const MethodChannel(
        'com.alexmercerind/media_kit_video',
      ).invokeMethod('Utils.ExitNativeFullscreen');
    } catch (_) {}
  }
}

int? _lastOrientationRequest;

Future<void>? _setPreferredOrientations(
  int request,
  List<DeviceOrientation> orientations,
) {
  final key = 0x20000 | request;
  if (_lastOrientationRequest == key) return null;
  _lastOrientationRequest = key;
  return SystemChrome.setPreferredOrientations(orientations);
}

Future<void>? _setAndroidOrientation(int request) {
  final key = 0x10000 | (request & 0xFFFF);
  if (_lastOrientationRequest == key) return null;
  _lastOrientationRequest = key;
  return OrientationPlatform.setAndroidRequestedOrientation(request);
}

Future<void>? portraitUpMode() {
  if (Platform.isAndroid) {
    return _setAndroidOrientation(AndroidRequestedOrientation.portrait);
  }
  return _setPreferredOrientations(1, const [.portraitUp]);
}

Future<void>? portraitDownMode() {
  if (Platform.isAndroid) {
    return _setAndroidOrientation(AndroidRequestedOrientation.reversePortrait);
  }
  return _setPreferredOrientations(2, const [.portraitDown]);
}

Future<void>? landscapeLeftMode() {
  if (Platform.isAndroid) {
    return _setPreferredOrientations(4, const [.landscapeLeft]);
  }
  return _setPreferredOrientations(4, const [.landscapeLeft]);
}

Future<void>? landscapeRightMode() {
  if (Platform.isAndroid) {
    return _setPreferredOrientations(8, const [.landscapeRight]);
  }
  return _setPreferredOrientations(8, const [.landscapeRight]);
}

Future<void>? fullMode() {
  if (Platform.isAndroid) {
    return _setAndroidOrientation(AndroidRequestedOrientation.fullUser);
  }
  return _setPreferredOrientations(
    OrientationMask.all,
    const [.portraitUp, .portraitDown, .landscapeLeft, .landscapeRight],
  );
}

Future<void>? userMode() {
  if (Platform.isAndroid) {
    return _setAndroidOrientation(AndroidRequestedOrientation.user);
  }
  return fullMode();
}

Future<void>? followSystemMode() {
  if (Platform.isAndroid) {
    return _setAndroidOrientation(AndroidRequestedOrientation.unspecified);
  }
  return _setPreferredOrientations(16, const []);
}

Future<void>? fullSensorMode() {
  if (Platform.isAndroid) {
    return _setAndroidOrientation(AndroidRequestedOrientation.fullSensor);
  }
  return fullMode();
}

Future<void>? lockedMode() {
  if (Platform.isAndroid) {
    return _setAndroidOrientation(AndroidRequestedOrientation.locked);
  }
  return null;
}

Future<void>? applyAutoOrientationMask(
  int mask, {
  required bool ignoreSystemLock,
}) {
  if (!Platform.isAndroid) {
    final orientations = <DeviceOrientation>[
      if (mask & OrientationMask.portraitUp != 0) .portraitUp,
      if (mask & OrientationMask.portraitDown != 0) .portraitDown,
      if (mask & OrientationMask.landscapeLeft != 0) .landscapeLeft,
      if (mask & OrientationMask.landscapeRight != 0) .landscapeRight,
    ];
    return _setPreferredOrientations(32 | mask, orientations);
  }

  if (ignoreSystemLock) {
    final request = switch (mask) {
      OrientationMask.all => AndroidRequestedOrientation.fullSensor,
      OrientationMask.portrait => AndroidRequestedOrientation.sensorPortrait,
      OrientationMask.landscape => AndroidRequestedOrientation.sensorLandscape,
      13 => AndroidRequestedOrientation.sensor,
      OrientationMask.portraitUp => AndroidRequestedOrientation.portrait,
      OrientationMask.portraitDown =>
        AndroidRequestedOrientation.reversePortrait,
      OrientationMask.landscapeLeft =>
        AndroidRequestedOrientation.landscape,
      OrientationMask.landscapeRight =>
        AndroidRequestedOrientation.reverseLandscape,
      _ => null,
    };
    return request == null
        ? fullSensorMode()
        : _setAndroidOrientation(request);
  }

  final orientations = switch (mask) {
    OrientationMask.portraitUp => const [DeviceOrientation.portraitUp],
    OrientationMask.portraitDown => const [DeviceOrientation.portraitDown],
    OrientationMask.landscapeLeft => const [DeviceOrientation.landscapeLeft],
    OrientationMask.landscapeRight => const [DeviceOrientation.landscapeRight],
    OrientationMask.portrait => const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    OrientationMask.landscape => const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    13 => const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    OrientationMask.all => const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    _ => null,
  };
  return orientations == null
      ? followSystemMode()
      : _setPreferredOrientations(64 | mask, orientations);
}

bool _showSystemBar = true;
bool get showSystemBar_ => _showSystemBar;
Future<void>? hideSystemBar() {
  if (!_showSystemBar) {
    return null;
  }
  _showSystemBar = false;
  return SystemChrome.setEnabledSystemUIMode(.immersiveSticky);
}

//退出全屏显示
Future<void>? showSystemBar() {
  if (_showSystemBar) {
    return null;
  }
  _showSystemBar = true;
  return SystemChrome.setEnabledSystemUIMode(
    Platform.isAndroid && DeviceUtils.sdkInt < 29 ? .manual : .edgeToEdge,
    overlays: SystemUiOverlay.values,
  );
}
