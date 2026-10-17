import 'dart:convert';
import 'dart:io';

import 'package:PiliBro/common/constants.dart';
import 'package:PiliBro/common/widgets/dialog/backup_dialog.dart';
import 'package:PiliBro/common/widgets/pair.dart';
import 'package:PiliBro/services/backup_service.dart';
import 'package:PiliBro/utils/device_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:path/path.dart' as path;
import 'package:webdav_client/webdav_client.dart' as webdav;

typedef _WebDavConfig = ({
  String uri,
  String username,
  String password,
  String directory,
});

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

  String _snapshotDirectory(_WebDavConfig config) =>
      '${config.directory}/snapshot_${DeviceUtils.platformName}';

  Future<void> backup(Set<BackupPart> parts) async {
    if (_busy) {
      SmartDialog.showToast('备份或恢复正在进行');
      return;
    }
    _busy = true;
    final temp = await Directory.systemTemp.createTemp('pilibro-webdav-');
    try {
      final config = _getConfig();
      final client = await _connect(config);
      final remote = _snapshotDirectory(config);
      await client.mkdirAll(remote);

      final files = await BackupService.collect(parts, temp);
      final manifest = await BackupService.manifest(files);
      final local = {
        for (final file in files.values.expand((list) => list))
          path.basename(file.path): file,
      };
      // A file the server already holds with the same hash is not sent again.
      final held = {};
      try {
        final previous = jsonDecode(
          utf8.decode(await client.read('$remote/manifest.json')),
        );
        if (previous['databaseVersion'] == GStorage.databaseVersion) {
          for (final List entries in (previous['parts'] as Map).values) {
            for (final Map entry in entries) {
              held[entry['file']] = entry['sha256'];
            }
          }
        }
      } catch (_) {}
      for (final List entries in (manifest['parts'] as Map).values) {
        for (final Map entry in entries) {
          final name = entry['file'] as String;
          if (held[name] != entry['sha256']) {
            await _uploadReplacing(client, local[name]!, '$remote/$name');
          }
        }
      }
      await _uploadReplacing(
        client,
        await File(
          path.join(temp.path, 'manifest.json'),
        ).writeAsString(jsonEncode(manifest)),
        '$remote/manifest.json',
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

  Future<void> restore(BuildContext context) async {
    if (_busy) {
      SmartDialog.showToast('备份或恢复正在进行');
      return;
    }
    _busy = true;
    final temp = await Directory.systemTemp.createTemp('pilibro-webdav-');
    try {
      final config = _getConfig();
      final client = await _connect(config);
      final remote = _snapshotDirectory(config);
      final manifest =
          jsonDecode(utf8.decode(await client.read('$remote/manifest.json')))
              as Map;
      if (!context.mounted) return;
      final parts = await selectRestoreParts(context, manifest);
      if (parts == null) return;
      await BackupService.restore(
        await BackupService.receive(
          manifest,
          parts,
          temp,
          (name, target) => client.read2File('$remote/$name', target.path),
        ),
      );
      SmartDialog.showToast('恢复成功');
    } catch (e) {
      SmartDialog.showToast('恢复失败: $e');
    } finally {
      _busy = false;
      try {
        await temp.delete(recursive: true);
      } catch (_) {}
    }
  }

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
}
