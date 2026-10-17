import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:PiliBro/pages/mine/controller.dart';
import 'package:PiliBro/services/brotech_scripts.dart';
import 'package:PiliBro/services/comment_helper_service.dart';
import 'package:PiliBro/services/playback_archive_service.dart';
import 'package:PiliBro/services/playback_stats_service.dart';
import 'package:PiliBro/services/traffic_stats_service.dart';
import 'package:PiliBro/services/watch_log_service.dart';
import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/accounts/account.dart';
import 'package:PiliBro/utils/login_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

/// What a backup can hold. The names go into manifests and the remembered
/// selection, so they stay as they are.
enum BackupPart {
  settings('设置', text: true),
  searchHistory('搜索历史', text: true),
  accounts('登录信息', text: true),
  playbackStats('倍速统计'),
  watchLog('观看日志'),
  launchYears('历年打开天数', text: true),
  replies('我的评论'),
  commentHelper('评论助手'),
  trafficStats('流量统计'),
  cdnDiagnostics('CDN 诊断'),
  scriptValues('脚本存储');

  const BackupPart(this.label, {this.text = false});

  final String label;

  /// JSON small enough to travel as text: clipboard, QR code.
  final bool text;

  bool get available =>
      this != trafficStats || Platform.isAndroid || Platform.isWindows;

  static final byName = BackupPart.values.asNameMap();
}

/// One snapshot format behind every way out: a set of part files plus a
/// manifest. WebDAV uploads them loose, a local file packs them into a zip,
/// text carries the JSON parts inline.
abstract final class BackupService {
  static const _manifest = 'manifest.json';
  static const _archive = 'playback_archive.hive';

  static Object? _json(BackupPart part) => switch (part) {
    BackupPart.settings => {
      GStorage.setting.name: GStorage.setting.toMap(),
      GStorage.video.name: GStorage.video.toMap(),
    },
    BackupPart.searchHistory =>
      GStorage.historyWord.get('cacheList') ?? const <String>[],
    BackupPart.accounts => Accounts.account.toMap(),
    BackupPart.launchYears => {
      ...?GStorage.localCache.get(LocalCacheKey.launchYears) as Map?,
      if (GStorage.localCache.get(LocalCacheKey.launchDay, defaultValue: 0)
          case final int stamp when stamp != 0)
        '${stamp ~/ 10000000}': stamp % 1000,
    },
    _ => throw StateError('${part.name} is not text'),
  };

  static String exportJson(Set<BackupPart> parts) => jsonEncode({
    'databaseVersion': GStorage.databaseVersion,
    'parts': {for (final part in parts) part.name: _json(part)},
  });

  /// Writes [parts] into [dir]. Live stores are copied so the snapshot is
  /// consistent; finished watch-log segments never change and are taken
  /// where they lie.
  static Future<Map<BackupPart, List<File>>> collect(
    Set<BackupPart> parts,
    Directory dir,
  ) async {
    final locked =
        parts.contains(BackupPart.playbackStats) ||
        parts.contains(BackupPart.watchLog);
    if (locked) await PlaybackArchiveService.beginExplicitAccess();
    try {
      return {
        for (final part in parts)
          if (await _collect(part, dir) case final files
              when files.isNotEmpty)
            part: files,
      };
    } finally {
      if (locked) PlaybackArchiveService.endExplicitAccess();
    }
  }

