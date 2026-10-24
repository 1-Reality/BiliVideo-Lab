import 'package:PiliBro/models/common/enum_with_label.dart';

/// 推荐过滤器的作用范围，序号即位掩码：位 0 首页（推荐、热门、排行），位 1 详情页相关视频
enum RcmdFilterScope with EnumWithLabel {
  off('关闭'),
  home('首页'),
  detail('详情'),
  all('全部')
  ;

  @override
  final String label;
  const RcmdFilterScope(this.label);
}