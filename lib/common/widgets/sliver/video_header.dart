import 'package:PiliBro/common/widgets/sliver/sliver_pinned_dynamic_header.dart';
import 'package:PiliBro/utils/extension/num_ext.dart';
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:material_ui/material_ui.dart';

class VideoHeader extends SliverPinnedDynamicHeader {
  const VideoHeader({
    super.key,
    required super.minExtent,
    required super.maxExtent,
    required this.minVideoHeight,
    required this.onScrollRatioChanged,
    required super.child,
  });

  final double minVideoHeight;
  final ValueChanged<double> onScrollRatioChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderVideoHeader(
      minExtent: minExtent,
      maxExtent: maxExtent,
      minVideoHeight: minVideoHeight,
      onScrollRatioChanged: onScrollRatioChanged,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderVideoHeader renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    renderObject.minVideoHeight = minVideoHeight;
  }
}

class RenderVideoHeader extends RenderSliverPinnedDynamicHeader {
  RenderVideoHeader({
    required super.minExtent,
    required super.maxExtent,
    required double minVideoHeight,
    required this.onScrollRatioChanged,
  }) : _minVideoHeight = minVideoHeight,
       _inverseScrollRange =
           1 / (minVideoHeight - kToolbarHeight).toPrecision(2);

  double? _scrollRatio;
  double _minVideoHeight;
  double _inverseScrollRange;
  double get minVideoHeight => _minVideoHeight;
  set minVideoHeight(double value) {
    if (_minVideoHeight == value) return;
    _minVideoHeight = value;
    _inverseScrollRange = 1 / (value - kToolbarHeight).toPrecision(2);
    markNeedsLayout();
  }
  final ValueChanged<double> onScrollRatioChanged;

  @override
  void performLayout() {
    super.performLayout();
    final scrollOffset = constraints.scrollOffset;
    final offset = scrollOffset - (maxExtent - minVideoHeight);
    final scrollRatio = clampDouble(
      offset.toPrecision(2) * _inverseScrollRange,
      0.0,
      1.0,
    );
    if (_scrollRatio != scrollRatio) {
      _scrollRatio = scrollRatio;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onScrollRatioChanged(scrollRatio);
      });
    }
  }
}
