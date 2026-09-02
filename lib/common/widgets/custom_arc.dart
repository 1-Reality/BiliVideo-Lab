import 'dart:math' show pi;

import 'package:flutter/widgets.dart';

class Arc extends LeafRenderObjectWidget {
  const Arc({
    super.key,
    required this.size,
    required this.color,
    required this.progress,
    this.strokeWidth = 2,
  });

  final double size;
  final Color color;
  final double progress;
  final double strokeWidth;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderArc(
      preferredSize: size,
      color: color,
      progress: progress,
      strokeWidth: strokeWidth,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderArc renderObject,
  ) {
    renderObject
      ..preferredSize = size
      ..color = color
      ..progress = progress
      ..strokeWidth = strokeWidth;
  }
}

class RenderArc extends RenderBox {
  RenderArc({
    required this._preferredSize,
    required this._color,
    required this._progress,
    required this._strokeWidth,
  }) : _paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = _color
      ..strokeWidth = _strokeWidth;

  final Paint _paint;

  Color _color;
  Color get color => _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    _paint.color = value;
    markNeedsPaint();
  }

  double _progress;
  double get progress => _progress;
  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    markNeedsPaint();
  }

  double _strokeWidth;
  double get strokeWidth => _strokeWidth;
  set strokeWidth(double value) {
    if (_strokeWidth == value) return;
    _strokeWidth = value;
    _paint.strokeWidth = value;
    markNeedsPaint();
  }

  double _preferredSize;
  double get preferredSize => _preferredSize;
  set preferredSize(double value) {
    if (_preferredSize == value) return;
    _preferredSize = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.constrainDimensions(_preferredSize, _preferredSize);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (progress == 0) {
      return;
    }

    final radius = size.width * 0.5;
    final rect = Rect.fromCircle(
      center: Offset(radius, radius),
      radius: radius,
    );

    const startAngle = -pi * 0.5;
    context.canvas.drawArc(rect, startAngle, progress * 2 * pi, false, _paint);
  }

  @override
  bool get isRepaintBoundary => true;
}
