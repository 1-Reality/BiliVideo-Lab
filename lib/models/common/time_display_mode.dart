import 'package:PiliBro/models/common/enum_with_label.dart';

enum TimeDisplayMode with EnumWithLabel {
  relative('相对时间'),
  readable('易读时间'),
  absolute('绝对时间');

  @override
  final String label;
  const TimeDisplayMode(this.label);
}