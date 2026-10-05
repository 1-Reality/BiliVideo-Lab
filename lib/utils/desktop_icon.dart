import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

abstract final class DesktopIcon {
  static const _channel = MethodChannel('pilibro/desktop_icon');

  static Future<int> chooseAndSet() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: [
        'png',
        'jpg',
        'jpeg',
        'ico',
        'webp',
        'bmp',
      ],
    );
    if (file == null) return 0;

    final bytes = await file.readAsBytes();
    final iconBytes = await compute(_prepareIcon, bytes);
    if (iconBytes == null) {
      throw const FormatException('无法识别这个图片文件');
    }

    return await _channel.invokeMethod<int>(
          'setCustomDesktopIcon',
          {'bytes': iconBytes},
        ) ??
        0;
  }

  static Uint8List? _prepareIcon(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    final rgba = image.convert(numChannels: 4, noAnimation: true);
    final icon = img.copyResize(
      rgba,
      width: 512,
      height: 512,
      maintainAspect: true,
      backgroundColor: img.ColorRgba8(0, 0, 0, 0),
      interpolation: img.Interpolation.linear,
    );
    return img.encodePng(icon);
  }
}
