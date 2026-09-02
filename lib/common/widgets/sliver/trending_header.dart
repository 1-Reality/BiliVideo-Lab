import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/rendering.dart' show RenderSliverToBoxAdapter;
import 'package:material_ui/material_ui.dart';

class TrendingHeader extends SliverToBoxAdapter {
  const TrendingHeader({
    super.key,
    required this.offset,
    required this.onScrollRatioChanged,
    required super.child,
  });

  final double offset;
  final ValueChanged<double> onScrollRatioChanged;

  @override
  RenderSliverToBoxAdapter createRenderObject(BuildContext context) {
    return RenderTrendingHeader(
      offset: offset,
      onScrollRatioChanged: onScrollRatioChanged,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTrendingHeader renderObject,
  ) {
    renderObject.offset = offset;
  }
}

class RenderTrendingHeader extends RenderSliverToBoxAdapter {
  RenderTrendingHeader({
    required double offset,
    required this.onScrollRatioChanged,
  }) : _offset = offset,
       _inverseOffset = 1 / offset;

  double _offset;
  double _inverseOffset;
  double get offset => _offset;
  set offset(double value) {
    if (_offset == value) return;
    _offset = value;
    _inverseOffset = 1 / value;
    markNeedsLayout();
  }
  double? _scrollRatio;
  final ValueChanged<double> onScrollRatioChanged;

  @override
  void performLayout() {
    super.performLayout();
    final scrollOffset = constraints.scrollOffset;
    final scrollRatio = clampDouble(scrollOffset * _inverseOffset, 0.0, 1.0);
    if (_scrollRatio != scrollRatio) {
      _scrollRatio = scrollRatio;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onScrollRatioChanged(scrollRatio);
      });
    }
  }
}
