import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models/user/danmaku_rule_adapter.dart';
import 'package:PiliPlus/models/user/info.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account_adapter.dart';
import 'package:PiliPlus/utils/accounts/account_type_adapter.dart';
import 'package:PiliPlus/utils/accounts/cookie_jar_adapter.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/set_int_adapter.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
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

  static const _heavyTelemetryMigrationKey = 'heavyTelemetryExternalV2';
  static const _nextPlaybackStatsCompactAtMs =
      'nextPlaybackStatsCompactAtMs';
  static const _cdnDiagnosticPrefix = 'cdnDiagnostic:';

  static File get playbackStatsFile =>
      File(path.join(appSupportDirPath, 'playback_stats.json'));

  static File get trafficStatsFile =>
      File(path.join(appSupportDirPath, 'traffic_stats.json'));

  static File get cdnDiagnosticsFile =>
      File(path.join(appSupportDirPath, 'cdn_diagnostic_latest.json'));

  static File get legacyCdnDiagnosticsFile =>
      File(path.join(appSupportDirPath, 'cdn_diagnostics.jsonl'));

  static File get playbackStatsHiveFile =>
      File(
        _playbackStats?.path ??
            path.join(appSupportDirPath, 'hive', 'playbackStats.hive'),
      );

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
    if (legacyCdnDiagnosticsFile.existsSync()) {
      unawaited(_deleteFileIfExists(legacyCdnDiagnosticsFile));
    }
    if (!cdnDiagnosticsFile.existsSync()) return const [];
    // A latest-result snapshot is intentionally tiny. Anything large is an
    // obsolete per-chunk history and must never be synchronously decoded.
    if (cdnDiagnosticsFile.lengthSync() > 8 * 1024 * 1024) {
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
    await cdnDiagnosticsFile.parent.create(recursive: true);
    final temp = File('${cdnDiagnosticsFile.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'schemaVersion': 3,
        'records': [for (final entry in entries) entry.record],
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

  static Future<void> migrateHeavyTelemetryFromVideoBox() async {
    if (localCache.get(_heavyTelemetryMigrationKey, defaultValue: false) ==
        true) {
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

    // Historical CDN records intentionally have no migration path: their
    // per-chunk arrays are the old storage bug. Delete keys by name without
    // decoding their values.
    keysToDelete.addAll(
      video.keys.where(
        (key) => key is String && key.startsWith(_cdnDiagnosticPrefix),
      ),
    );
    unawaited(_deleteFileIfExists(legacyCdnDiagnosticsFile));

    if (keysToDelete.isNotEmpty) {
      await video.deleteAll(keysToDelete);
    }

    // The old 30-second full-map telemetry writes leave large stale Hive
    // frames behind. Compact once after the first visible frame so future cold
    // starts no longer scan hundreds of MiB of obsolete data.
    await video.compact();
    await localCache.put(_heavyTelemetryMigrationKey, true);
  }

  static Future<void> init() async {
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

    await _runPlaybackMaintenanceIfDue();

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

  static Future<void> _runPlaybackMaintenanceIfDue() async {
    final now = DateTime.now();
    final due = localCache.get(
      _nextPlaybackStatsCompactAtMs,
      defaultValue: 0,
    );
    if (due is! num || now.millisecondsSinceEpoch < due.toInt()) return;

    // This deliberately runs before the first home frame. Compaction is rare,
    // while opening a bloated hot store on every launch is expensive.
    await initializePlaybackStats();
    await playbackStats.compact();
    await localCache.put(
      _nextPlaybackStatsCompactAtMs,
      _nextPlaybackMaintenanceAt(now).millisecondsSinceEpoch,
    );
  }

  static DateTime _nextPlaybackMaintenanceAt(DateTime now) {
    for (final day in const [8, 18, 28]) {
      final candidate = DateTime(now.year, now.month, day);
      if (candidate.isAfter(now)) return candidate;
    }
    final nextMonth = DateTime(now.year, now.month + 1);
    return DateTime(nextMonth.year, nextMonth.month, 8);
  }

  static String exportAllSettings({
    bool includePlaybackStats = true,
    bool includeCdnDiagnostics = true,
  }) {
    final videoData = Map<dynamic, dynamic>.from(video.toMap())
      ..remove(VideoBoxKey.playbackStats)
      ..remove(VideoBoxKey.trafficStats)
      ..removeWhere(
        (key, _) =>
            key is String && key.startsWith(_cdnDiagnosticPrefix),
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
      final diagnostics = <String, Map<String, dynamic>>{
        for (final entry in readCdnDiagnosticsSync())
          entry.id: entry.record,
      };
      videoData.addAll(diagnostics);
    }

    return Utils.jsonEncoder.convert({
      'backupMeta': {
        'includePlaybackStats': includePlaybackStats,
        'includeCdnDiagnostics': includeCdnDiagnostics,
      },
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

    final importedSettings = Map<dynamic, dynamic>.from(
      map[setting.name] as Map? ?? const {},
    );
    final importedVideo = Map<dynamic, dynamic>.from(
      map[video.name] as Map? ?? const {},
    );

    final importedPlayback = importedVideo.remove(VideoBoxKey.playbackStats);
    final importedTraffic = importedVideo.remove(VideoBoxKey.trafficStats);
    final importedDiagnostics = <String, Map<String, dynamic>>{};
    importedVideo.removeWhere((key, value) {
      if (key is String &&
          key.startsWith(_cdnDiagnosticPrefix) &&
          value is Map) {
        importedDiagnostics[key] = value.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        return true;
      }
      return false;
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
      importedTraffic is Map
          ? writeJsonFile(trafficStatsFile, importedTraffic)
          : _deleteFileIfExists(trafficStatsFile),
      if (!keepDiagnostics)
        replaceCdnDiagnostics([
          for (final entry in importedDiagnostics.entries)
            (id: entry.key, record: entry.value),
        ]),
    ]);

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

  static Future<List<void>> compact() {
    return Future.wait([
      userInfo.compact(),
      historyWord.compact(),
      localCache.compact(),
      setting.compact(),
      video.compact(),
      if (_playbackStats case final box?) box.compact(),
      commentHelper.compact(),
      Accounts.account.compact(),
      watchProgress.compact(),
      ?reply?.compact(),
    ]);
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
