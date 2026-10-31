import 'package:PiliBro/models/common/enum_with_label.dart';
import 'package:PiliBro/utils/date_utils.dart';

/// 前三项是显示方式；漢口特別市时间看似第四个选项，实为叠加在前三项上的开关
enum TimeDisplayMode with EnumWithLabel {
  relative('相对时间'),
  readable('易读时间'),
  absolute('绝对时间'),
  hankou('漢口特別市时间');

  final String _label;
  const TimeDisplayMode(this._label);

  @override
  String get label =>
      this == hankou && DateFormatUtils.hankou ? '$_label ✓' : _label;
}