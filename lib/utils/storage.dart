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
  static late final Box<int> watchProgress;
  static late final Box<Uint8List>? reply;

  static const _heavyTelemetryMigrationKey = 'heavyTelemetryExternalV1';
  static const _cdnDiagnosticPrefix = 'cdnDiagnostic:';

  static File get playbackStatsFile =>
      File(path.join(appSupportDirPath, 'playback_stats.json'));

  static File get trafficStatsFile =>
      File(path.join(appSupportDirPath, 'traffic_stats.json'));

  static File get cdnDiagnosticsFile =>
      File(path.join(appSupportDirPath, 'cdn_diagnostics.jsonl'));

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
    final result = <({String id, Map<String, dynamic> record})>[];
    try {
      for (final line in cdnDiagnosticsFile.readAsLinesSync()) {
        if (line.trim().isEmpty) continue;
        try {
          final decoded = jsonDecode(line);
          if (decoded is! Map) continue;
          final id = decoded['id']?.toString();
          final raw = decoded['record'];
          if (id == null || raw is! Map) continue;
          result.add((
            id: id,
            record: raw.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ));
        } catch (_) {
          // One damaged diagnostic line must not hide the rest of the history.
        }
      }
    } catch (_) {}
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
    final sink = cdnDiagnosticsFile.openWrite(mode: FileMode.write);
    try {
      for (final entry in entries) {
        sink.writeln(jsonEncode({'id': entry.id, 'record': entry.record}));
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  static Future<void> appendCdnDiagnostic(
    ({String id, Map<String, dynamic> record}) entry,
  ) async {
    await cdnDiagnosticsFile.parent.create(recursive: true);
    await cdnDiagnosticsFile.writeAsString(
      '${jsonEncode({'id': entry.id, 'record': entry.record})}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  static List<({String id, Map<String, dynamic> record})>
  _legacyCdnDiagnostics() {
    final result = <({String id, Map<String, dynamic> record})>[];
    for (final key in video.keys) {
      if (key is! String || !key.startsWith(_cdnDiagnosticPrefix)) continue;
      final raw = video.get(key);
      if (raw is Map) {
        result.add((
          id: key,
          record: raw.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        ));
      }
    }
    return result;
  }

  static Future<void> migrateHeavyTelemetryFromVideoBox() async {
    if (localCache.get(_heavyTelemetryMigrationKey, defaultValue: false) ==
        true) {
      return;
    }

    final keysToDelete = <dynamic>[];

    final legacyPlayback = video.get(VideoBoxKey.playbackStats);
    if (legacyPlayback is Map) {
      if (!playbackStatsFile.existsSync()) {
        await writeJsonFile(playbackStatsFile, legacyPlayback);
      }
      keysToDelete.add(VideoBoxKey.playbackStats);
    }

    final legacyTraffic = video.get(VideoBoxKey.trafficStats);
    if (legacyTraffic is Map) {
      if (!trafficStatsFile.existsSync()) {
        await writeJsonFile(trafficStatsFile, legacyTraffic);
      }
      keysToDelete.add(VideoBoxKey.trafficStats);
    }

    final legacyDiagnostics = _legacyCdnDiagnostics();
    if (legacyDiagnostics.isNotEmpty) {
      final merged = <String, Map<String, dynamic>>{
        for (final entry in readCdnDiagnosticsSync())
          entry.id: entry.record,
        for (final entry in legacyDiagnostics)
          entry.id: entry.record,
      };
      await replaceCdnDiagnostics([
        for (final entry in merged.entries)
          (id: entry.key, record: entry.value),
      ]);
      keysToDelete.addAll(
        legacyDiagnostics.map((entry) => entry.id),
      );
    }

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
      Accounts.init(),
      Hive.openBox<int>(
        'watchProgress',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 4;
        },
      ).then((res) => watchProgress = res),
    ]);

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
      final playback =
          readJsonMapSync(playbackStatsFile) ??
          (video.get(VideoBoxKey.playbackStats) case final Map raw
              ? raw.map((key, value) => MapEntry(key.toString(), value))
              : null);
      if (playback != null) {
        videoData[VideoBoxKey.playbackStats] = playback;
      }
    }

    final traffic =
        readJsonMapSync(trafficStatsFile) ??
        (video.get(VideoBoxKey.trafficStats) case final Map raw
            ? raw.map((key, value) => MapEntry(key.toString(), value))
            : null);
    if (traffic != null) {
      videoData[VideoBoxKey.trafficStats] = traffic;
    }

    if (includeCdnDiagnostics) {
      final diagnostics = <String, Map<String, dynamic>>{
        for (final entry in _legacyCdnDiagnostics())
          entry.id: entry.record,
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
    final meta = map['backupMeta'];
    final keepPlayback =
        meta is Map && meta['includePlaybackStats'] == false;
    final keepDiagnostics =
        meta is Map && meta['includeCdnDiagnostics'] == false;

    final preservedPlayback = keepPlayback
        ? readJsonMapSync(playbackStatsFile) ??
              (video.get(VideoBoxKey.playbackStats) case final Map raw
                  ? raw.map(
                      (key, value) => MapEntry(key.toString(), value),
                    )
                  : null)
        : null;

    final preservedDiagnostics = keepDiagnostics
        ? <String, Map<String, dynamic>>{
            for (final entry in _legacyCdnDiagnostics())
              entry.id: entry.record,
            for (final entry in readCdnDiagnosticsSync())
              entry.id: entry.record,
          }
        : const <String, Map<String, dynamic>>{};

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
        importedPlayback is Map
            ? writeJsonFile(playbackStatsFile, importedPlayback)
            : _deleteFileIfExists(playbackStatsFile)
      else if (preservedPlayback != null && !playbackStatsFile.existsSync())
        writeJsonFile(playbackStatsFile, preservedPlayback),
      importedTraffic is Map
          ? writeJsonFile(trafficStatsFile, importedTraffic)
          : _deleteFileIfExists(trafficStatsFile),
      if (!keepDiagnostics)
        replaceCdnDiagnostics([
          for (final entry in importedDiagnostics.entries)
            (id: entry.key, record: entry.value),
        ])
      else if (preservedDiagnostics.isNotEmpty)
        replaceCdnDiagnostics([
          for (final entry in preservedDiagnostics.entries)
            (id: entry.key, record: entry.value),
        ]),
    ]);

    return const <void>[];
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
      _deleteFileIfExists(playbackStatsFile),
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
