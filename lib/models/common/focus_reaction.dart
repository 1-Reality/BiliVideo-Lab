import 'package:PiliBro/models/common/enum_with_label.dart';

/// 其他 App 出声时怎么反应；压低多少见「压低到」
enum FocusReaction with EnumWithLabel {
  ignore('不变'),
  duck('压低音量'),
  pause('暂停'),
  ;

  @override
  final String label;
  const FocusReaction(this.label);
}