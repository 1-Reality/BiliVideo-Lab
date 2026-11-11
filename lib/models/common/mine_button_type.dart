import 'package:PiliBro/models/common/enum_with_label.dart';

enum MineButtonType implements EnumWithLabel {
  history('观看记录'),
  sub('我的订阅'),
  oneKeyListen('一键听歌'),
  later('稍后再看'),
  avSettings('音画设置'),
  networkPolicy('智能网优'),
  orientation('屏幕旋转'),
  creator('创作中心'),
  download('离线缓存'),
  audioSettings('特色播放'),
  playbackStats('播放统计');

  static const List<MineButtonType> kDefault = [
    .history,
    .oneKeyListen,
    .later,
    .avSettings,
    .networkPolicy,
    .orientation,
    .creator,
    .download,
    .audioSettings,
    .playbackStats,
  ];

  @override
  final String label;

  const MineButtonType(this.label);
}