import 'package:PiliBro/models/common/video/video_decode_type.dart';
import 'package:PiliBro/models/video/play/url.dart';
import 'package:PiliBro/pages/setting/widgets/select_dialog.dart'
    show CdnSpeedConfig, CdnSpeedMode, showCdnSpeedConfigDialog;
import 'package:PiliBro/services/cdn_last_video_service.dart';
import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/connectivity_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

typedef CdnSpeedSetup = ({CdnSpeedConfig? config, BaseItem? sample});

enum _CdnTestSource { skip, fixed, lastVideo }

Future<CdnSpeedSetup?> showCdnSpeedSetupDialog(BuildContext context) async {
  final source = await showDialog<_CdnTestSource>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('CDN 测速'),
      content: const Text('选择进入 CDN 设置前的本次测速载荷。取消只跳过测速，仍然进入 CDN 设置。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_CdnTestSource.skip),
          child: const Text('取消（不测速）'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_CdnTestSource.lastVideo),
          child: const Text('测试上次播放的视频'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_CdnTestSource.fixed),
          child: const Text('默认样本测速'),
        ),
      ],
    ),
  );

  if (!context.mounted || source == null || source == _CdnTestSource.skip) {
    return (config: null, sample: null);
  }

  if (source == _CdnTestSource.fixed) {
    final config = await showCdnSpeedConfigDialog(context);
    return (config: config, sample: null);
  }

  final last = await CdnLastVideoService.load();
  if (!context.mounted) return null;
  if (last == null) {
    SmartDialog.showToast('没有可用的上次播放视频，已跳过测速');
    return (config: null, sample: null);
  }

  final byCodec = <VideoDecodeFormatType, VideoItem>{};
  for (final item in last.videos) {
    final codecs = item.codecs;
    if (codecs == null || codecs.isEmpty) continue;
    try {
      final format = VideoDecodeFormatType.fromString(codecs);
      byCodec.putIfAbsent(format, () => item);
    } catch (_) {}
  }
  if (byCodec.isEmpty) {
    SmartDialog.showToast('上次视频没有可识别的 DASH 编码，已跳过测速');
    return (config: null, sample: null);
  }

  final codec = await showDialog<VideoDecodeFormatType>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('上次播放视频 · 选择编码'),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: RadioGroup<VideoDecodeFormatType>(
        // This dialog advances immediately on selection. Keeping a visual
        // default made tapping that already-selected codec a no-op, so leave
        // the group unselected until the user actually chooses one.
        groupValue: null,
        onChanged: (value) {
          if (value != null) Navigator.of(context).pop(value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in byCodec.keys)
              RadioListTile<VideoDecodeFormatType>(
                value: item,
                title: Text(item.description),
                subtitle: Text(byCodec[item]?.codecs ?? ''),
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
  if (!context.mounted || codec == null) {
    return (config: null, sample: null);
  }

  final sample = byCodec[codec]!;
  final durationMs =
      last.playUrl.timeLength ?? ((last.playUrl.dash?.duration ?? 0) * 1000);
  final bandwidth = sample.bandWidth ?? 0;
  final estimatedBytes = bandwidth > 0 && durationMs > 0
      ? bandwidth * durationMs / 8000
      : 0.0;

  final cellular =
      (await ConnectivityUtils.resolveForPlayback()).useCellularPreferences;
  if (!context.mounted) return null;
  final defaultMiB = estimatedBytes > 0
      ? (estimatedBytes / 1048576).clamp(0.0, 512.0)
      : (cellular ? 16.0 : 64.0);
  final config = await showDialog<CdnSpeedConfig>(
    context: context,
    builder: (context) => _LastVideoSpeedConfigDialog(
      codec: codec,
      sample: sample,
      initialTotalMiB: defaultMiB,
    ),
  );
  return (config: config, sample: config == null ? null : sample);
}

class _LastVideoSpeedConfigDialog extends StatefulWidget {
  const _LastVideoSpeedConfigDialog({
    required this.codec,
    required this.sample,
    required this.initialTotalMiB,
  });

  final VideoDecodeFormatType codec;
  final VideoItem sample;
  final double initialTotalMiB;

  @override
  State<_LastVideoSpeedConfigDialog> createState() =>
      _LastVideoSpeedConfigDialogState();
}

class _LastVideoSpeedConfigDialogState
    extends State<_LastVideoSpeedConfigDialog> {
  late final TextEditingController totalController;
  late final TextEditingController warmupController;
  final cooldownController = TextEditingController(text: '0');
  CdnSpeedMode mode = CdnSpeedMode.serial;
  String? error;

  @override
  void initState() {
    super.initState();
    final total = widget.initialTotalMiB;
    totalController = TextEditingController(text: _number(total))
      ..addListener(_syncWarmupFromTotal);
    warmupController = TextEditingController(text: _number(total / 8));
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');

  void _syncWarmupFromTotal() {
    final total = double.tryParse(totalController.text);
    if (total == null || !total.isFinite || total <= 0) return;
    warmupController.text = _number(total / 8);
  }

  @override
  void dispose() {
    totalController.dispose();
    warmupController.dispose();
    cooldownController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final total = double.tryParse(totalController.text);
    final warmup = double.tryParse(warmupController.text);
    final cooldown = double.tryParse(cooldownController.text);
    if (total == null ||
        warmup == null ||
        cooldown == null ||
        !total.isFinite ||
        !warmup.isFinite ||
        !cooldown.isFinite ||
        total <= 0 ||
        warmup < 0 ||
        warmup >= total ||
        cooldown < 0) {
      setState(() => error = '总大小须大于热身大小，所有数值均须有效且不能为负');
      return;
    }

    final k = Accounts.x;
    if (!k && total > 256 && total <= 512) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('CDN 测速'),
          content: const Text('本次文件较大，建议不要超过 512 MiB。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('继续'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final effectiveTotal = !k && total > 512 ? 512.0 : total;
    final effectiveWarmup = warmup.clamp(0.0, effectiveTotal * 0.999);
    Navigator.of(context).pop((
      totalBytes: (effectiveTotal * 1048576).round(),
      warmupBytes: (effectiveWarmup * 1048576).round(),
      cooldown: Duration(microseconds: (cooldown * 1000000).round()),
      mode: mode,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final resolution = widget.sample.width != null && widget.sample.height != null
        ? '${widget.sample.width}×${widget.sample.height}'
        : '未知分辨率';
    return AlertDialog(
      title: Text('上次播放视频 · ${widget.codec.description}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$resolution · ${widget.sample.codecs ?? widget.codec.name}；总大小默认按该视频流估算，可自由修改。',
              ),
            ),
            TextField(
              controller: totalController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '单个 CDN 总大小',
                suffixText: 'MiB',
              ),
            ),
            TextField(
              controller: warmupController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '热身大小',
                suffixText: 'MiB',
              ),
            ),
            TextField(
              controller: cooldownController,
              enabled: mode != CdnSpeedMode.fullParallel,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '相邻 CDN 冷却时间',
                suffixText: '秒',
              ),
            ),
            DropdownButtonFormField<CdnSpeedMode>(
              initialValue: mode,
              decoration: const InputDecoration(labelText: '测速并发模式'),
              items: const [
                DropdownMenuItem(
                  value: CdnSpeedMode.serial,
                  child: Text('单线程'),
                ),
                DropdownMenuItem(
                  value: CdnSpeedMode.multi,
                  child: Text('多线程'),
                ),
                DropdownMenuItem(
                  value: CdnSpeedMode.fullParallel,
                  child: Text('全并发'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => mode = value);
              },
            ),
            if (error != null)
              Text(error!, style: TextStyle(color: ColorScheme.of(context).error)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('开始测速')),
      ],
    );
  }
}
