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

import 'dart:math' show pi;

import 'package:flutter/semantics.dart' show SemanticsConfiguration;
import 'package:material_ui/material_ui.dart';

///
/// created by dom on 2026/02/14
///

class LoadingIndicator extends LeafRenderObjectWidget {
  const LoadingIndicator({
    super.key,
    required this.size,
    required this.progress,
  });

  final double size;
  final double progress;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLoadingIndicator(
      preferredSize: size,
      progress: progress,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLoadingIndicator renderObject,
  ) {
    renderObject
      ..preferredSize = size
      ..progress = progress;
  }
}

class RenderLoadingIndicator extends RenderBox {
  RenderLoadingIndicator({
    required this._preferredSize,
    required this._progress,
  });

  final _backgroundPaint = Paint()
    ..isAntiAlias = true
    ..style = .fill
    ..color = const Color(0x80000000);
  final _ringPaint = Paint()
    ..isAntiAlias = true
    ..style = .stroke
    ..strokeWidth = 1.4
    ..color = Colors.white;
  final _progressPaint = Paint()
    ..isAntiAlias = true
    ..style = .fill
    ..color = Colors.white;
  static const _fullRotation = pi * 2;

  late Offset _center;
  late double _radius;
  late Rect _progressRect;

  double _preferredSize;
  double get preferredSize => _preferredSize;
  set preferredSize(double value) {
    if (_preferredSize == value) return;
    _preferredSize = value;
    markNeedsLayout();
  }

  double _progress;
  double get progress => _progress;
  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void performLayout() {
    size = constraints.constrainDimensions(_preferredSize, _preferredSize);
    _radius = size.width * 0.5 - 1.4;
    _center = size.center(.zero);
    _progressRect = Rect.fromCircle(center: _center, radius: _radius - 8.0);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_progress == 0) {
      return;
    }
    const startAngle = -pi * 0.5;

    context.canvas
      ..drawCircle(
        _center,
        _radius,
        _backgroundPaint,
      )
      ..drawCircle(
        _center,
        _radius,
        _ringPaint,
      )
      ..drawArc(
        _progressRect,
        startAngle,
        progress * _fullRotation,
        true,
        _progressPaint,
      );
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..role = .progressBar
      ..minValue = '0'
      ..maxValue = '100'
      ..value = (_progress * 100).round().toString();
  }

  @override
  bool get isRepaintBoundary => true;
}
