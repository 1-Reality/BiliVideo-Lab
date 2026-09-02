import 'package:PiliBro/common/widgets/flutter/refresh_indicator.dart'
    show displacement, kIndicatorSize;
import 'package:PiliBro/common/widgets/slotted_layout_helper.dart';
import 'package:flutter/rendering.dart' show BoxHitTestResult, ClipRectLayer;
import 'package:material_ui/material_ui.dart' hide RefreshIndicatorStatus;

enum RefreshType { indicator, body }

class RefreshLayout
    extends SlottedMultiChildRenderObjectWidget<RefreshType, RenderBox> {
  const RefreshLayout({
    super.key,
    required this.scale,
    required this.position,
    required this.indicator,
    required this.body,
  });

  final Animation<double> scale;
  final Animation<double> position;
  final Widget? indicator;
  final Widget body;

  @override
  Iterable<RefreshType> get slots => RefreshType.values;

  @override
  Widget? childForSlot(slot) => switch (slot) {
    .indicator => indicator,
    .body => body,
  };

  @override
  SlottedContainerRenderObjectMixin<RefreshType, RenderBox> createRenderObject(
    BuildContext context,
  ) {
    return RenderRefreshLayout(
      scale: scale,
      position: position,
    );
  }
}

class RenderRefreshLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<RefreshType, RenderBox> {
  RenderRefreshLayout({
    required this.scale,
    required this.position,
  }) {
    scale.addListener(_scaleListener);
    position.addListener(_positionListener);
  }

  final Animation<double> scale;

  final Animation<double> position;

  double _heightFactor = 0;
  double get heightFactor => _heightFactor;
  set heightFactor(double value) {
    if (_heightFactor == value) {
      return;
    }
    _heightFactor = value;
    _layoutIndicator();
    markNeedsPaint();
  }

  double _scaleFactor = 0;
  double get scaleFactor => _scaleFactor;
  set scaleFactor(double value) {
    if (_scaleFactor == value) {
      return;
    }
    _scaleFactor = value;
    _layoutIndicator();
    markNeedsPaint();
  }

  void _scaleListener() {
    scaleFactor = scale.value;
  }

  void _positionListener() {
    heightFactor = position.value;
  }

  late Rect _clipRect;
  Offset _indicatorOffset = .zero;
  late final _paintIndicatorCallback = _paintIndicator;

  void _paintIndicator(PaintingContext context, Offset offset) {
    final indicator = this.indicator;
    if (indicator != null) {
      context.paintChild(indicator, _indicatorOffset + offset);
    }
  }

  @override
  void dispose() {
    scale.removeListener(_scaleListener);
    position.removeListener(_positionListener);
    super.dispose();
  }

  RenderBox? get indicator => childForSlot(.indicator);
  RenderBox get body => childForSlot(.body)!;

  @override
  void performLayout() {
    final constraints = this.constraints;
    size = constraints.biggest;
    _clipRect = Offset.zero & size;

    final body = this.body..layout(constraints);
    setOffset(body, .zero);

    _layoutIndicator();
  }

  void _layoutIndicator() {
    final indicator = this.indicator;
    if (indicator == null) return;
    final scaleSize = kIndicatorSize * scaleFactor;
    indicator.layout(
      BoxConstraints.tightFor(width: scaleSize, height: scaleSize),
    );
    setOffset(
      indicator,
      Offset(
        (constraints.maxWidth - scaleSize) * 0.5,
        (kIndicatorSize + displacement) * heightFactor -
            kIndicatorSize +
            (kIndicatorSize - scaleSize) * 0.5,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(body, getOffset(body) + offset);
    final indicator = this.indicator;
    if (indicator != null && heightFactor > 0 && scaleFactor > 0) {
      final indicatorOffset = getOffset(indicator);
      if (indicatorOffset.dy > 0) {
        context.paintChild(indicator, indicatorOffset + offset);
        layer = null;
      } else {
        _indicatorOffset = indicatorOffset;
        layer = context.pushClipRect(
          needsCompositing,
          offset,
          _clipRect,
          _paintIndicatorCallback,
          clipBehavior: .hardEdge,
          oldLayer: layer as ClipRectLayer?,
        );
      }
    } else {
      layer = null;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final body = this.body;
    return result.addWithPaintOffset(
      offset: getOffset(body),
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        return body.hitTest(result, position: transformed);
      },
    );
  }
}
