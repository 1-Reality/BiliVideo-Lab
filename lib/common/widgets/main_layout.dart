import 'package:PiliBro/common/widgets/slotted_layout_helper.dart';
import 'package:flutter/rendering.dart' show ChildLayoutHelper;
import 'package:material_ui/material_ui.dart';

// Order is also hit-test order: the mini player sits above the body.
enum MainType { sideBar, bottomNav, miniPlayer, body }

class MainLayout
    extends SlottedMultiChildRenderObjectWidget<MainType, RenderBox> {
  const MainLayout({
    super.key,
    required this.sideBar,
    required this.bottomNav,
    required this.body,
    this.miniPlayer,
  });

  final Widget? sideBar;
  final Widget? bottomNav;
  final Widget body;

  /// Laid out at its own size, horizontally centred over the body and resting
  /// on top of the bottom navigation (or the bottom edge without one).
  final Widget? miniPlayer;

  @override
  Iterable<MainType> get slots => MainType.values;

  @override
  Widget? childForSlot(slot) => switch (slot) {
    .sideBar => sideBar,
    .bottomNav => bottomNav,
    .miniPlayer => miniPlayer,
    .body => body,
  };

  @override
  SlottedContainerRenderObjectMixin<MainType, RenderBox> createRenderObject(
    BuildContext context,
  ) {
    return _RenderMainLayout();
  }
}

class _RenderMainLayout extends RenderBox
    with
        SlottedContainerRenderObjectMixin<MainType, RenderBox>,
        SlottedLayoutMixin {
  RenderBox? get sideBar => childForSlot(.sideBar);
  RenderBox? get bottomNav => childForSlot(.bottomNav);
  RenderBox get body => childForSlot(.body)!;
  RenderBox? get miniPlayer => childForSlot(.miniPlayer);

  @override
  Iterable<MainType> get slots => MainType.values;

  @override
  void performLayout() {
    final constraints = this.constraints;
    size = constraints.biggest;

    final Offset bodyOffset;
    final BoxConstraints bodyConstraints;
    var bottomNavHeight = 0.0;

    final sideBar = this.sideBar;
    if (sideBar != null) {
      final sideBarWidth = ChildLayoutHelper.layoutChild(
        sideBar,
        BoxConstraints.tightFor(height: constraints.maxHeight),
      ).width;
      setOffset(sideBar, .zero);

      bodyOffset = Offset(sideBarWidth, 0);
      bodyConstraints = BoxConstraints.tightFor(
        width: constraints.maxWidth - sideBarWidth,
        height: constraints.maxHeight,
      );
    } else {
      final bottomNav = this.bottomNav;
      if (bottomNav != null) {
        final bottomNavSize = ChildLayoutHelper.layoutChild(
          bottomNav,
          constraints.loosen(),
        );
        setOffset(
          bottomNav,
          Offset(
            (constraints.maxWidth - bottomNavSize.width) * 0.5,
            constraints.maxHeight - bottomNavSize.height,
          ),
        );
        bottomNavHeight = bottomNavSize.height;
      }

      bodyOffset = .zero;
      bodyConstraints = BoxConstraints.tightFor(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
      );
    }

    final body = this.body..layout(bodyConstraints);
    setOffset(body, bodyOffset);

    if (miniPlayer case final child?) {
      final size = ChildLayoutHelper.layoutChild(
        child,
        BoxConstraints(
          maxWidth: bodyConstraints.maxWidth,
          maxHeight: bodyConstraints.maxHeight - bottomNavHeight,
        ),
      );
      setOffset(
        child,
        Offset(
          bodyOffset.dx + (bodyConstraints.maxWidth - size.width) * 0.5,
          constraints.maxHeight - bottomNavHeight - size.height,
        ),
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (sideBar case final child?) {
      context.paintChild(child, getOffset(child) + offset);
    }
    context.paintChild(body, getOffset(body) + offset);
    if (miniPlayer case final child?) {
      context.paintChild(child, getOffset(child) + offset);
    }
    if (bottomNav case final child?) {
      context.paintChild(child, getOffset(child) + offset);
    }
  }
}
