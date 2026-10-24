import 'dart:math';
import 'dart:ui' as ui;

import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:material_ui/material_ui.dart';

abstract final class DmUtils {
  static const maxRasterizeSize = 8192.0;

  static double devicePixelRatio = 1;
  static final Paint _selfSendPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = Colors.green;

  static void updateSelfSendPaint(double strokeWidth) {
    _selfSendPaint.strokeWidth = strokeWidth;
  }

  static String? fontFamily;

  /// 按数量标记的位置写入文本：隐藏、在前、在后
  static void _appendText(
    ui.ParagraphBuilder builder,
    DanmakuContentItem content,
    ui.TextStyle textStyle,
    ui.TextStyle countStyle,
  ) {
    void text() => builder
      ..pushStyle(textStyle)
      ..addText(content.text)
      ..pop();
    void count(int n) => builder
      ..pushStyle(countStyle)
      ..addText('($n)')
      ..pop();
    final n = content.count;
    if (n == null || content.countPosition == DanmakuCountPosition.hidden) {
      text();
    } else if (content.countPosition == DanmakuCountPosition.head) {
      count(n);
      text();
    } else {
      text();
      count(n);
    }
  }

  static ui.Paragraph generateParagraph({
    required DanmakuContentItem content,
    required double fontSize,
    required int fontWeight,
  }) {
    final size = content.fontSize ?? fontSize;
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontWeight: FontWeight.values[fontWeight],
      textDirection: TextDirection.ltr,
      fontFamily: fontFamily,
      maxLines: 1,
    ));

    _appendText(
      builder,
      content,
      ui.TextStyle(color: content.color, fontSize: size),
      ui.TextStyle(color: content.color, fontSize: size * 0.6),
    );

    return builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
  }

  static ui.Image recordDanmakuImage({
    required ui.Paragraph contentParagraph,
    required DanmakuContentItem content,
    required double fontSize,
    required int fontWeight,
    required double strokeWidth,
  }) {
    double w = contentParagraph.maxIntrinsicWidth + strokeWidth;
    double h = contentParagraph.height + strokeWidth;

    final offset = Offset(
      (strokeWidth / 2.0) + (content.selfSend ? 2.0 : 0.0),
      strokeWidth / 2.0,
    );

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    if (devicePixelRatio != 1) {
      canvas.scale(devicePixelRatio);
    }

    if (strokeWidth != 0) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontWeight: FontWeight.values[fontWeight],
        textDirection: TextDirection.ltr,
        fontFamily: fontFamily,
        maxLines: 1,
      ));
      final Paint strokePaint = Paint()
        ..shader = content.isColorful
            ? const LinearGradient(
                    colors: [Color(0xFFF2509E), Color(0xFF308BCD)])
                .createShader(Rect.fromLTWH(0, 0, w, h))
            : null
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      if (!content.isColorful) {
        strokePaint.color = Colors.black;
      }

      final size = content.fontSize ?? fontSize;
      _appendText(
        builder,
        content,
        ui.TextStyle(fontSize: size, foreground: strokePaint),
        ui.TextStyle(fontSize: size * 0.6, foreground: strokePaint),
      );

      final strokeParagraph = builder.build()
        ..layout(const ui.ParagraphConstraints(width: double.infinity));

      canvas.drawParagraph(strokeParagraph, offset);
      strokeParagraph.dispose();
    }

    canvas.drawParagraph(contentParagraph, offset);

    if (content.selfSend) {
      w += 4;
      canvas.drawRect(Rect.fromLTRB(0, 0, w, h), _selfSendPaint);
    }

    final pic = rec.endRecording();
    final img = pic.toImageSync(
      (w * devicePixelRatio).ceil(),
      (h * devicePixelRatio).ceil(),
    );
    pic.dispose();
    return img;
  }

  static ui.Image recordSpecialDanmakuImg({
    required SpecialDanmakuContentItem content,
    required int fontWeight,
    required double strokeWidth,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontWeight: FontWeight.values[fontWeight],
      textDirection: TextDirection.ltr,
      fontSize: content.fontSize,
      fontFamily: fontFamily,
    ))
      ..pushStyle(ui.TextStyle(
        color: content.color,
        fontSize: content.fontSize,
        shadows: content.hasStroke
            ? [Shadow(color: Colors.black, blurRadius: strokeWidth)]
            : null,
      ))
      ..addText(content.text);

    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));

    final strokeOffset = strokeWidth / 2;
    final totalWidth = paragraph.maxIntrinsicWidth + strokeWidth;
    final totalHeight = paragraph.height + strokeWidth;

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);

    Rect rect;

    if (content.rotateZ != 0 || content.matrix != null) {
      rect = _calculateRotatedBounds(
        totalWidth,
        totalHeight,
        content.rotateZ,
        content.matrix,
      );

      if (devicePixelRatio != 1) {
        canvas.scale(devicePixelRatio);
      }
      canvas.translate(strokeOffset - rect.left, strokeOffset - rect.top);

      if (content.matrix case final matrix?) {
        canvas.transform(matrix.storage);
      } else {
        canvas.rotate(content.rotateZ);
      }
      canvas.drawParagraph(paragraph, Offset.zero);
    } else {
      rect = Rect.fromLTRB(0, 0, totalWidth, totalHeight);

      if (devicePixelRatio != 1) {
        canvas.scale(devicePixelRatio);
      }
      canvas.drawParagraph(paragraph, Offset(strokeOffset, strokeOffset));
    }
    paragraph.dispose();

    double width = rect.width * devicePixelRatio;
    double height = rect.height * devicePixelRatio;
    if (width > maxRasterizeSize || height > maxRasterizeSize) {
      final scaledMaxSize = maxRasterizeSize / devicePixelRatio;
      final left = rect.left;
      final top = rect.top;
      double right = rect.right;
      double bottom = rect.bottom;

      if (width > maxRasterizeSize) {
        right = left + scaledMaxSize;
        width = maxRasterizeSize;
      }

      if (height > maxRasterizeSize) {
        bottom = top + scaledMaxSize;
        height = maxRasterizeSize;
      }

      rect = Rect.fromLTRB(left, top, right, bottom);
    }

    content.rect = rect;

    final pic = rec.endRecording();
    final img = pic.toImageSync(width.ceil(), height.ceil());
    pic.dispose();

    return img;
  }

  static Rect _calculateRotatedBounds(
    double w,
    double h,
    double rotateZ,
    Matrix4? matrix,
  ) {
    final double cosZ;
    final double cosY;
    final double sinZ;
    if (matrix == null) {
      cosZ = cos(rotateZ);
      sinZ = sin(rotateZ);
      cosY = 1;
    } else {
      cosZ = matrix[5];
      sinZ = matrix[1];
      cosY = matrix[10];
    }

    final wx = w * cosZ * cosY;
    final wy = w * sinZ;
    final hx = -h * sinZ * cosY;
    final hy = h * cosZ;

    final minX = _min4(0.0, wx, hx, wx + hx);
    final maxX = _max4(0.0, wx, hx, wx + hx);
    final minY = _min4(0.0, wy, hy, wy + hy);
    final maxY = _max4(0.0, wy, hy, wy + hy);

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @pragma("vm:prefer-inline")
  static double _min4(double a, double b, double c, double d) {
    final ab = a < b ? a : b;
    final cd = c < d ? c : d;
    return ab < cd ? ab : cd;
  }

  @pragma("vm:prefer-inline")
  static double _max4(double a, double b, double c, double d) {
    final ab = a > b ? a : b;
    final cd = c > d ? c : d;
    return ab > cd ? ab : cd;
  }
}
