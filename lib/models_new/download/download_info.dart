import 'package:PiliBro/models_new/download/bili_download_entry_info.dart';
import 'package:PiliBro/pages/common/multi_select/base.dart'
    show MultiSelectData;

class DownloadPageInfo with MultiSelectData {
  final String pageId;
  final bool audioOnly;
  final String dirPath;
  final String title;
  String cover;
  int sortKey;
  final int? seasonType;
  final List<BiliDownloadEntryInfo> entries;

  DownloadPageInfo({
    required this.pageId,
    this.audioOnly = false,
    required this.dirPath,
    required this.title,
    required this.cover,
    required this.sortKey,
    this.seasonType,
    required this.entries,
  });
}

class DownloadSeasonInfo with MultiSelectData {
  SeasonInfo? seasonInfo;
  final String pageId;
  final List<DownloadPageInfo> pages;

  bool get audioOnly => pages.first.audioOnly;

  DownloadSeasonInfo({
    required this.seasonInfo,
    required this.pageId,
    required this.pages,
  });
}
