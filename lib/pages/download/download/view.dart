import 'dart:async';

import 'package:PiliBro/common/widgets/appbar/appbar.dart';
import 'package:PiliBro/common/widgets/flutter/pop_scope.dart';
import 'package:PiliBro/common/widgets/loading_widget/http_error.dart';
import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/models_new/download/bili_download_entry_info.dart';
import 'package:PiliBro/models_new/download/download_info.dart';
import 'package:PiliBro/pages/common/multi_select/base.dart';
import 'package:PiliBro/pages/download/detail/widgets/item.dart';
import 'package:PiliBro/pages/download/download/controller.dart';
import 'package:PiliBro/pages/download/download/widgets/page.dart';
import 'package:PiliBro/pages/download/download/widgets/season.dart';
import 'package:PiliBro/pages/download/download_action_mixin.dart';
import 'package:PiliBro/pages/download/search/view.dart';
import 'package:PiliBro/services/download/download_service.dart';
import 'package:PiliBro/utils/extension/iterable_ext.dart';
import 'package:PiliBro/utils/grid.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:collection/collection.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with GridMixin, BaseDownloadActionMixin<DownloadPage, DownloadSeasonInfo> {
  final _progress = ChangeNotifier();
  final _controller = Get.put(DownloadController());
  bool _showAudio = false;

  @override
  final downloadService = Get.find<DownloadService>();

  @override
  BaseMultiSelectMixin<DownloadSeasonInfo> get multiSelectCtr => _controller;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Future<void> onUpdate(
    Future<bool> Function(BiliDownloadEntryInfo e) toElement,
  ) async {
    if (checkUpdateCount(_controller.checkedCount)) return;

    bool dismiss = false;
    SmartDialog.showLoading(
      onDismiss: () {
        dismiss = true;
        _controller.handleSelect();
      },
    );

    bool isSuccess = true;
    for (final chunk in _controller.allChecked.mapChunked(
      kUpdateConcurrency,
      (season) async {
        bool isSuccess = true;
        for (final chunk in season.pages.mapChunked(
          kUpdateConcurrency,
          (page) async {
            bool isSuccess = true;
            for (final chunk in page.entries.mapChunked(
              kUpdateConcurrency,
              toElement,
            )) {
              final res = await Future.wait(chunk);
              if (res.any((e) => !e)) isSuccess = false;
              if (dismiss) break;
            }
            return isSuccess;
          },
        )) {
          final res = await Future.wait(chunk);
          if (res.any((e) => !e)) isSuccess = false;
          if (dismiss) break;
        }
        return isSuccess;
      },
    )) {
      final res = await Future.wait(chunk);
      if (res.any((e) => !e)) isSuccess = false;
      if (dismiss) break;
    }

    toastUpdateResult(dismiss, isSuccess);
  }

  Future<void> _updateSeasonDm(DownloadSeasonInfo seasonInfo) async {
    if (checkUpdateCount(
      seasonInfo.pages.fold(0, (a, b) => a + b.entries.length),
    )) {
      return;
    }

    bool dismiss = false;
    SmartDialog.showLoading(onDismiss: () => dismiss = true);

    bool isSuccess = true;

    for (final page in seasonInfo.pages) {
      for (final chunk in page.entries.mapChunked(
        kUpdateConcurrency,
        (e) => downloadService.downloadDanmaku(
          entry: e,
          isUpdate: true,
        ),
      )) {
        final res = await Future.wait(chunk);
        if (res.any((e) => !e)) isSuccess = false;
        if (dismiss) break;
      }
    }

    toastUpdateResult(dismiss, isSuccess);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    return Obx(() {
      final enableMultiSelect = _controller.enableMultiSelect.value;
      return popScope(
        canPop: !enableMultiSelect && !_showAudio,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (enableMultiSelect) {
            _controller.handleSelect();
          } else if (_showAudio) {
            setState(() => _showAudio = false);
          }
        },
        child: SimpleScaffold(
          appBar: MultiSelectAppBarWidget(
            ctr: _controller,
            actions: [if (!_showAudio) updateBtn()],
            child: AppBar(
              title: Text(_showAudio ? '下载的音频' : '离线缓存'),
              leading: _showAudio
                  ? IconButton(
                      tooltip: '返回缓存列表',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (enableMultiSelect) _controller.handleSelect();
                        setState(() => _showAudio = false);
                      },
                    )
                  : null,
              actions: [
                if (!_showAudio)
                  IconButton(
                  tooltip: '搜索',
                  onPressed: () async {
                    await downloadService.waitForInitialization;
                    if (!mounted) return;
                    Get.to(DownloadSearchPage(progress: _progress));
                  },
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  tooltip: '多选',
                  onPressed: () {
                    if (enableMultiSelect) {
                      _controller.handleSelect();
                    } else {
                      _controller.enableMultiSelect.value = true;
                    }
                  },
                  icon: const Icon(Icons.edit_note),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          body: Padding(
            padding: EdgeInsets.only(left: padding.left, right: padding.right),
            child: CustomScrollView(
              slivers: [
                if (!_showAudio)
                  Obx(() {
                    final audioCount = _controller.seasons
                        .where((e) => e.audioOnly)
                        .fold<int>(
                          0,
                          (count, season) =>
                              count + season.pages.first.entries.length,
                        );
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Material(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _showAudio = true),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 15,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.folder_outlined, size: 30),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('下载的音频'),
                                        Text(
                                          '$audioCount 个音频',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                if (!_showAudio)
                  Obx(() {
                  final entry =
                      downloadService.waitDownloadQueue.firstWhereOrNull(
                        (e) => e.cid == downloadService.curCid,
                      ) ??
                      downloadService.waitDownloadQueue.firstOrNull;
                  if (entry != null) {
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.only(left: 12, bottom: 7),
                          sliver: SliverToBoxAdapter(
                            child: Text(
                              '正在缓存 (${downloadService.waitDownloadQueue.length})',
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 110,
                            child: DetailItem(
                              entry: entry,
                              progress: _progress,
                              downloadService: downloadService,
                              showTitle: true,
                              isCurr: true,
                              controller: _controller,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return const SliverToBoxAdapter();
                }),
                Obx(() {
                  final seasons = _controller.seasons
                      .where((e) => e.audioOnly == _showAudio)
                      .toList(growable: false);
                  if (seasons.isNotEmpty) {
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.only(
                            left: 12,
                            bottom: 7,
                            top: downloadService.waitDownloadQueue.isEmpty
                                ? 0
                                : 7,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Text(_showAudio ? '已缓存音频' : '已缓存视频'),
                          ),
                        ),
                        SliverGrid.builder(
                          gridDelegate: gridDelegate,
                          itemBuilder: (context, index) {
                            final season = seasons[index];
                            final seasonInfo = season.seasonInfo;
                            final pages = season.pages;

                            if (seasonInfo != null && pages.length > 1) {
                              return SeasonInfoItem(
                                controller: _controller,
                                downloadService: downloadService,
                                seasonInfo: seasonInfo,
                                season: season,
                                enableMultiSelect: enableMultiSelect,
                                progress: _progress,
                                updateSeasonDm: _updateSeasonDm,
                              );
                            }

                            final page = pages.first;
                            if (pages.length == 1 && page.entries.length == 1) {
                              final entry = page.entries.first;
                              return DetailItem(
                                entry: entry,
                                progress: _progress,
                                downloadService: downloadService,
                                showTitle: true,
                                onDelete: () {
                                  downloadService.deleteDownload(
                                    entry: entry,
                                    removeList: true,
                                  );
                                  GStorage.watchProgress.delete(
                                    entry.cid.toString(),
                                  );
                                },
                                checked: season.checked,
                                onSelect: (_) => _controller.onSelect(season),
                                controller: _controller,
                              );
                            }

                            return PageInfoItem(
                              controller: _controller,
                              downloadService: downloadService,
                              seasonInfo: season,
                              pageInfo: page,
                              enableMultiSelect: enableMultiSelect,
                              progress: _progress,
                              updatePageDm: updatePageDm,
                            );
                          },
                          itemCount: seasons.length,
                        ),
                      ],
                    );
                  }
                  if (!_showAudio &&
                      downloadService.waitDownloadQueue.isNotEmpty) {
                    return const SliverToBoxAdapter();
                  }
                  return _showAudio
                      ? const SliverToBoxAdapter(
                          child: Center(child: Text('还没有下载的音频')),
                        )
                      : const HttpError();
                }),
                SliverToBoxAdapter(
                  child: SizedBox(height: padding.bottom + 100),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
