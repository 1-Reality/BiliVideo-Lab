/*
 * This file is part of PiliBro
 *
 * PiliBro is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PiliBro is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with PiliBro.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flutter/widgets.dart';

class VideoProgressIndicator extends LeafRenderObjectWidget {
  const VideoProgressIndicator({
    super.key,
    required this.color,
    required this.backgroundColor,
    this.radius = 10,
    this.height = 4,
    required this.progress,
  });

  final Color color;
  final Color backgroundColor;
  final double radius;
  final double height;
  final double progress;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderProgressBar(
      color: color,
      backgroundColor: backgroundColor,
      radius: radius,
      height: height,
      progress: progress,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderProgressBar renderObject,
  ) {
    renderObject
      ..color = color
      ..backgroundColor = backgroundColor
      ..radius = radius
      ..height = height
      ..progress = progress;
  }
}

class RenderProgressBar extends RenderBox {
  RenderProgressBar({
    required this._color,
    required this._backgroundColor,
    required this._radius,
    required this._height,
    required this._progress,
  }) : _progressPaint = Paint()
         ..style = .fill
         ..color = _color,
       _backgroundPaint = Paint()
         ..style = .fill
         ..color = _backgroundColor;

  final Paint _progressPaint;
  final Paint _backgroundPaint;
  Size? _geometrySize;
  double? _geometryRadius;
  late Rect _clipRect;
  late RRect _rrect;

  Color _color;
  Color get color => _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    _progressPaint.color = value;
    markNeedsPaint();
  }

  Color _backgroundColor;
  Color get backgroundColor => _backgroundColor;
  set backgroundColor(Color value) {
    if (_backgroundColor == value) return;
    _backgroundColor = value;
    _backgroundPaint.color = value;
    markNeedsPaint();
  }

  double _progress;
  double get progress => _progress;
  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    markNeedsPaint();
  }

  double _radius;
  double get radius => _radius;
  set radius(double value) {
    if (_radius == value) return;
    _radius = value;
    markNeedsPaint();
  }

  double _height;
  double get height => _height;
  set height(double value) {
    if (_height == value) return;
    _height = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.constrainDimensions(constraints.maxWidth, _height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final size = this.size;
    final canvas = context.canvas;
    final hasOffset = offset != .zero;
    if (hasOffset) {
      canvas
        ..save()
        ..translate(offset.dx, offset.dy);
    }

    if (_geometrySize != size || _geometryRadius != _radius) {
      _geometrySize = size;
      _geometryRadius = _radius;
      _clipRect = Offset.zero & size;
      final radius = Radius.circular(_radius);
      _rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          0,
          -(_radius - size.height),
          size.width,
          _radius,
        ),
        bottomLeft: radius,
        bottomRight: radius,
      );
    }

    final progress = _progress;
    if (progress <= 0) {
      canvas
        ..clipRect(_clipRect)
        ..drawRRect(_rrect, _backgroundPaint);
    } else if (progress >= 1) {
      canvas
        ..clipRect(_clipRect)
        ..drawRRect(_rrect, _progressPaint);
    } else {
      final w = size.width * progress;
      final left = Rect.fromLTRB(0, 0, w, size.height);
      final right = Rect.fromLTRB(w, 0, size.width, size.height);
      canvas
        ..clipRRect(_rrect)
        ..drawRect(left, _progressPaint)
        ..drawRect(right, _backgroundPaint);
    }
    if (hasOffset) canvas.restore();
  }
}
