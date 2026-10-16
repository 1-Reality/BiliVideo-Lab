import 'dart:io' show Platform;

import 'package:PiliBro/build_config.dart';
import 'package:PiliBro/common/constants.dart';
import 'package:PiliBro/http/api.dart';
import 'package:PiliBro/http/browser_ua.dart';
import 'package:PiliBro/http/init.dart';
import 'package:PiliBro/services/brotech_scripts.dart';
import 'package:PiliBro/utils/accounts/account.dart';
import 'package:PiliBro/utils/page_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

abstract final class Update {
  static void onLaunch() {
    final cache = GStorage.localCache;
    final n = BroTechScripts.list.length + 1;
    var slot = cache.get(LocalCacheKey.launchSlot, defaultValue: 1) as int;
    final now = DateTime.now().subtract(const Duration(hours: 4));
    final today = now.year * 10000 + now.month * 100 + now.day;
    final stamp = cache.get(LocalCacheKey.launchDay, defaultValue: 0) as int;
    if (today > stamp ~/ 1000) {
      slot %= n;
      cache.put(
        LocalCacheKey.launchDay,
        today * 1000 + (now.year == stamp ~/ 10000000 ? stamp % 1000 + 1 : 1),
      );
    }
    cache.put(LocalCacheKey.launchSlot, slot + 1);
    final bucket = slot % n;
    final ignore = cache.get(LocalCacheKey.updateIgnore);
    if (Pref.autoUpdate &&
        (bucket == 0 || (ignore is Map && ignore['temporary'] == false))) {
      checkUpdate();
    }
    if (bucket != 0 && (slot ~/ n) & 4 == 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => BroTechScripts.refresh(bucket - 1),
      );
    }
  }

  // 检查更新
  static Future<void> checkUpdate([bool isAuto = true]) async {
    if (kDebugMode) return;
    SmartDialog.dismiss();
    try {
      final res = await Request().get(
        Api.latestApp,
        options: Options(
          headers: {'user-agent': BrowserUa.mob},
          extra: {'account': const NoAccount()},
        ),
      );
      if (res.data is Map || res.data.isEmpty) {
        if (!isAuto) {
          SmartDialog.showToast('检查更新失败，GitHub接口未返回数据，请检查网络');
        }
        return;
      }
      final data = res.data[0];
      final int latest =
          DateTime.parse(data['created_at']).millisecondsSinceEpoch ~/ 1000;
      final version = data['tag_name']?.toString() ?? data['created_at'].toString();
      final updateIgnore = GStorage.localCache.get(LocalCacheKey.updateIgnore);
      if (isAuto && updateIgnore is Map) {
        final ignoredVersion = updateIgnore['version']?.toString();
        if (updateIgnore['temporary'] == true || ignoredVersion == version) {
          return;
        }
        GStorage.localCache.delete(LocalCacheKey.updateIgnore);
      }
      if (BuildConfig.buildTime >= latest) {
        if (!isAuto) {
          SmartDialog.showToast('已是最新版本');
        }
      } else {
        SmartDialog.show(
          useSystem: true,
          animationType: SmartAnimationType.centerFade_otherSlide,
          builder: (context) {
            final colorScheme = ColorScheme.of(context);
            Widget downloadBtn(String text, {String? ext}) => TextButton(
              autofocus: ext == null,
              onPressed: () => onDownload(data, ext: ext),
              child: Text(text),
            );
            return AlertDialog(
              title: const Text('🎉 发现新版本 '),
              content: SizedBox(
                height: 280,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['tag_name']}',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text('${data['body']}'),
                      TextButton(
                        onPressed: () => PageUtils.launchURL(
                          '${Constants.sourceCodeUrl}/commits/${Constants.sourceBranch}',
                        ),
                        child: Text(
                          "点此查看完整更新(即commit)内容",
                          style: TextStyle(color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (isAuto) ...[
                  TextButton(
                    onPressed: () async {
                      await GStorage.localCache.put(
                        LocalCacheKey.updateIgnore,
                        {
                          'version': version,
                          'temporary': false,
                        },
                      );
                      SmartDialog.dismiss();
                    },
                    child: Text(
                      '忽略本版',
                      style: TextStyle(color: colorScheme.outline),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await GStorage.localCache.put(
                        LocalCacheKey.updateIgnore,
                        {
                          'version': version,
                          'temporary': true,
                        },
                      );
                      SmartDialog.dismiss();
                    },
                    child: Text(
                      '忽略几天',
                      style: TextStyle(color: colorScheme.outline),
                    ),
                  ),
                ],
                if (Platform.isWindows) ...[
                  downloadBtn('zip', ext: 'zip'),
                  downloadBtn('exe', ext: 'exe'),
                ] else if (Platform.isLinux) ...[
                  downloadBtn('rpm', ext: 'rpm'),
                  downloadBtn('deb', ext: 'deb'),
                  downloadBtn('targz', ext: 'tar.gz'),
                ] else
                  downloadBtn('更新'),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('failed to check update: $e');
    }
  }

  // 下载适用于当前系统的安装包
  static Future<void> onDownload(Map data, {String? ext}) async {
    SmartDialog.dismiss();
    try {
      void download(String plat) {
        if (data['assets'].isNotEmpty) {
          for (Map<String, dynamic> i in data['assets']) {
            final String name = i['name'];
            if (name.contains(plat) &&
                (ext == null || ext.isEmpty || name.endsWith(ext))) {
              PageUtils.launchURL(i['browser_download_url']);
              return;
            }
          }
          throw UnsupportedError('platform not found: $plat');
        }
      }

      if (Platform.isAndroid) {
        // 获取设备信息
        AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
        // [arm64-v8a]
        download(androidInfo.supportedAbis.first);
      } else {
        download(Platform.operatingSystem);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('download error: $e');
      PageUtils.launchURL('${Constants.sourceCodeUrl}/releases/latest');
    }
  }
}