  static Future<List<File>> _collect(BackupPart part, Directory dir) async {
    File to(String name) => File(path.join(dir.path, name));
    switch (part) {
      case BackupPart.playbackStats:
        await GStorage.initializePlaybackStats();
        final hot = await PlaybackStatsService.copyHiveSnapshot(
          to('playback_stats.hive'),
        );
        final archive = await PlaybackArchiveService.copyArchiveSnapshot(
          to(_archive),
        );
        return [hot, ?archive];
      case BackupPart.watchLog:
        return [
          for (final log in await WatchLogService.files())
            path.basename(log.path) == 'watchlog.jsonl'
                ? await log.copy(to('watchlog.jsonl').path)
                : log,
        ];
      case BackupPart.replies:
        await GStorage.reply?.flush();
        final reply = GStorage.replyHiveFile;
        return [
          if (await reply.exists()) await reply.copy(to('reply.hive').path),
        ];
      case BackupPart.commentHelper:
        await GStorage.commentHelper.flush();
        return [
          await GStorage.commentHelperHiveFile.copy(
            to('comment_helper.hive').path,
          ),
        ];
      case BackupPart.trafficStats:
        final traffic = await TrafficStatsService.instance.copyHiveSnapshot(
          to('traffic_stats.hive'),
        );
        return [?traffic];
      case BackupPart.cdnDiagnostics:
        return [
          for (final source in [
            GStorage.cdnDiagnosticsFile,
            GStorage.cdnDiagnosticsHistoryFile,
          ])
            if (await source.exists())
              await source.copy(to(path.basename(source.path)).path),
        ];
      case BackupPart.scriptValues:
        final values = await BroTechGmStore.copySnapshot(
          to('brotech_gm.hive'),
        );
        return [?values];
      default:
        return [
          await to('${part.name}.json').writeAsString(jsonEncode(_json(part))),
        ];
    }
  }

  static Future<String> _sha256(File file) async =>
      '${await sha256.bind(file.openRead()).first}';

  static Future<Map<String, dynamic>> manifest(
    Map<BackupPart, List<File>> parts,
  ) async => {
    'databaseVersion': GStorage.databaseVersion,
    'parts': {
      for (final MapEntry(key: part, value: files) in parts.entries)
        part.name: [
          for (final file in files)
            {
              'file': path.basename(file.path),
              'bytes': await file.length(),
              'sha256': await _sha256(file),
            },
        ],
    },
  };

  /// Brings the files of [chosen] into [dir] through [write] and checks each
  /// against [manifest] before anything local is touched.
  static Future<Map<BackupPart, List<File>>> receive(
    Map manifest,
    Set<BackupPart> chosen,
    Directory dir,
    Future<void> Function(String name, File target) write,
  ) async {
    final parts = manifest['parts'] as Map;
    final received = <BackupPart, List<File>>{};
    for (final part in chosen) {
      final files = received[part] = [];
      for (final Map entry in parts[part.name] as List) {
        final name = entry['file'];
        if (name is! String || path.basename(name) != name) {
          throw const FormatException('备份清单无效');
        }
        final target = File(path.join(dir.path, name));
        await write(name, target);
        if (await target.length() != entry['bytes'] ||
            await _sha256(target) != entry['sha256']) {
          throw FormatException('$name 校验失败');
        }
        files.add(target);
      }
    }
    return received;
  }

  /// Settings go last: they flip switches the other parts are read under.
  static Future<void> restore(Map<BackupPart, List<File>> parts) async {
    final locked =
        parts.containsKey(BackupPart.playbackStats) ||
        parts.containsKey(BackupPart.watchLog);
    if (locked) await PlaybackArchiveService.beginExplicitAccess();
    try {
      for (final part in BackupPart.values) {
        if (parts[part] case final files? when part != BackupPart.settings) {
          await _restore(part, files);
        }
      }
      if (parts[BackupPart.settings] case final files?) {
        await _restore(BackupPart.settings, files);
      }
    } finally {
      if (locked) {
        PlaybackArchiveService.endExplicitAccess();
        unawaited(PlaybackArchiveService.archiveIfDue());
      }
    }
  }

