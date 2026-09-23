import 'dart:io' show Platform;

import 'package:flutter/services.dart' show MethodChannel;

final class FirstRunDeviceHints {
  const FirstRunDeviceHints({
    required this.leanback,
    required this.televisionUiMode,
    required this.touchscreen,
    required this.hingeAngle,
    required this.telephony,
    required this.telephonyCalling,
    required this.voiceCapable,
  });

  final bool leanback;
  final bool televisionUiMode;
  final bool touchscreen;
  final bool hingeAngle;
  final bool telephony;
  final bool telephonyCalling;
  final bool voiceCapable;

  bool get television => leanback || televisionUiMode;
  bool get phoneCapable =>
      telephony && (telephonyCalling || voiceCapable);
}

abstract final class DeviceFormFactorPlatform {
  static const _channel = MethodChannel('pilibro/device');

  static Future<FirstRunDeviceHints> firstRunHints() async {
    if (!Platform.isAndroid) {
      return const FirstRunDeviceHints(
        leanback: false,
        televisionUiMode: false,
        touchscreen: true,
        hingeAngle: false,
        telephony: false,
        telephonyCalling: false,
        voiceCapable: false,
      );
    }
    final raw =
        await _channel.invokeMapMethod<String, dynamic>('firstRunHints') ??
        const <String, dynamic>{};
    bool flag(String key) => raw[key] == true;
    return FirstRunDeviceHints(
      leanback: flag('leanback'),
      televisionUiMode: flag('televisionUiMode'),
      touchscreen: flag('touchscreen'),
      hingeAngle: flag('hingeAngle'),
      telephony: flag('telephony'),
      telephonyCalling: flag('telephonyCalling'),
      voiceCapable: flag('voiceCapable'),
    );
  }
}
