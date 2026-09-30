import 'dart:async' show Completer;
import 'dart:convert';
import 'dart:io';

import 'package:PiliBro/services/playback_stats_service.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:hive_ce/hive.dart';

/// Cold storage: never opened by the normal playback/statistics path.
/// The one mutable archive record per shard is updated only at 8/18/28 rollover.
abstract final class PlaybackArchiveService {
  static Future<void>? _operation;
  static int _explicitAccess = 0;
  static Completer<void>? _explicitLock;

  static Future<void> beginExplicitAccess() async {
    // Explicit export, import and advanced view may not close one another's
    // LazyBox. This lock is never acquired by routine playback.
    while (_explicitLock != null) await _explicitLock!.future;
    final lock = Completer<void>();
    _explicitLock = lock;
    try {
      await waitForMaintenance();
      if (await GStorage.playbackStatsPendingHiveFile.exists()) {
        await archiveIfDue();
      }
      _explicitAccess++;
      await waitForMaintenance();
      if (await GStorage.playbackStatsPendingHiveFile.exists()) {
        _explicitAccess--;
        throw StateError('Playback archive remains unfinished');
      }
    } catch (_) {
      _explicitLock = null;
      lock.complete();
      rethrow;
    }
  }

  static void endExplicitAccess() {
    _explicitAccess--;
    final lock = _explicitLock;
    _explicitLock = null;
    lock?.complete();
  }

  static Future<void> waitForMaintenance() async {
    final running = _operation;
    if (running != null) await running;
  }

  static Future<void> archiveIfDue() =>
      _operation ??= _archiveIfDue().whenComplete(() => _operation = null);

  static Future<void> _archiveIfDue() async {
    if (_explicitAccess > 0) return;
    // Every normal timer tick is one scalar check. Do not stat/open cold files
    // or even touch the playback service until a real rollover is due.
    if (!GStorage.playbackArchiveDue && GStorage.playbackArchiveId == null) {
      return;
    }
    await GStorage.initializePlaybackStats();
    if (_explicitAccess > 0) return;
    final pending = await GStorage.playbackStatsPendingHiveFile.exists();
    if (!pending) await GStorage.discardOrphanPlaybackArchiveId();
    if (!pending && !GStorage.playbackArchiveDue) return;
    if (!pending) {
      // Drain writes, then atomically exchange the in-memory active period;
      // events recorded while Hive rotates belong to the NEW period.
      await GStorage.preparePlaybackArchiveId();
      await PlaybackStatsService.prepareArchiveRollover();
      try {
        await GStorage.rotatePlaybackStats();
      } catch (_) {
        // Rotation reopens the old hot box if rename fails.
        PlaybackStatsService.reloadFromStorage();
        rethrow;
      } finally {
        PlaybackStatsService.endArchiveRollover();
      }
      await PlaybackStatsService.flush(force: true);
    }
    await _mergePending();
    await GStorage.completePlaybackArchive();
    await Hive.deleteBoxFromDisk('playbackStatsPending');
    await GStorage.finishPlaybackArchive();
  }

  static bool _metadata(String key) =>
      key == 'schemaVersion' ||
      key == 'metricDefinitionVersion' ||
      key == 'storageLayoutVersion' ||
      key == 'lastSelectedSpeed';

  // Per-shard merge. No archive.toMap(), no cumulative composite recopy.
  static dynamic _merge(dynamic oldValue, dynamic increment, String key) {
    if (increment == null) return oldValue;
    if (oldValue == null) return increment;
    if (oldValue is num && increment is num) {
      if (_metadata(key)) return increment;
      if (key == 'createdAtMs' || key == 'firstSeenAtMs') {
        return oldValue < increment ? oldValue : increment;
      }
      if (key == 'updatedAtMs' || key == 'lastSeenAtMs') {
        return oldValue > increment ? oldValue : increment;
      }
      return oldValue + increment;
    }
    if (oldValue is Map && increment is Map) {
      final merged = <dynamic, dynamic>{...oldValue};
      for (final entry in increment.entries) {
        merged[entry.key] = _merge(
          merged[entry.key], entry.value, entry.key.toString(),
        );
      }
      return merged;
    }
    // Names, strings, booleans and any non-additive values use the latest value.
    return increment;
  }

  static Future<void> _mergePending() async {
    final id = GStorage.playbackArchiveId;
    if (id == null) throw StateError('Missing playback archive transaction ID');
    final pending = await Hive.openLazyBox<dynamic>('playbackStatsPending');
    final archive = await Hive.openLazyBox<dynamic>('playbackArchive');
    try {
      final writes = <dynamic, dynamic>{};
      for (final key in pending.keys) {
        final name = key.toString();
        final fresh = await pending.get(key);
        final previous = await archive.get(name);
        if (previous is Map && previous['_sourceId'] == id) continue;
        final oldValue = previous is Map && previous.containsKey('_value')
            ? previous['_value']
            : null;
        writes[name] = {
          '_sourceId': id,
          '_value': _merge(oldValue, fresh, name),
        };
        if (writes.length == 24) {
          await archive.putAll(writes);
          writes.clear();
          await Future<void>.delayed(Duration.zero);
        }
      }
      if (writes.isNotEmpty) await archive.putAll(writes);
      await archive.flush();
    } finally {
      await archive.close();
      await pending.close();
    }
  }

  /// The only full archive traversal, used by an explicit user action.
  static Future<Map<String, dynamic>> loadRawArchive() async {
    if (await GStorage.playbackStatsPendingHiveFile.exists()) {
      if (_explicitAccess > 0) throw StateError('Playback archive pending during export');
      await archiveIfDue();
    }
    await waitForMaintenance();
    final historical = <String, dynamic>{};
    if (!await GStorage.playbackArchiveHiveFile.exists()) return historical;
    final archive = await Hive.openLazyBox<dynamic>('playbackArchive');
    try {
      var count = 0;
      for (final key in archive.keys) {
        final data = await archive.get(key);
        if (data is Map && data.containsKey('_value')) {
          historical[key.toString()] = data['_value'];
        }
        if (++count % 24 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    } finally {
      await archive.close();
    }
    return historical;
  }

  /// Called only by expanding Advanced Statistics, never by its parent page.
  static Future<String> advancedJson() async {
    await beginExplicitAccess();
    try {
      final historical = await loadRawArchive();
      final active = jsonDecode(PlaybackStatsService.advancedJson());
      return const JsonEncoder.withIndent('  ').convert({
        '活动统计': active,
        '历史归档原语': historical,
      });
    } finally {
      endExplicitAccess();
    }
  }

  /// A user-triggered snapshot; an empty archive still gets a real Hive file.
  static Future<File> copyArchiveSnapshot(File destination) async {
    await waitForMaintenance();
    if (!await GStorage.playbackArchiveHiveFile.exists()) {
      final archive = await Hive.openLazyBox<dynamic>('playbackArchive');
      try {
        await archive.put('__archiveFormat', 1);
        await archive.flush();
      } finally {
        await archive.close();
      }
    }
    await destination.parent.create(recursive: true);
    return GStorage.playbackArchiveHiveFile.copy(destination.path);
  }

  static Future<void> resetArchive() async {
    await beginExplicitAccess();
    try {
      if (await GStorage.playbackArchiveHiveFile.exists()) {
        await Hive.deleteBoxFromDisk('playbackArchive');
      }
      if (await GStorage.playbackStatsPendingHiveFile.exists()) {
        await Hive.deleteBoxFromDisk('playbackStatsPending');
      }
      await GStorage.markPlaybackArchiveReset();
    } finally {
      endExplicitAccess();
    }
  }
}
