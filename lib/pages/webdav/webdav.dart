import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/pair.dart';
import 'package:PiliPlus/services/comment_helper_service.dart';
import 'package:PiliPlus/services/playback_stats_service.dart';
import 'package:PiliPlus/services/traffic_stats_service.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:path/path.dart' as path;
import 'package:webdav_client/webdav_client.dart' as webdav;

typedef _WebDavConfig = ({
  String uri,
  String username,
  String password,
  String directory,
});

abstract final class _ComponentName {
  static const settings = 'settings';
  static const playbackStats = 'playbackStats';
  static const replyHistory = 'replyHistory';
  static const commentHelper = 'commentHelper';
  static const trafficStats = 'trafficStats';
  static const cdnLatest = 'cdnLatest';
}

class WebDav {
  _WebDavConfig? _clientConfig;
  webdav.Client? _client;
  bool _busy = false;

  WebDav._internal();
  static final WebDav _instance = WebDav._internal();
  factory WebDav() => _instance;

  _WebDavConfig _getConfig() {
    String directory = Pref.webdavDirectory;
    if (!directory.endsWith('/')) {
      directory += '/';
    }
    return (
      uri: Pref.webdavUri,
      username: Pref.webdavUsername,
      password: Pref.webdavPassword,
      directory: '$directory${Constants.appName}',
    );
  }

  Future<webdav.Client> _connect(
    _WebDavConfig config, {
    bool force = false,
  }) async {
    final cachedClient = _client;
    if (!force && cachedClient != null && _clientConfig == config) {
      return cachedClient;
    }

    final client =
        webdav.newClient(
            config.uri,
            user: config.username,
            password: config.password,
          )
          ..setHeaders({'accept-charset': 'utf-8'})
          ..setConnectTimeout(12000)
          ..setReceiveTimeout(12000)
          ..setSendTimeout(12000);

    await client.mkdirAll(config.directory);
    _clientConfig = config;
    _client = client;
    return client;
  }

  Future<Pair<bool, String?>> init() async {
    try {
      await _connect(_getConfig(), force: true);
      return Pair(first: true, second: null);
    } catch (e) {
      return Pair(first: false, second: e.toString());
    }
  }

  String _getFileName() {
    return 'piliplus_settings_${DeviceUtils.platformName}.json';
  }

  String _snapshotDirectory(_WebDavConfig config) =>
      '${config.directory}/snapshot_${DeviceUtils.platformName}';

