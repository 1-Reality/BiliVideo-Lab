import 'dart:convert';
import 'dart:io';

import 'package:PiliBro/common/constants.dart';
import 'package:PiliBro/common/widgets/dialog/backup_dialog.dart';
import 'package:PiliBro/common/widgets/pair.dart';
import 'package:PiliBro/services/backup_seal.dart';
import 'package:PiliBro/services/backup_service.dart';
import 'package:PiliBro/utils/device_utils.dart';
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

  Future<void> backup(Set<BackupPart> parts, {BackupSeal? seal}) async {
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

      final files = await BackupService.collect(parts, temp, seal: seal);
      final manifest = await BackupService.manifest(files);
      final local = {
        for (final file in files.values.expand((list) => list))
          path.basename(file.path): file,
      };
      // 文件名带内容哈希：服务器上已有同名文件就是同一份内容，跳过；
      // 变了就是新名字，只新增不覆盖，旧备份原样留着
      final held = {
        for (final file in await client.readDir(remote)) file.name,
      };
      for (final List entries in (manifest['parts'] as Map).values) {
        for (final Map entry in entries) {
          final name = _remoteName(entry);
          if (!held.contains(name)) {
            await client.writeFromFile(
              local[entry['file']]!.path,
              '$remote/$name',
            );
          }
        }
      }
      // 清单最后上传，也是新文件名；中途失败时之前的各次备份都完整
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final stamp =
          '${now.year}${two(now.month)}${two(now.day)}-'
          '${two(now.hour)}${two(now.minute)}${two(now.second)}';
      await client.writeFromFile(
        (await File(
          path.join(temp.path, 'manifest.json'),
        ).writeAsString(jsonEncode(manifest))).path,
        '$remote/manifest_$stamp.json',
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
      // 取时间戳最新的一份清单；没有的话是改版前的备份，读旧的 manifest.json
      final manifests = [
        for (final file in await client.readDir(remote))
          if (file.name case final name?
              when name.startsWith('manifest_') && name.endsWith('.json'))
            name,
      ]..sort();
      final legacy = manifests.isEmpty;
      final manifest =
          jsonDecode(
                utf8.decode(
                  await client.read(
                    '$remote/${legacy ? 'manifest.json' : manifests.last}',
                  ),
                ),
              )
              as Map;
      final remoteNames = {
        for (final List entries in (manifest['parts'] as Map).values)
          for (final Map entry in entries)
            entry['file']: legacy ? entry['file'] : _remoteName(entry),
      };
      if (!context.mounted) return;
      final parts = await selectRestoreParts(context, manifest);
      if (parts == null) return;
      toastRestored(
        await BackupService.restore(
          await BackupService.receive(
            manifest,
            parts,
            temp,
            (name, target) =>
                client.read2File('$remote/${remoteNames[name]}', target.path),
          ),
          password: (retry) =>
              askBackupPassword(context, export: false, retry: retry),
        ),
      );
    } catch (e) {
      SmartDialog.showToast('恢复失败: $e');
    } finally {
      _busy = false;
      try {
        await temp.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// 服务器上的文件名：在扩展名前插入内容哈希的前 16 位
  static String _remoteName(Map entry) {
    final String name = entry['file'];
    final String sha = entry['sha256'];
    return '${path.basenameWithoutExtension(name)}.${sha.substring(0, 16)}'
        '${path.extension(name)}';
  }
}
