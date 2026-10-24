import 'package:PiliBro/models/common/enum_with_label.dart';

/// 首页推荐来源：混合模式同时请求两端，交错排列、按视频去重
enum RcmdSource with EnumWithLabel {
  web('Web 端'),
  app('App 端'),
  merged('Web 与 App 混合'),
  ;

  @override
  final String label;
  const RcmdSource(this.label);
}