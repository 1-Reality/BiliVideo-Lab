import 'package:PiliBro/models/common/video/base_quality.dart';
import 'package:PiliBro/models_new/live/live_room_play_info/codec.dart';

class Format {
  String? formatName;
  List<CodecItem> codec;

  Format({
    this.formatName,
    required this.codec,
  });

  factory Format.fromJson(
    Map<String, dynamic> json,
    List<LiveQuality>? liveQn,
  ) => Format(
    formatName: json['format_name'],
    codec: (json['codec'] as List<dynamic>)
        .map((e) => CodecItem.fromJson(e as Map<String, dynamic>, liveQn))
        .toList(),
  );
}
