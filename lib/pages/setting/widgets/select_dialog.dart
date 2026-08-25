import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/pages/setting/widgets/checkbox_num_list_tile.dart';
import 'package:PiliPlus/utils/connectivity_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_ui/material_ui.dart';

class SelectDialog<T> extends StatelessWidget {
  final T? value;
  final String title;
  final List<(T, String)> values;
  final Widget Function(BuildContext, int)? subtitleBuilder;
  final bool toggleable;

  const SelectDialog({
    super.key,
    this.value,
    required this.values,
    required this.title,
    this.subtitleBuilder,
    this.toggleable = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleMedium = TextTheme.of(context).titleMedium!;
    return AlertDialog(
      clipBehavior: Clip.hardEdge,
      title: Text(title),
      constraints: subtitleBuilder != null
          ? const BoxConstraints.tightFor(width: 320)
          : null,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: Material(
        type: .transparency,
        child: SingleChildScrollView(
          child: RadioGroup<T>(
            onChanged: (v) => Navigator.of(context).pop(v ?? value),
            groupValue: value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                values.length,
                (index) {
                  final item = values[index];
                  return RadioListTile<T>(
                    toggleable: toggleable,
                    dense: true,
                    value: item.$1,
                    title: Text(
                      item.$2,
                      style: titleMedium,
                    ),
                    subtitle: subtitleBuilder?.call(context, index),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

typedef CdnSpeedConfig = ({
  int totalBytes,
  int warmupBytes,
  Duration cooldown,
  bool parallel,
});

Future<CdnSpeedConfig?> showCdnSpeedConfigDialog(BuildContext context) async {
  final cellular =
      (await ConnectivityUtils.resolveForPlayback()).useCellularPreferences;
  if (!context.mounted) return null;
  return showDialog<CdnSpeedConfig>(
    context: context,
    builder: (context) => _CdnSpeedConfigDialog(cellular: cellular),
  );
}

class _CdnSpeedConfigDialog extends StatefulWidget {
  const _CdnSpeedConfigDialog({required this.cellular});

  final bool cellular;

  @override
  State<_CdnSpeedConfigDialog> createState() =>
      _CdnSpeedConfigDialogState();
}

class _CdnSpeedConfigDialogState extends State<_CdnSpeedConfigDialog> {
  late final TextEditingController totalController;
  late final TextEditingController warmupController;
  final cooldownController = TextEditingController(text: '0');
  bool parallel = false;
  String? error;

  @override
  void initState() {
    super.initState();
    totalController = TextEditingController(text: widget.cellular ? '16' : '64')
      ..addListener(_syncWarmupFromTotal);
    warmupController = TextEditingController(text: widget.cellular ? '4' : '8');
  }

  void _syncWarmupFromTotal() {
    final total = double.tryParse(totalController.text);
    if (total == null || !total.isFinite || total <= 0) return;
    final value = total / 8;
    warmupController.text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  }

  @override
  void dispose() {
    totalController.dispose();
    warmupController.dispose();
    cooldownController.dispose();
    super.dispose();
  }

  void _submit() {
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
    Navigator.of(context).pop((
      totalBytes: (total * 1048576).round(),
      warmupBytes: (warmup * 1048576).round(),
      cooldown: Duration(microseconds: (cooldown * 1000000).round()),
      parallel: parallel,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('CDN 测速参数 · ${widget.cellular ? "等效移网" : "等效宽带"}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
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
              enabled: !parallel,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '相邻 CDN 冷却时间',
                suffixText: '秒',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('并行测速'),
              subtitle: Text(parallel ? '全部 CDN 同时开始' : '按交错顺序串行测速'),
              value: parallel,
              onChanged: (value) => setState(() => parallel = value),
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
        TextButton(onPressed: _submit, child: const Text('开始测速')),
      ],
    );
  }
}

class CdnSelectDialog extends StatefulWidget {
  final BaseItem? sample;
  final List<CDNService> initValues;
  final CdnSpeedConfig? speedConfig;

  const CdnSelectDialog({
    super.key,
    this.sample,
    required this.initValues,
    this.speedConfig,
  });

  @override
  State<CdnSelectDialog> createState() => _CdnSelectDialogState();
}

class _CdnSelectDialogState extends State<CdnSelectDialog> {
  static const _testOrder = [
    CDNService.baseUrl,
    CDNService.backupUrl,
    CDNService.ali,
    CDNService.cos,
    CDNService.hw,
    CDNService.alib,
    CDNService.cosb,
    CDNService.hwb,
    CDNService.alio1,
    CDNService.coso1,
    CDNService.hwo1,
    CDNService.aliov,
    CDNService.cosov,
    CDNService.hwov,
    CDNService.tf_tx,
    CDNService.tf_hw,
    CDNService.hw_08c,
    CDNService.hw_08h,
    CDNService.hw_08ct,
    CDNService.akamai,
    CDNService.hk_bcache,
  ];

  late final List<ValueNotifier<_CdnSpeedSample?>> _cdnResList;
  late final List<CancelToken?> _tokens;
  late final bool _cdnSpeedTest;
  late final Map<CDNService, int> _tempValues;

  @override
  void initState() {
    _tempValues = {
      for (final (index, item) in widget.initValues.indexed) item: index + 1,
    };
    _cdnSpeedTest = Pref.cdnSpeedTest && widget.speedConfig != null;
    final length = CDNService.values.length;
    _cdnResList = List.generate(
      length,
      (_) => ValueNotifier<_CdnSpeedSample?>(null),
    );
    _tokens = List.filled(length, null);
    if (_cdnSpeedTest) {
      _dio =
          Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              ),
            )
            ..options.headers = {
              'user-agent': BrowserUa.pc,
              'referer': HttpString.baseUrl,
            };
      _startSpeedTest();
    }
    super.initState();
  }

  @override
  void dispose() {
    for (final e in _tokens) {
      e?.cancel();
    }
    for (final notifier in _cdnResList) {
      notifier.dispose();
    }
    if (_cdnSpeedTest) {
      _dio.close(force: true);
    }
    super.dispose();
  }

  Future<BaseItem> _getSampleUrl() async {
    final result = await VideoHttp.videoUrl(
      cid: 196018899,
      bvid: 'BV1fK4y1t7hj',
      tryLook: false,
      videoType: VideoType.ugc,
    );
    final item = result.dataOrNull?.dash?.video?.first;
    if (item == null) throw Exception('无法获取视频流');
    return item;
  }

  Future<void> _startSpeedTest() async {
    try {
      final config = widget.speedConfig!;
      final limits = (warmup: config.warmupBytes, max: config.totalBytes);
      final videoItem = widget.sample ?? await _getSampleUrl();
      await _testAllCdnServices(videoItem, limits, config);
    } catch (e) {
      if (kDebugMode) debugPrint('CDN speed test failed: $e');
    }
  }

  Future<void> _testAllCdnServices(
    BaseItem videoItem,
    ({int warmup, int max}) limits,
    CdnSpeedConfig config,
  ) async {
    if (config.parallel) {
      await Future.wait([
        for (final item in _testOrder)
          _testSingleCdn(item, videoItem, limits),
      ]);
      return;
    }
    for (final (index, item) in _testOrder.indexed) {
      if (!mounted) break;
      await _testSingleCdn(item, videoItem, limits);
      if (mounted && index != _testOrder.length - 1 && config.cooldown > .zero) {
        await Future.delayed(config.cooldown);
      }
    }
  }

  Future<void> _testSingleCdn(
    CDNService item,
    BaseItem videoItem,
    ({int warmup, int max}) limits,
  ) async {
    try {
      final cdnUrl = VideoUtils.getCdnUrl(
        videoItem.playUrls,
        defaultCDNService: item,
      );
      await _measureDownloadSpeed(cdnUrl, item.index, limits);
    } catch (e) {
      _handleSpeedTestError(e, item.index);
    }
  }

  late final Dio _dio;

  Future<void> _measureDownloadSpeed(
    String url,
    int index,
    ({int warmup, int max}) limits,
  ) async {
    _CdnSpeedSample sample;
    try {
      final probes = await _measureLatencyProbes(url, index, limits.max);
      final probeBytes = probes.fold<int>(0, (sum, probe) => sum + probe.bytes);
      final remainingBytes = limits.max - probeBytes;
      final streamMax = remainingBytes > 1 ? remainingBytes : 1;
      final streamWarmup = limits.warmup < streamMax - 1
          ? limits.warmup
          : streamMax - 1;
      sample = await _measureStream(
        url,
        index,
        (warmup: streamWarmup < 0 ? 0 : streamWarmup, max: streamMax),
        probes,
      );
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('CDN stream speed test failed: $e');
      sample = await _measureLegacy(url, index, limits, const []);
    }
    if (mounted) _updateSpeedResult(index, sample);
  }

  Future<List<_CdnLatencyProbe>> _measureLatencyProbes(
    String url,
    int index,
    int totalBytes,
  ) async {
    final probes = <_CdnLatencyProbe>[];
    final suggestedProbeBytes = totalBytes ~/ 256;
    final probeBytes = suggestedProbeBytes < 1024
        ? 1024
        : suggestedProbeBytes > 16384
        ? 16384
        : suggestedProbeBytes;
    for (var attempt = 0; attempt < 5; attempt++) {
      CancelToken? token;
      try {
        token = _newToken(index);
        final watch = Stopwatch()..start();
        final response = await _dio.get<ResponseBody>(
          url,
          cancelToken: token,
          options: Options(
            headers: {'range': 'bytes=0-${probeBytes - 1}'},
            responseType: ResponseType.stream,
            receiveTimeout: const Duration(seconds: 8),
            validateStatus: (status) => status == 200 || status == 206,
          ),
        );
        final headersUs = watch.elapsedMicroseconds;
        var received = 0;
        final stream = response.data?.stream;
        if (stream == null) continue;
        await for (final chunk in stream) {
          if (chunk.isEmpty) continue;
          received += chunk.length;
          probes.add((
            headersUs: headersUs,
            firstByteUs: watch.elapsedMicroseconds,
            bytes: received,
          ));
          token!.cancel();
          break;
        }
      } catch (_) {
        // 单次探测失败不影响主测速；结果页会保留成功样本数。
      } finally {
        if (identical(_tokens[index], token)) _tokens[index] = null;
      }
    }
    return probes;
  }

  CancelToken _newToken(int index) {
    final token = CancelToken();
    _tokens[index]?.cancel();
    _tokens[index] = token;
    return token;
  }

  Future<_CdnSpeedSample> _measureStream(
    String url,
    int index,
    ({int warmup, int max}) limits,
    List<_CdnLatencyProbe> probes,
  ) async {
    final token = _newToken(index);
    final watch = Stopwatch()..start();
    Timer? measureTimer;
    var intentionalStop = false;
    var downloaded = 0;
    int? firstByteUs;
    int? headersUs;
    int? sampleStartUs;
    var sampleStartBytes = 0;
    final points = <_CdnPoint>[];
    List<String> resolvedIps = const [];

    final totalTimer = Timer(const Duration(seconds: 15), () {
      intentionalStop = true;
      token.cancel();
    });

    try {
      final response = await _dio.get<ResponseBody>(
        url,
        cancelToken: token,
        options: Options(
          headers: {'range': 'bytes=0-${limits.max - 1}'},
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
          validateStatus: (status) => status == 200 || status == 206,
        ),
      );
      headersUs = watch.elapsedMicroseconds;
      final stream = response.data?.stream;
      if (stream == null) throw StateError('测速响应为空');

      await for (final chunk in stream) {
        if (chunk.isEmpty) continue;
        final now = watch.elapsedMicroseconds;
        firstByteUs ??= now;
        final total = downloaded + chunk.length;
        downloaded = total > limits.max ? limits.max : total;
        points.add((elapsedUs: now, bytes: downloaded));

        if (sampleStartUs == null && downloaded >= limits.warmup) {
          sampleStartUs = now;
          sampleStartBytes = downloaded;
          measureTimer = Timer(const Duration(seconds: 8), () {
            intentionalStop = true;
            token.cancel();
          });
        }
        if (downloaded >= limits.max) break;
      }
      resolvedIps = await _resolveIps(url);
    } on DioException {
      if (!intentionalStop) rethrow;
    } finally {
      totalTimer.cancel();
      measureTimer?.cancel();
      if (identical(_tokens[index], token)) _tokens[index] = null;
    }

    return _buildSample(
      watch: watch,
      downloaded: downloaded,
      firstByteUs: firstByteUs,
      headersUs: headersUs,
      sampleStartUs: sampleStartUs,
      sampleStartBytes: sampleStartBytes,
      points: points,
      probes: probes,
      resolvedIps: resolvedIps,
      type: downloaded >= limits.max
          ? _CdnSpeedSampleType.complete
          : _CdnSpeedSampleType.partial,
    );
  }

  Future<_CdnSpeedSample> _measureLegacy(
    String url,
    int index,
    ({int warmup, int max}) limits,
    List<_CdnLatencyProbe> probes,
  ) async {
    final token = _newToken(index);
    final watch = Stopwatch()..start();
    Timer? measureTimer;
    var intentionalStop = false;
    var downloaded = 0;
    int? firstByteUs;
    int? headersUs;
    int? sampleStartUs;
    var sampleStartBytes = 0;
    final points = <_CdnPoint>[];

    final totalTimer = Timer(const Duration(seconds: 15), () {
      intentionalStop = true;
      token.cancel();
    });

    try {
      await _dio.get(
        url,
        cancelToken: token,
        onReceiveProgress: (count, _) {
          if (count <= 0 || intentionalStop) return;
          final now = watch.elapsedMicroseconds;
          firstByteUs ??= now;
          downloaded = count > limits.max ? limits.max : count;
          points.add((elapsedUs: now, bytes: downloaded));

          if (sampleStartUs == null && downloaded >= limits.warmup) {
            sampleStartUs = now;
            sampleStartBytes = downloaded;
            measureTimer = Timer(const Duration(seconds: 8), () {
              intentionalStop = true;
              token.cancel();
            });
          }
          if (downloaded >= limits.max) {
            intentionalStop = true;
            token.cancel();
          }
        },
      );
    } on DioException {
      if (!intentionalStop) rethrow;
    } finally {
      totalTimer.cancel();
      measureTimer?.cancel();
      if (identical(_tokens[index], token)) _tokens[index] = null;
    }

    return _buildSample(
      watch: watch,
      downloaded: downloaded,
      firstByteUs: firstByteUs,
      headersUs: headersUs,
      sampleStartUs: sampleStartUs,
      sampleStartBytes: sampleStartBytes,
      points: points,
      probes: probes,
      resolvedIps: const [],
      type: _CdnSpeedSampleType.fallback,
    );
  }

  _CdnSpeedSample _buildSample({
    required Stopwatch watch,
    required int downloaded,
    required int? firstByteUs,
    required int? headersUs,
    required int? sampleStartUs,
    required int sampleStartBytes,
    required List<_CdnPoint> points,
    required List<_CdnLatencyProbe> probes,
    required List<String> resolvedIps,
    required _CdnSpeedSampleType type,
  }) {
    watch.stop();
    if (downloaded <= 0 || firstByteUs == null) {
      throw TimeoutException('测速超时');
    }

    var bytes = downloaded - sampleStartBytes;
    var startUs = sampleStartUs;
    if (bytes <= 0 || startUs == null) {
      bytes = downloaded;
      startUs = firstByteUs;
    }
    final elapsedUs = watch.elapsedMicroseconds - startUs;
    return _CdnSpeedSample(
      bytes: bytes,
      elapsedUs: elapsedUs > 0 ? elapsedUs : 1,
      firstByteUs: firstByteUs,
      headersUs: headersUs,
      downloaded: downloaded,
      sampleStartBytes: sampleStartBytes,
      measurementStartUs: startUs,
      points: points,
      probes: probes,
      resolvedIps: resolvedIps,
      type: type,
    );
  }

  Future<List<String>> _resolveIps(String url) async {
    try {
      return (await InternetAddress.lookup(Uri.parse(url).host))
          .map((item) => item.address)
          .toSet()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  void _updateSpeedResult(int index, _CdnSpeedSample sample) =>
      _cdnResList[index].value = sample;

  void _handleSpeedTestError(dynamic error, int index) {
    _tokens
      ..[index]?.cancel()
      ..[index] = null;
    final item = _cdnResList[index];
    if (item.value != null) return;

    if (kDebugMode) debugPrint('CDN speed test error: $error');
    if (!mounted) return;
    String message;
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null && 400 <= statusCode && statusCode < 500) {
        message = '此视频可能无法替换为该CDN';
      } else {
        message = error.toString();
      }
    } else {
      message = error.toString();
    }
    if (message.isEmpty) {
      message = '测速失败';
    }
    item.value = _CdnSpeedSample.error(message);
  }

  String _rate(_CdnSpeedSample sample, double bytesPerSecond) =>
      '${(bytesPerSecond / sample.divisor).toStringAsPrecision(3)} ${sample.unit}';

  String _ms(num microseconds) =>
      '${(microseconds / 1000).toStringAsPrecision(3)} ms';

  String _duration(int microseconds) {
    if (microseconds < 1000) return '$microseconds μs';
    if (microseconds < 1000000) return _ms(microseconds);
    return '${(microseconds / 1000000).toStringAsPrecision(3)} s';
  }

  void _sortByDiagnostics() {
    final selected = _tempValues.keys.toList()
      ..sort((a, b) {
        final aSample = _cdnResList[a.index].value;
        final bSample = _cdnResList[b.index].value;
        double score(_CdnSpeedSample? sample) {
          if (sample == null || sample.hasError) return double.negativeInfinity;
          final metrics = sample.metrics;
          return metrics.p05 /
              (1 + metrics.relativeJitter + metrics.latencyMeanUs / 1000000 + metrics.maxGapUs / 1000000);
        }
        return score(bSample).compareTo(score(aSample));
      });
    _tempValues
      ..clear()
      ..addEntries(selected.indexed.map((item) => MapEntry(item.$2, item.$1 + 1)));
    setState(() {});
  }

  void _showDiagnosticDetails(BuildContext context, CDNService cdn, _CdnSpeedSample sample) {
    final metrics = sample.metrics;
    final rows = [
      '测试模式：${sample.type.name}；总接收 ${(sample.downloaded / 1048576).toStringAsPrecision(4)} MiB',
      '测量区间：${_duration(sample.elapsedUs)}；传输片段：${metrics.segmentRates.length}',
      '平均带宽：${_rate(sample, sample.averageRate)}',
      '原始最小／最大：${_rate(sample, metrics.minRate)} ／ ${_rate(sample, metrics.maxRate)}',
      'P02／P05／P50：${_rate(sample, metrics.p02)} ／ ${_rate(sample, metrics.p05)} ／ ${_rate(sample, metrics.p50)}',
      'P95／P98：${_rate(sample, metrics.p95)} ／ ${_rate(sample, metrics.p98)}',
      'P95−P05 极差：${_rate(sample, metrics.p95 - metrics.p05)}',
      'P98−P02 极差：${_rate(sample, metrics.p98 - metrics.p02)}',
      '滚动带宽最低／最高：${_rate(sample, metrics.rollingLow)} ／ ${_rate(sample, metrics.rollingHigh)}',
      '带宽趋势：${(metrics.trendPercent * 100).toStringAsPrecision(3)}%（后段相对前段）',
      '带宽标准差：${_rate(sample, metrics.standardDeviation)}；方差 ${(metrics.variance / (sample.divisor * sample.divisor)).toStringAsPrecision(4)}',
      '带宽抖动：${_rate(sample, metrics.absoluteJitter)}；相对 ${(metrics.relativeJitter * 100).toStringAsPrecision(3)}%',
      '最大传输空窗：${_duration(metrics.maxGapUs)}；≥250/500/1000ms：${metrics.gap250ms}/${metrics.gap500ms}/${metrics.gap1000ms}',
      '首包等待：${_ms(sample.firstByteUs)}；响应头：${sample.headersUs == null ? "—" : _ms(sample.headersUs!)}',
      '首包样本：${metrics.latencySamples.length}；平均 ${_ms(metrics.latencyMeanUs)}；标准差 ${_ms(metrics.latencyStdUs)}；方差 ${(metrics.latencyVariance / 1000000).toStringAsPrecision(4)} ms²；抖动 ${_ms(metrics.latencyJitterUs)}',
      '计算方法：带宽抖动为相邻传输片段速率差的绝对值平均；相对抖动 = 带宽抖动 ÷ 平均带宽。首包抖动按相邻首包等待差的绝对值平均计算。',
      '综合排序优先看 P05 低谷带宽，再同时扣除相对抖动、首包等待与最大传输空窗；它只调整当前列表顺序，不会自动改写播放优先级。',
      if (sample.resolvedIps.isNotEmpty) 'DNS 地址：${sample.resolvedIps.join("，")}',
    ];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${cdn.desc} · 详细诊断'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: SelectableText(rows.join('\n\n')),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildCdnCard(BuildContext context, CDNService cdn) {
    final titleStyle = TextTheme.of(context).titleMedium!;
    return Card(
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ValueListenableBuilder<_CdnSpeedSample?>(
          valueListenable: _cdnResList[cdn.index],
          builder: (context, sample, _) {
            final failed = sample?.hasError == true;
            final metrics = sample?.hasError == false ? sample!.metrics : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OrderedCheckboxListTile(
                  dense: true,
                  value: _tempValues[cdn],
                  title: Text(cdn.desc, style: titleStyle),
                  subtitle: Text(
                    sample == null
                        ? (_cdnSpeedTest ? '正在等待测速' : '未测速')
                        : failed
                        ? sample.errorMessage!
                        : '${_rate(sample, sample.averageRate)} · 首包 ${_ms(sample.firstByteUs)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onChanged: (value) {
                    if (value == null) {
                      _tempValues[cdn] = _tempValues.length + 1;
                    } else {
                      final pos = _tempValues.remove(cdn)!;
                      _tempValues.updateAll(
                        (key, current) => current > pos ? current - 1 : current,
                      );
                    }
                    setState(() {});
                  },
                ),
                if (metrics != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('P05 ${_rate(sample!, metrics.p05)} · P50 ${_rate(sample, metrics.p50)} · P95 ${_rate(sample, metrics.p95)}'),
                        Text('抖动 ${(metrics.relativeJitter * 100).toStringAsPrecision(3)}% · 最大空窗 ${_duration(metrics.maxGapUs)}'),
                        TextButton.icon(
                          onPressed: () => _showDiagnosticDetails(context, cdn, sample),
                          icon: const Icon(Icons.analytics_outlined, size: 18),
                          label: const Text('详细诊断'),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(title: const Text('CDN 优先级与网络诊断')),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 4),
              child: Text('按编号依次尝试；当前 CDN 打不开时自动回退到下一项。首包等待、带宽抖动与百分位均按单个 CDN 独立计算。'),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: constraints.maxWidth >= 760 ? 2 : 1,
                    childAspectRatio: constraints.maxWidth >= 760 ? 2.35 : 2.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _testOrder.length,
                  itemBuilder: (context, index) => _buildCdnCard(context, _testOrder[index]),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              if (_cdnSpeedTest) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _sortByDiagnostics,
                  child: const Text('按综合指标排序'),
                ),
              ],
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _tempValues.isEmpty
                    ? null
                    : () {
                        final selected = _tempValues.entries.toList()
                          ..sort((a, b) => a.value.compareTo(b.value));
                        Navigator.of(context).pop(
                          selected.map((entry) => entry.key).toList(),
                        );
                      },
                child: const Text('保存优先级'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CdnSpeedSampleType { complete, partial, fallback }

typedef _CdnPoint = ({int elapsedUs, int bytes});
typedef _CdnLatencyProbe = ({int headersUs, int firstByteUs, int bytes});

class _CdnSpeedSample {
  _CdnSpeedSample({
    required this.bytes,
    required this.elapsedUs,
    required this.firstByteUs,
    required this.headersUs,
    required this.downloaded,
    required this.sampleStartBytes,
    required this.measurementStartUs,
    required this.points,
    required this.probes,
    required this.resolvedIps,
    required this.type,
  }) : errorMessage = null;

  _CdnSpeedSample.error(this.errorMessage)
    : bytes = 0,
      elapsedUs = 1,
      firstByteUs = 0,
      headersUs = null,
      downloaded = 0,
      sampleStartBytes = 0,
      measurementStartUs = 0,
      points = const [],
      probes = const [],
      resolvedIps = const [],
      type = _CdnSpeedSampleType.fallback;

  final int bytes;
  final int elapsedUs;
  final int firstByteUs;
  final int? headersUs;
  final int downloaded;
  final int sampleStartBytes;
  final int measurementStartUs;
  final List<_CdnPoint> points;
  final List<_CdnLatencyProbe> probes;
  final List<String> resolvedIps;
  final _CdnSpeedSampleType type;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
  int get divisor => type == _CdnSpeedSampleType.fallback ? 1000000 : 1048576;
  String get unit => switch (type) {
    _CdnSpeedSampleType.complete => 'MiB/s',
    _CdnSpeedSampleType.partial => 'M/s',
    _CdnSpeedSampleType.fallback => 'MB/s',
  };
  double get averageRate => bytes * Duration.microsecondsPerSecond / elapsedUs;
  late final metrics = _CdnMetrics.from(this);
}

class _CdnMetrics {
  _CdnMetrics._({
    required this.segmentRates,
    required this.p02,
    required this.p05,
    required this.p50,
    required this.p95,
    required this.p98,
    required this.minRate,
    required this.maxRate,
    required this.standardDeviation,
    required this.variance,
    required this.relativeJitter,
    required this.rollingLow,
    required this.rollingHigh,
    required this.trendPercent,
    required this.absoluteJitter,
    required this.maxGapUs,
    required this.gap250ms,
    required this.gap500ms,
    required this.gap1000ms,
    required this.latencySamples,
    required this.latencyMeanUs,
    required this.latencyStdUs,
    required this.latencyVariance,
    required this.latencyJitterUs,
  });

  final List<double> segmentRates;
  final double p02;
  final double p05;
  final double p50;
  final double p95;
  final double p98;
  final double minRate;
  final double maxRate;
  final double standardDeviation;
  final double variance;
  final double relativeJitter;
  final double rollingLow;
  final double rollingHigh;
  final double trendPercent;
  final double absoluteJitter;
  final int maxGapUs;
  final int gap250ms;
  final int gap500ms;
  final int gap1000ms;
  final List<int> latencySamples;
  final double latencyMeanUs;
  final double latencyStdUs;
  final double latencyVariance;
  final double latencyJitterUs;

  factory _CdnMetrics.from(_CdnSpeedSample sample) {
    final rates = <double>[];
    var previousTime = sample.measurementStartUs;
    var previousBytes = sample.sampleStartBytes;
    var maxGapUs = 0;
    var gap250ms = 0;
    var gap500ms = 0;
    var gap1000ms = 0;
    for (final point in sample.points) {
      if (point.elapsedUs < sample.measurementStartUs) continue;
      final elapsed = point.elapsedUs - previousTime;
      final bytes = point.bytes - previousBytes;
      if (elapsed > 0 && bytes > 0) {
        rates.add(bytes * Duration.microsecondsPerSecond / elapsed);
        if (elapsed > maxGapUs) maxGapUs = elapsed;
        if (elapsed >= 250000) gap250ms++;
        if (elapsed >= 500000) gap500ms++;
        if (elapsed >= 1000000) gap1000ms++;
      }
      previousTime = point.elapsedUs;
      previousBytes = point.bytes;
    }
    if (rates.isEmpty) rates.add(sample.averageRate);
    final sorted = List<double>.of(rates)..sort();
    final mean = rates.reduce((a, b) => a + b) / rates.length;
    final variance = rates
            .map((rate) {
              final delta = rate - mean;
              return delta * delta;
            })
            .reduce((a, b) => a + b) /
        rates.length;
    final absoluteJitter = rates.length < 2
        ? 0.0
        : List<double>.generate(
                rates.length - 1,
                (index) => (rates[index + 1] - rates[index]).abs(),
              ).reduce((a, b) => a + b) /
            (rates.length - 1);
    final latency = [
      for (final probe in sample.probes) probe.firstByteUs,
      if (sample.probes.isEmpty) sample.firstByteUs,
    ];
    final latencyMean = latency.reduce((a, b) => a + b) / latency.length;
    final latencyVariance = latency
            .map((value) {
              final delta = value - latencyMean;
              return delta * delta;
            })
            .reduce((a, b) => a + b) /
        latency.length;
    final latencyJitter = latency.length < 2
        ? 0.0
        : List<double>.generate(
                latency.length - 1,
                (index) => (latency[index + 1] - latency[index]).abs().toDouble(),
              ).reduce((a, b) => a + b) /
            (latency.length - 1);
    final rolling = <double>[];
    final activePoints = sample.points
        .where((point) => point.elapsedUs >= sample.measurementStartUs)
        .toList(growable: false);
    var startIndex = 0;
    for (var endIndex = 0; endIndex < activePoints.length; endIndex++) {
      while (startIndex < endIndex &&
          activePoints[endIndex].elapsedUs - activePoints[startIndex].elapsedUs > 1000000) {
        startIndex++;
      }
      final elapsed = activePoints[endIndex].elapsedUs - activePoints[startIndex].elapsedUs;
      final bytes = activePoints[endIndex].bytes - activePoints[startIndex].bytes;
      if (elapsed >= 250000 && bytes > 0) {
        rolling.add(bytes * Duration.microsecondsPerSecond / elapsed);
      }
    }
    if (rolling.isEmpty) rolling.addAll(rates);
    final split = rates.length ~/ 2 == 0 ? 1 : rates.length ~/ 2;
    final early = rates.take(split).reduce((a, b) => a + b) / split;
    final lateRates = rates.skip(split).toList();
    final late = lateRates.isEmpty
        ? early
        : lateRates.reduce((a, b) => a + b) / lateRates.length;
    return _CdnMetrics._(
      segmentRates: rates,
      p02: _percentile(sorted, 0.02),
      p05: _percentile(sorted, 0.05),
      p50: _percentile(sorted, 0.50),
      p95: _percentile(sorted, 0.95),
      p98: _percentile(sorted, 0.98),
      minRate: sorted.first,
      maxRate: sorted.last,
      standardDeviation: math.sqrt(variance),
      variance: variance,
      relativeJitter: mean == 0 ? 0 : absoluteJitter / mean,
      rollingLow: rolling.reduce((a, b) => a < b ? a : b),
      rollingHigh: rolling.reduce((a, b) => a > b ? a : b),
      trendPercent: early == 0 ? 0 : late / early - 1,
      absoluteJitter: absoluteJitter,
      maxGapUs: maxGapUs,
      gap250ms: gap250ms,
      gap500ms: gap500ms,
      gap1000ms: gap1000ms,
      latencySamples: latency,
      latencyMeanUs: latencyMean,
      latencyStdUs: math.sqrt(latencyVariance),
      latencyVariance: latencyVariance,
      latencyJitterUs: latencyJitter,
    );
  }

  static double _percentile(List<double> values, double p) {
    if (values.length == 1) return values.first;
    final position = (values.length - 1) * p;
    final lower = position.floor();
    final upper = position.ceil();
    return values[lower] + (values[upper] - values[lower]) * (position - lower);
  }
}
