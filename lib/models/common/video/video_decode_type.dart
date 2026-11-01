// ignore_for_file: constant_identifier_names

enum VideoDecodeFormatType {
  DVH1(['dvh1'], 'DV'),
  AV1(['av01'], 'AV1'),
  HEVC(['hev1', 'hvc1'], '265'),
  AVC(['avc1'], '264'),
  ;

  String get description => name;
  final List<String> codes;

  /// 播放器顶栏按钮下的简称
  final String label;

  const VideoDecodeFormatType(this.codes, this.label);

  static VideoDecodeFormatType fromString(String val) =>
      values.firstWhere((i) => i.codes.any(val.startsWith));
}
