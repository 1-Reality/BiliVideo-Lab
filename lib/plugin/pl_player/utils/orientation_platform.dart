import 'dart:io' show Platform;

import 'package:flutter/services.dart';

abstract final class OrientationPlatform {
  static const _channel = MethodChannel('pilibro/orientation');

  static Future<bool> systemAutoRotate() async {
    if (!Platform.isAndroid) return true;
    return await _channel.invokeMethod<bool>('systemAutoRotate') ?? true;
  }

  static Future<void> setAndroidRequestedOrientation(int value) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setRequestedOrientation', value);
  }

  static Future<int?> currentOrientationBit() async {
    if (!Platform.isAndroid) return null;
    final value = await _channel.invokeMethod<int>('currentOrientation');
    return switch (value) {
      AndroidRequestedOrientation.portrait => 1,
      AndroidRequestedOrientation.reversePortrait => 2,
      AndroidRequestedOrientation.landscape => 4,
      AndroidRequestedOrientation.reverseLandscape => 8,
      _ => null,
    };
  }
}

abstract final class AndroidRequestedOrientation {
  static const int unspecified = -1;
  static const int landscape = 0;
  static const int portrait = 1;
  static const int user = 2;
  static const int sensor = 4;
  static const int sensorLandscape = 6;
  static const int sensorPortrait = 7;
  static const int reverseLandscape = 8;
  static const int reversePortrait = 9;
  static const int fullSensor = 10;
  static const int fullUser = 13;
  static const int locked = 14;
}
