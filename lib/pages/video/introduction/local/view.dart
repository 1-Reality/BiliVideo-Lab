import 'dart:io';

import 'package:PiliBro/common/style.dart';
import 'package:PiliBro/common/widgets/badge.dart';
import 'package:PiliBro/common/widgets/image/network_img_layer.dart';
import 'package:PiliBro/models/common/badge_type.dart';
import 'package:PiliBro/models/common/video/video_quality.dart';
import 'package:PiliBro/models_new/download/bili_download_entry_info.dart';
import 'package:PiliBro/pages/video/introduction/local/controller.dart';
import 'package:PiliBro/plugin/pl_player/controller.dart';
import 'package:PiliBro/plugin/pl_player/decoder_lab.dart';
import 'package:PiliBro/plugin/pl_player/models/data_status.dart';
import 'package:PiliBro/utils/duration_utils.dart';
import 'package:PiliBro/utils/extension/num_ext.dart';
import 'package:PiliBro/utils/path_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

class LocalIntroPanel extends StatefulWidget {
  const LocalIntroPanel({super.key, required this.heroTag});

  final String heroTag;

  @override
  State<LocalIntroPanel> createState() => _LocalIntroPanelState();
}

class _LocalIntroPanelState extends State<LocalIntroPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final _controller = Get.find<LocalIntroController>(tag: widget.heroTag);

  int _decoderModeIndex = 0;
  int _benchmarkSeconds = 10;
  double _benchmarkSpeed = 10.0;
  bool _showAllDecoders = false;
  bool _benchmarking = false;
  bool _decoderFrameDrop = false;
  bool _skipNonRef = false;
  DecoderBenchmarkResult? _lastBenchmark;
  String? _labMessage;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Obx(() {
      final currIndex = _controller.index.value;
      return SliverList.builder(
        itemCount: _controller.list.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildDecoderLab(theme);
          }
          final entryIndex = index - 1;
          final item = _controller.list[entryIndex];
          return _buildItem(
            theme,
            currIndex == entryIndex,
            entryIndex,
            item,
          );
        },
      );
    });
  }

  Widget _buildDecoderLab(ThemeData theme) {
    final player = PlPlayerController.instance;
    if (player == null || player.dataStatus.none || !player.isFileSource) {
      return const SizedBox.shrink();
    }
    final modes = player.decoderLabModes;
    if (_decoderModeIndex >= modes.length) {
      _decoderModeIndex = 0;
    }
    final result = _lastBenchmark;
    final visibleModeIndexes = <int>[
      for (final (index, mode) in modes.indexed)
        if (_showAllDecoders || mode.primary || index == _decoderModeIndex) index,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Style.safeSpace,
        4,
        Style.safeSpace,
        10,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: Style.mdRadius,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 9,
            children: [
              Row(
                children: [
                  Text(
                    '解码实验室',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '离线视频 · 当前会话',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 6,
                  children: List.generate(visibleModeIndexes.length, (visibleIndex) {
                    final index = visibleModeIndexes[visibleIndex];
                    final mode = modes[index];
                    return ChoiceChip(
                      label: Text(mode.label),
                      selected: _decoderModeIndex == index,
                      onSelected: _benchmarking
                          ? null
                          : (selected) async {
                              if (!selected) return;
                              setState(() {
                                _decoderModeIndex = index;
                                _labMessage = '正在切换 ${mode.label}…';
                                _lastBenchmark = null;
                              });
                              try {
                                await player.applyDecoderLabMode(mode);
                                if (!mounted) return;
                                setState(() {
                                  _labMessage = '${mode.label} 已应用';
                                });
                              } catch (e) {
                                if (!mounted) return;
                                setState(() {
                                  _labMessage = '${mode.label} 切换失败：$e';
                                });
                              }
                            },
                    );
                  }),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _benchmarking
                      ? null
                      : () => setState(() => _showAllDecoders = !_showAllDecoders),
                  icon: Icon(
                    _showAllDecoders ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(
                    _showAllDecoders
                        ? '收起更多解码器'
                        : '展开全部 ${modes.length - 1} 个解码器',
                  ),
                ),
              ),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    label: const Text('Decoder 丢帧'),
                    selected: _decoderFrameDrop,
                    onSelected: _benchmarking
                        ? null
                        : (value) async {
                            setState(() => _decoderFrameDrop = value);
                            try {
                              await player.setDecoderLabFrameDrop(value);
                            } catch (e) {
                              if (mounted) {
                                setState(() => _labMessage = '丢帧切换失败：$e');
                              }
                            }
                          },
                  ),
                  FilterChip(
                    label: const Text('跳非参考帧'),
                    selected: _skipNonRef,
                    onSelected: _benchmarking
                        ? null
                        : (value) async {
                            setState(() => _skipNonRef = value);
                            try {
                              await player.setDecoderLabSkipNonRef(value);
                            } catch (e) {
                              if (mounted) {
                                setState(() => _labMessage = '跳帧切换失败：$e');
                              }
                            }
                          },
                  ),
                  PopupMenuButton<double>(
                    enabled: !_benchmarking,
                    initialValue: _benchmarkSpeed,
                    onSelected: (value) {
                      setState(() => _benchmarkSpeed = value);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 0.0, child: Text('不改变')),
                      PopupMenuItem(value: 4.0, child: Text('4×')),
                      PopupMenuItem(value: 6.0, child: Text('6×')),
                      PopupMenuItem(value: 8.0, child: Text('8×')),
                      PopupMenuItem(value: 10.0, child: Text('10×')),
                      PopupMenuItem(value: 12.0, child: Text('12×')),
                      PopupMenuItem(value: 13.5, child: Text('13.5×')),
                      PopupMenuItem(value: 15.0, child: Text('15×')),
                      PopupMenuItem(value: 16.0, child: Text('16×')),
                    ],
                    child: Chip(
                      label: Text(
                        _benchmarkSpeed == 0
                            ? '倍速：不改变'
                            : '倍速：${_benchmarkSpeed.toStringAsFixed(_benchmarkSpeed % 1 == 0 ? 0 : 1)}×',
                      ),
                    ),
                  ),
                  PopupMenuButton<int>(
                    enabled: !_benchmarking,
                    initialValue: _benchmarkSeconds,
                    onSelected: (value) {
                      setState(() => _benchmarkSeconds = value);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 10, child: Text('10 秒')),
                      PopupMenuItem(value: 30, child: Text('30 秒')),
                      PopupMenuItem(value: 60, child: Text('60 秒')),
                    ],
                    child: Chip(label: Text('$_benchmarkSeconds 秒')),
                  ),
                  FilledButton.icon(
                    onPressed: _benchmarking
                        ? null
                        : () => _runBenchmark(player, modes[_decoderModeIndex]),
                    icon: const Icon(Icons.speed),
                    label: Text(_benchmarking ? '跑分中…' : 'Benchmark'),
                  ),
                ],
              ),
              if (_labMessage case final message?)
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (result != null)
                Text(
                  '${result.modeLabel}：实际 ${result.effectiveSpeed.toStringAsFixed(2)}× '
                  '/ 设定 ${result.targetSpeed.toStringAsFixed(2)}× · '
                  '${(result.wallTime.inMilliseconds * 0.001).toStringAsFixed(2)}s '
                  '推进 ${(result.mediaTime.inMilliseconds * 0.001).toStringAsFixed(1)}s',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runBenchmark(
    PlPlayerController player,
    DecoderLabMode mode,
  ) async {
    setState(() {
      _benchmarking = true;
      _lastBenchmark = null;
      final target = _benchmarkSpeed == 0
          ? '当前 ${player.playbackSpeed.toStringAsFixed(2)}×'
          : '${_benchmarkSpeed.toStringAsFixed(_benchmarkSpeed % 1 == 0 ? 0 : 1)}×';
      _labMessage = '${mode.label}：按 $target 跑 $_benchmarkSeconds 秒…';
    });
    try {
      final result = await player.runDecoderBenchmark(
        mode: mode,
        targetSpeed: _benchmarkSpeed == 0 ? null : _benchmarkSpeed,
        wallTime: Duration(seconds: _benchmarkSeconds),
      );
      if (!mounted) return;
      setState(() {
        _lastBenchmark = result;
        _labMessage = '完成；已恢复原播放位置和播放状态';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _labMessage = 'Benchmark 失败：$e');
    } finally {
      if (mounted) {
        setState(() => _benchmarking = false);
      }
    }
  }

  Widget _buildItem(
    ThemeData theme,
    bool isCurr,
    int index,
    BiliDownloadEntryInfo entry,
  ) {
    final outline = theme.colorScheme.outline;
    final cover = File(path.join(entry.entryDirPath, PathUtils.coverName));
    final cacheWidth = entry.pageData?.cacheWidth ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SizedBox(
        height: 110,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () {
              if (isCurr) {
                return;
              }
              _controller.playIndex(index, entry: entry);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Style.safeSpace,
                vertical: 5,
              ),
              child: Row(
                spacing: 10,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      cover.existsSync()
                          ? ClipRRect(
                              borderRadius: Style.mdRadius,
                              child: Image.file(
                                cover,
                                width: 160,
                                height: 100,
                                fit: BoxFit.cover,
                                cacheWidth: cacheWidth
                                    ? 160.cacheSize(context)
                                    : null,
                                cacheHeight: cacheWidth
                                    ? null
                                    : 100.cacheSize(context),
                                colorBlendMode: NetworkImgLayer.reduce
                                    ? BlendMode.modulate
                                    : null,
                                color: NetworkImgLayer.reduce
                                    ? NetworkImgLayer.reduceLuxColor
                                    : null,
                              ),
                            )
                          : NetworkImgLayer(
                              src: entry.cover,
                              width: 160,
                              height: 100,
                            ),
                      PBadge(
                        text: DurationUtils.formatDuration(
                          entry.totalTimeMilli ~/ 1000,
                        ),
                        right: 6.0,
                        bottom: 6.0,
                        type: PBadgeType.gray,
                      ),
                      if (entry.videoQuality case final videoQuality?)
                        PBadge(
                          text: VideoQuality.fromCode(videoQuality).shortDesc,
                          right: 6.0,
                          top: 6.0,
                          type: PBadgeType.gray,
                        ),
                    ],
                  ),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          spacing: 5,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontSize: theme.textTheme.bodyMedium!.fontSize,
                                height: 1.42,
                                letterSpacing: 0.3,
                                color: isCurr
                                    ? theme.colorScheme.primary
                                    : null,
                                fontWeight: isCurr ? FontWeight.bold : null,
                              ),
                              maxLines: entry.ep != null ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (entry.pageData?.part case final part?)
                              if (part != entry.title)
                                Text(
                                  part,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            if (entry.ep?.showTitle case final showTitle?)
                              Text(
                                showTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        if (entry.ownerName case final ownerName?)
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              ownerName,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1,
                                color: outline,
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: entry.moreBtn(theme.colorScheme),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
