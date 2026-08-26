import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/services/cdn_diagnostics_service.dart';
import 'package:material_ui/material_ui.dart';

Future<CDNService?> showPlaybackCdnDialog(
  BuildContext context, {
  required CDNService current,
  required bool locked,
}) {
  final groups = CdnDiagnosticsService.groupedSnapshot();
  final latest = groups.isEmpty ? null : groups.first;
  final byName = <String, Map>{};
  if (latest != null) {
    for (final record in latest.records) {
      final cdn = record['cdn'];
      if (cdn is Map && cdn['name'] != null) {
        byName[cdn['name'].toString()] = record;
      }
    }
  }

  String resultText(CDNService cdn) {
    final record = byName[cdn.name];
    if (record == null) return '上轮：无结果';
    final sample = record['sample'] is Map ? record['sample'] as Map : const {};
    final error = sample['error'];
    if (error != null) return '上轮：$error';
    final derived =
        record['derived'] is Map ? record['derived'] as Map : const {};
    final bytesPerSecond =
        (derived['averageRateBytesPerSecond'] as num?)?.toDouble();
    final firstByteUs = (sample['firstByteUs'] as num?)?.toDouble();
    final parts = <String>[];
    if (bytesPerSecond != null && bytesPerSecond > 0) {
      parts.add('${(bytesPerSecond / 1048576).toStringAsFixed(1)} MiB/s');
    }
    if (firstByteUs != null && firstByteUs > 0) {
      parts.add('首包 ${(firstByteUs / 1000).toStringAsFixed(1)} ms');
    }
    return parts.isEmpty ? '上轮：有记录' : '上轮：${parts.join(' · ')}';
  }

  final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
  return showDialog<CDNService>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('本次播放 CDN'),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 420,
        height: maxHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                locked
                    ? '当前视频已手动锁定 CDN。再次选择会立即切换；本次播放不自动回退。'
                    : '只影响当前视频。选择后立即切换；手动选择后本次播放不自动回退。',
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: RadioGroup<CDNService>(
                  groupValue: current,
                  onChanged: (value) {
                    if (value != null) Navigator.of(context).pop(value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final cdn in CDNService.values)
                        RadioListTile<CDNService>(
                          value: cdn,
                          dense: true,
                          title: Text(cdn.desc),
                          subtitle: Text(resultText(cdn)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    ),
  );
}
