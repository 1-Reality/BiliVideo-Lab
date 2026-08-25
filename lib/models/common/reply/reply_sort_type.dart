import 'package:PiliPlus/models/common/enum_with_label.dart';

enum ReplySortType implements EnumWithLabel {
  time('最新评论', '最新', label: '按时间'),
  hot('最热评论', '最热', label: '按热度'),
  select('精选评论', '精选'),
  ;

  @override
  final String label;
  final String? text;
  const ReplySortType(this.title, this.label, {this.text});

  String get reply2Title => this == time ? '最早评论' : title;
}