  static Future<void> _restore(BackupPart part, List<File> files) async {
    Future<dynamic> decoded() async =>
        jsonDecode(await files.single.readAsString());
    switch (part) {
      case BackupPart.settings:
        final Map boxes = await decoded();
        for (final box in [GStorage.setting, GStorage.video]) {
          await box.clear();
          await box.putAll(boxes[box.name] as Map);
        }
      case BackupPart.searchHistory:
        await GStorage.historyWord.put(
          'cacheList',
          List<String>.from(await decoded()),
        );
      case BackupPart.accounts:
        final Map accounts = await decoded();
        await Accounts.account.putAll({
          for (final MapEntry(:key, :value) in accounts.entries)
            key: LoginAccount.fromJson(value),
        });
        await Accounts.refresh();
        MineController.anonymity.value = !Accounts.heartbeat.isLogin;
        if (Accounts.main.isLogin) await LoginUtils.onLoginMain();
      case BackupPart.launchYears:
        // Old phone to new: per year the larger count wins, so restoring the
        // same backup twice changes nothing.
        final Map years = await decoded();
        final cache = GStorage.localCache;
        final history = {...?cache.get(LocalCacheKey.launchYears) as Map?};
        final stamp =
            cache.get(LocalCacheKey.launchDay, defaultValue: 0) as int;
        for (final MapEntry(:key, :value) in years.entries) {
          if (key == '${stamp ~/ 10000000}') {
            if (value > stamp % 1000) {
              await cache.put(
                LocalCacheKey.launchDay,
                stamp - stamp % 1000 + value,
              );
            }
          } else if (value > (history[key] ?? 0)) {
            history[key] = value;
          }
        }
        await cache.put(LocalCacheKey.launchYears, history);
      case BackupPart.playbackStats:
        File? hot, archive;
        for (final file in files) {
          if (path.basename(file.path) == _archive) {
            archive = file;
          } else {
            hot = file;
          }
        }
        await PlaybackStatsService.restoreHiveSnapshot(
          hot!,
          archiveSource: archive,
        );
      case BackupPart.watchLog:
        await WatchLogService.restore(files);
      case BackupPart.replies:
        await GStorage.restoreReplyHive(files.single);
      case BackupPart.commentHelper:
        await GStorage.restoreCommentHelperHive(files.single);
        CommentHelperService.revision.value++;
      case BackupPart.trafficStats:
        await TrafficStatsService.instance.initialize();
        await TrafficStatsService.instance.restoreHive(files.single);
      case BackupPart.cdnDiagnostics:
        for (final target in [
          GStorage.cdnDiagnosticsFile,
          GStorage.cdnDiagnosticsHistoryFile,
        ]) {
          if (await target.exists()) await target.delete();
          final name = path.basename(target.path);
          for (final file in files) {
            if (path.basename(file.path) == name) await file.copy(target.path);
          }
        }
      case BackupPart.scriptValues:
        await BroTechGmStore.restore(files.single);
    }
  }

  static Future<Uint8List> zip(Set<BackupPart> parts) async {
    final dir = await Directory.systemTemp.createTemp('pilibro-backup-');
    try {
      final files = await collect(parts, dir);
      final out = path.join(dir.path, 'backup.zip');
      final encoder = ZipFileEncoder()..create(out);
      await encoder.addFile(
        await File(
          path.join(dir.path, _manifest),
        ).writeAsString(jsonEncode(await manifest(files))),
      );
      for (final file in files.values.expand((list) => list)) {
        // Segments are gzip already; deflating them again only costs time.
        await encoder.addFile(
          file,
          null,
          file.path.endsWith('.gz') ? ZipFileEncoder.store : null,
        );
      }
      await encoder.close();
      return await File(out).readAsBytes();
    } finally {
      await dir.delete(recursive: true);
    }
  }

  /// False when [choose] declined.
  static Future<bool> restoreZip(
    String zipPath,
    Future<Set<BackupPart>?> Function(Map manifest) choose,
  ) async {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      final manifest =
          jsonDecode(
                utf8.decode(
                  archive.find(_manifest)?.readBytes() ??
                      (throw const FormatException('不是 PiliBro 备份')),
                ),
              )
              as Map;
      final chosen = await choose(manifest);
      if (chosen == null) return false;
      final dir = await Directory.systemTemp.createTemp('pilibro-backup-');
      try {
        await restore(
          await receive(manifest, chosen, dir, (name, target) async {
            final output = OutputFileStream(target.path);
            archive.find(name)!.writeContent(output);
            await output.close();
          }),
        );
      } finally {
        await dir.delete(recursive: true);
      }
      return true;
    } finally {
      await input.close();
    }
  }

  /// False when [choose] declined.
  static Future<bool> restoreJson(
    Map json,
    Future<Set<BackupPart>?> Function(Map manifest) choose,
  ) async {
    final chosen = await choose(json);
    if (chosen == null) return false;
    final dir = await Directory.systemTemp.createTemp('pilibro-backup-');
    try {
      final parts = json['parts'] as Map;
      await restore({
        for (final part in chosen)
          part: [
            await File(
              path.join(dir.path, '${part.name}.json'),
            ).writeAsString(jsonEncode(parts[part.name])),
          ],
      });
      return true;
    } finally {
      await dir.delete(recursive: true);
    }
  }
}
