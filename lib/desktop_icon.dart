import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:image/image.dart' as img;

const _launcherAssetPrefix = 'assets/images/logo/launcher_';
const _launcherExtensions = {'png', 'jpg', 'jpeg', 'webp'};

const _desktopIconNames = <String, String>{
  'launcher_realoriginalpic.jpg': '米山舞',
};

class DesktopIconPage extends StatefulWidget {
  const DesktopIconPage({super.key});

  @override
  State<DesktopIconPage> createState() => _DesktopIconPageState();
}

class _DesktopIconPageState extends State<DesktopIconPage> {
  List<String>? _icons;
  String? _current;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final discovered = manifest
          .listAssets()
          .where((asset) {
            final lower = asset.toLowerCase();
            if (!lower.startsWith(_launcherAssetPrefix)) return false;
            final extension = lower.split('.').last;
            return _launcherExtensions.contains(extension);
          })
          .map((asset) => asset.split('/').last)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      final files = <String>{...discovered, ..._desktopIconNames.keys}.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final current = await DesktopIcon.currentBuiltInIcon(discovered);

      if (!mounted) return;
      setState(() {
        _icons = files;
        _current = current;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _select(String? fileName) async {
    try {
      SmartDialog.showLoading(msg: '处理中');
      final ok = await DesktopIcon.setBuiltInIcon(fileName);
      SmartDialog.dismiss();
      if (!mounted) return;
      if (ok) {
        setState(() => _current = fileName);
        SmartDialog.showToast(
          fileName == null ? '已恢复默认桌面图标' : '桌面图标已切换',
        );
      } else {
        SmartDialog.showToast('这个图标没有编译进当前版本');
      }
    } catch (e) {
      SmartDialog.dismiss();
      if (mounted) {
        SmartDialog.showToast('桌面图标切换失败：$e');
      }
    }
  }

  Future<void> _addCustomShortcut() async {
    try {
      SmartDialog.showLoading(msg: '处理中');
      final status = await DesktopIcon.chooseAndSet();
      SmartDialog.dismiss();
      if (!mounted) return;
      if (status == 2) {
        SmartDialog.showToast('桌面快捷方式已更新');
      } else if (status == 1) {
        SmartDialog.showToast('已请求添加桌面快捷方式，请在系统提示中确认');
      } else {
        SmartDialog.showToast('当前桌面不支持添加快捷方式');
      }
    } catch (e) {
      SmartDialog.dismiss();
      if (mounted) {
        SmartDialog.showToast('图标处理失败：$e');
      }
    }
  }

  String? _assetPath(String fileName) {
    if (_icons == null || !_icons!.contains(fileName)) return null;
    return 'assets/images/logo/$fileName';
  }

  Widget _iconPreview(String? fileName) {
    final asset = fileName == null
        ? 'assets/images/logo/logo_2.png'
        : _assetPath(fileName);
    if (asset == null) {
      return const SizedBox(
        width: 56,
        height: 56,
        child: Icon(Icons.image_not_supported_outlined),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Image.asset(
        asset,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.image_not_supported_outlined),
        ),
      ),
    );
  }

  Widget _buildIconTile({
    required String? fileName,
    required String title,
    required String? subtitle,
    required ThemeData theme,
  }) {
    final missing = fileName != null &&
        _icons != null &&
        !_icons!.contains(fileName);
    return InkWell(
      onTap: missing ? null : () => _select(fileName),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: _iconPreview(fileName),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              if (_current == fileName)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icons = _icons;
    return Scaffold(
      appBar: AppBar(title: const Text('桌面图标')),
      body: SafeArea(
        child: _error != null
            ? Center(child: Text('图标列表读取失败：$_error'))
            : icons == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                        child: Text(
                          '内置图标',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      _buildIconTile(
                        fileName: null,
                        title: '默认',
                        subtitle: '使用应用当前默认图标',
                        theme: theme,
                      ),
                      ...icons.map(
                        (fileName) => _buildIconTile(
                          fileName: fileName,
                          title: _desktopIconNames[fileName] ?? fileName,
                          subtitle: _desktopIconNames.containsKey(fileName)
                              ? fileName
                              : '内置图标',
                          theme: theme,
                        ),
                      ),
                      const Divider(height: 1),
                      InkWell(
                        onTap: _addCustomShortcut,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 56,
                                height: 56,
                                child: Center(
                                  child: Icon(
                                    Icons.add_to_home_screen_outlined,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '添加任意图片到桌面',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '选择手机中的图片，作为桌面快捷方式',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

abstract final class DesktopIcon {
  static const _channel = MethodChannel('pilibro/desktop_icon');

  static Future<String?> currentBuiltInIcon(List<String> fileNames) async {
    return _channel.invokeMethod<String>(
      'getCurrentBuiltInIcon',
      {'fileNames': fileNames},
    );
  }

  static Future<bool> setBuiltInIcon(String? fileName) async {
    return await _channel.invokeMethod<bool>(
          'setBuiltInIcon',
          {'fileName': fileName},
        ) ??
        false;
  }

  static Future<int> chooseAndSet() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: [
        'png',
        'jpg',
        'jpeg',
        'ico',
        'webp',
        'bmp',
      ],
    );
    if (file == null) return 0;

    final bytes = await file.readAsBytes();
    final iconBytes = await compute(_prepareIcon, bytes);
    if (iconBytes == null) {
      throw const FormatException('无法识别这个图片文件');
    }

    return await _channel.invokeMethod<int>(
          'setCustomDesktopIcon',
          {'bytes': iconBytes},
        ) ??
        0;
  }

  static Uint8List? _prepareIcon(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    final rgba = image.convert(numChannels: 4, noAnimation: true);
    final icon = img.copyResize(
      rgba,
      width: 512,
      height: 512,
      maintainAspect: true,
      backgroundColor: img.ColorRgba8(0, 0, 0, 0),
      interpolation: img.Interpolation.linear,
    );
    return img.encodePng(icon);
  }
}