  Future<void> backup() async {
    if (_busy) {
      SmartDialog.showToast('备份或恢复正在进行');
      return;
    }
    _busy = true;
    final temp = await Directory.systemTemp.createTemp('piliplus-webdav-');
    try {
      await TrafficStatsService.instance.initialize();
      await GStorage.initializePlaybackStats();
      final config = _getConfig();
      final client = await _connect(config);
      final remoteDirectory = _snapshotDirectory(config);
      await client.mkdirAll(remoteDirectory);

      await Future.wait<void>([
        GStorage.setting.flush(),
        GStorage.video.flush(),
        GStorage.playbackStats.flush(),
        GStorage.commentHelper.flush(),
        if (GStorage.reply case final reply?) reply.flush(),
      ]);

      final components = <String, Map<String, dynamic>>{};
      final settingsFile = File(path.join(temp.path, 'settings.json'));
      await settingsFile.writeAsString(
        GStorage.exportAllSettings(
          includePlaybackStats: false,
          includeCdnDiagnostics: false,
        ),
        flush: true,
      );
      components[_ComponentName.settings] = await _snapshotFile(settingsFile);

      final trafficSnapshot = await TrafficStatsService.instance
          .copyHiveSnapshot(File(path.join(temp.path, 'traffic_stats.hive')));
      if (trafficSnapshot != null) {
        components[_ComponentName.trafficStats] = await _snapshotFile(
          trafficSnapshot,
        );
      }

      if (Pref.webdavBackupPlaybackStats) {
        final playbackSnapshot = await PlaybackStatsService.copyHiveSnapshot(
          File(path.join(temp.path, 'playback_stats.hive')),
        );
        components[_ComponentName.playbackStats] = await _snapshotFile(
          playbackSnapshot,
        );
      }

      if (Pref.webdavBackupCommentHistory) {
        if (await GStorage.replyHiveFile.exists()) {
          components[_ComponentName.replyHistory] = await _copySnapshot(
            GStorage.replyHiveFile,
            temp,
            'reply_history.hive',
          );
        }
        components[_ComponentName.commentHelper] = await _copySnapshot(
          GStorage.commentHelperHiveFile,
          temp,
          'comment_helper.hive',
        );
      }

      if (Pref.webdavBackupCdnDiagnostics &&
          await GStorage.cdnDiagnosticsFile.exists()) {
        components[_ComponentName.cdnLatest] = await _copySnapshot(
          GStorage.cdnDiagnosticsFile,
          temp,
          'cdn_latest.json',
        );
      }

      for (final component in components.values) {
        final fileName = component['file'] as String;
        await _uploadReplacing(
          client,
          File(path.join(temp.path, fileName)),
          '$remoteDirectory/$fileName',
        );
      }

      final manifestFile = File(path.join(temp.path, 'manifest.json'));
      await manifestFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': 1,
          'createdAtMs': DateTime.now().millisecondsSinceEpoch,
          'app': Constants.appName,
          'platform': DeviceUtils.platformName,
          'components': components,
        }),
        flush: true,
      );
      await _uploadReplacing(
        client,
        manifestFile,
        '$remoteDirectory/manifest.json',
      );
      SmartDialog.showToast('备份成功');
    } catch (e) {
      SmartDialog.showToast('备份失败: $e');
    } finally {
      _busy = false;
      try {
        await temp.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> restore() async {
    if (_busy) {
      SmartDialog.showToast('备份或恢复正在进行');
      return;
    }
    _busy = true;
    final temp = await Directory.systemTemp.createTemp('piliplus-webdav-');
    var localMutationStarted = false;
    try {
      await TrafficStatsService.instance.initialize();
      await GStorage.initializePlaybackStats();
      final config = _getConfig();
      final client = await _connect(config);
      final remoteDirectory = _snapshotDirectory(config);
      final manifestBytes = await client.read('$remoteDirectory/manifest.json');
      final manifest = jsonDecode(utf8.decode(manifestBytes));
      if (manifest is! Map || manifest['schemaVersion'] != 1) {
        throw const FormatException('备份清单版本不受支持');
      }
      final rawComponents = manifest['components'];
      if (rawComponents is! Map) {
        throw const FormatException('备份清单缺少文件列表');
      }
      final components = rawComponents.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final selected = <String>{
        _ComponentName.settings,
        _ComponentName.trafficStats,
        if (Pref.webdavBackupPlaybackStats) _ComponentName.playbackStats,
        if (Pref.webdavBackupCommentHistory) ...[
          _ComponentName.replyHistory,
          _ComponentName.commentHelper,
        ],
        if (Pref.webdavBackupCdnDiagnostics) _ComponentName.cdnLatest,
      };
      final downloaded = <String, File>{};
      for (final name in selected) {
        final raw = components[name];
        if (raw == null) continue;
        if (raw is! Map) throw FormatException('$name 的清单内容无效');
        downloaded[name] = await _downloadAndVerify(
          client,
          remoteDirectory,
          temp,
          raw,
        );
      }

      final settingsFile = downloaded[_ComponentName.settings];
      if (settingsFile == null) {
        throw const FormatException('备份缺少设置文件');
      }
      localMutationStarted = true;
      await GStorage.importAllSettings(await settingsFile.readAsString());

      if (downloaded[_ComponentName.playbackStats] case final file?) {
        await PlaybackStatsService.restoreHiveSnapshot(file);
      }
      if (downloaded[_ComponentName.replyHistory] case final file?) {
        await GStorage.restoreReplyHive(file);
      }
      if (downloaded[_ComponentName.commentHelper] case final file?) {
        await GStorage.restoreCommentHelperHive(file);
        CommentHelperService.revision.value++;
      }
      if (downloaded[_ComponentName.trafficStats] case final file?) {
        await TrafficStatsService.instance.restoreHive(file);
      }
      if (downloaded[_ComponentName.cdnLatest] case final file?) {
        await _replaceLocalFile(file, GStorage.cdnDiagnosticsFile);
      }
      SmartDialog.showToast('恢复成功');
    } catch (e) {
      if (localMutationStarted) {
        SmartDialog.showToast('恢复失败: $e');
      } else {
        await _restoreLegacyBackup(e);
      }
    } finally {
      _busy = false;
      try {
        await temp.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _restoreLegacyBackup(Object snapshotError) async {
    try {
      final config = _getConfig();
      final client = await _connect(config);
      final data = await client.read('${config.directory}/${_getFileName()}');
      await GStorage.importAllSettings(utf8.decode(data));
      SmartDialog.showToast('已恢复旧版设置备份');
    } catch (_) {
      SmartDialog.showToast('恢复失败: $snapshotError');
    }
  }

  Future<Map<String, dynamic>> _copySnapshot(
    File source,
    Directory temp,
    String fileName,
  ) async {
    if (!await source.exists()) {
      throw FileSystemException('找不到待备份文件', source.path);
    }
    final snapshot = await source.copy(path.join(temp.path, fileName));
    return _snapshotFile(snapshot);
  }

  Future<Map<String, dynamic>> _snapshotFile(File file) async => {
        'file': path.basename(file.path),
        'bytes': await file.length(),
        'sha256': await _sha256(file),
      };

  Future<String> _sha256(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<void> _uploadReplacing(
    webdav.Client client,
    File local,
    String remote,
  ) async {
    final uploading = '$remote.uploading';
    try {
      await client.remove(uploading);
    } catch (_) {}
    await client.writeFromFile(local.path, uploading);
    await client.rename(uploading, remote, true);
  }

  Future<File> _downloadAndVerify(
    webdav.Client client,
    String remoteDirectory,
    Directory temp,
    Map raw,
  ) async {
    final fileName = raw['file'];
    final expectedBytes = raw['bytes'];
    final expectedHash = raw['sha256'];
    if (fileName is! String ||
        expectedBytes is! num ||
        expectedHash is! String ||
        path.basename(fileName) != fileName) {
      throw const FormatException('备份文件清单无效');
    }
    final local = File(path.join(temp.path, fileName));
    await client.read2File('$remoteDirectory/$fileName', local.path);
    if (await local.length() != expectedBytes.toInt() ||
        await _sha256(local) != expectedHash) {
      throw FormatException('$fileName 校验失败');
    }
    return local;
  }

  Future<void> _replaceLocalFile(File source, File target) async {
    await target.parent.create(recursive: true);
    final staged = File('${target.path}.webdav-restore');
    if (await staged.exists()) await staged.delete();
    await source.copy(staged.path);
    if (await target.exists()) await target.delete();
    await staged.rename(target.path);
  }
}
