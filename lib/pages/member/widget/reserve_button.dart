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

import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:flutter/widgets.dart';

class ReserveButton extends SingleChildRenderObjectWidget {
  const ReserveButton({
    super.key,
    required this.count,
    required this.color,
    required Widget super.child,
  });

  final int count;
  final Color color;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderReserveBtn(count: count, color: color);
  }

  @override
  void updateRenderObject(BuildContext context, RenderReserveBtn renderObject) {
    renderObject
      ..color = color
      ..count = count;
  }
}

class RenderReserveBtn extends RenderProxyBox {
  RenderReserveBtn({
    required int count,
    required this._color,
  }) : _count = count {
    _textPainter = TextPainter(
      textDirection: .ltr,
      text: _getTextSpan(count),
    )..layout();
  }

  int _count;
  int get count => _count;
  set count(int value) {
    if (_count == value) return;
    _count = value;
    _updateTextSpan();
    markNeedsPaint();
  }

  Color _color;
  Color get color => _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    _updateTextSpan();
    markNeedsPaint();
  }

  late final TextPainter _textPainter;
  Path? _path;
  Size? _pathSize;

  void _updateTextSpan() {
    _textPainter
      ..text = _getTextSpan(_count)
      ..layout();
  }

  TextSpan _getTextSpan(int count) {
    return TextSpan(
      text: count.toString(),
      style: TextStyle(
        height: 1,
        fontSize: 12,
        color: _color,
        fontWeight: .bold,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final size = this.size;
    if (_path == null || _pathSize != size) {
      final width = size.width;
      final height = size.height;
      _path = Path()
        ..moveTo(0, 0)
        ..lineTo(13.0, 0)
        ..lineTo(13.0, 14.0)
        ..lineTo(width, 14.0)
        ..lineTo(width, height)
        ..lineTo(0, height)
        ..close();
      _pathSize = size;
    }
    final canvas = context.canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..clipPath(_path!);
    context.paintChild(child!, .zero);
    canvas.restore();

    _textPainter.paint(canvas, Offset(offset.dx + 15.0, offset.dy));
  }

  @override
  void dispose() {
    _textPainter.dispose();
    super.dispose();
  }
}
