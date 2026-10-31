import 'package:PiliBro/models/common/enum_with_label.dart';

enum AutoFullscreenMode implements EnumWithLabel {
  off('关闭'),
  landscape('屏幕横着时'),
  sameAxis('屏幕与视频方向相同时'),
  always('总是'),
  ;

  @override
  final String label;
  const AutoFullscreenMode(this.label);

  bool allows({required bool screenLandscape, required bool videoVertical}) =>
      switch (this) {
        off => false,
        landscape => screenLandscape,
        sameAxis => screenLandscape != videoVertical,
        always => true,
      };
}