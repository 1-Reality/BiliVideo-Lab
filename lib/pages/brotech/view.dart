import 'dart:async';
import 'dart:collection';
import 'dart:io' show FileSystemEntityType;

import 'package:PiliBro/main.dart' show webViewEnvironment;
import 'package:PiliBro/services/brotech_scripts.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// Temporary entry for wiring the router tools end to end; the real UI
/// replaces this page, the service layer stays as is.
class BroTechPage extends StatefulWidget {
  const BroTechPage({super.key});

  @override
  State<BroTechPage> createState() => _BroTechPageState();
}

class _BroTechPageState extends State<BroTechPage> {
  static const _hostKey = 'broTechHost';
  late final _host = TextEditingController(
    text: GStorage.localCache.get(_hostKey, defaultValue: 'http://192.168.1.1'),
  );

  late Future<List<int?>> _cached = _stat();

  static Future<List<int?>> _stat() => Future.wait([
    for (var i = 0; i < BroTechScripts.list.length; i++)
      BroTechScripts.file(i)
          .stat()
          .then((s) => s.type == FileSystemEntityType.notFound ? null : s.size),
  ]);

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  void _open(int index) {
    final url = _host.text.trim();
    GStorage.localCache.put(_hostKey, url);
    Get.to(() => BroTechWebPage(index: index, url: url))
        ?.then((_) => setState(() => _cached = _stat()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('路由器增强（临时入口）')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: '路由器后台地址',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          FutureBuilder<List<int?>>(
            future: _cached,
            builder: (context, snapshot) => Column(
              children: [
                for (final (index, script) in BroTechScripts.list.indexed)
                  ListTile(
                    title: Text(script.name),
                    subtitle: Text(
                      '脚本猫 ${script.id} · ${switch (snapshot.data?[index]) {
                        null => '未缓存',
                        final int size => '已缓存 ${(size / 1024).toStringAsFixed(1)} KiB',
                      }}'
                      '${BroTechScripts.lastError[index] == null ? '' : '\n上次下载失败：${BroTechScripts.lastError[index]}'}',
                    ),
                    onTap: () => _open(index),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BroTechWebPage extends StatefulWidget {
  const BroTechWebPage({super.key, required this.index, required this.url});

  final int index;
  final String url;

  @override
  State<BroTechWebPage> createState() => _BroTechWebPageState();
}

class _BroTechWebPageState extends State<BroTechWebPage> {
  late final int _id = BroTechScripts.list[widget.index].id;
  late final Future<UserScript?> _ready = _prepare();
  late String _source;
  late UserScriptMeta _meta;
  late Map<String, String> _values;
  InAppWebViewController? _controller;
  Timer? _reregister;

  Future<UserScript?> _prepare() async {
    final source = await BroTechScripts.load(widget.index);
    if (source == null) return null;
    _source = source;
    _meta = UserScriptMeta.parse(source);
    _values = await BroTechGmStore.snapshot(_id);
    return _build();
  }

  UserScript _build() => buildBroTechUserScript(
    id: _id,
    source: _source,
    meta: _meta,
    values: _values,
  );

  // The injected source carries the values, so a reload must see the latest
  // ones; coalesce bursts of writes into one re-registration.
  void _onGm(List<dynamic> args) {
    final key = args[1] as String;
    final json = args[2] as String?;
    if (json == null) {
      _values.remove(key);
    } else {
      _values[key] = json;
    }
    BroTechGmStore.put(_id, key, json);
    _reregister ??= Timer(const Duration(seconds: 1), () async {
      _reregister = null;
      final controller = _controller;
      if (controller == null) return;
      await controller.removeUserScriptsByGroupName(groupName: 'broTech');
      await controller.addUserScript(userScript: _build());
    });
  }

  @override
  void dispose() {
    _reregister?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(BroTechScripts.list[widget.index].name),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => _controller?.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<UserScript?>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  CircularProgressIndicator(),
                  Text('正在从脚本猫获取脚本，3 秒后若本地有缓存则直接使用'),
                ],
              ),
            );
          }
          final script = snapshot.data;
          if (script == null) {
            return Center(
              child: Text(
                '脚本下载失败，本地也没有缓存：'
                '${snapshot.error ?? BroTechScripts.lastError[widget.index] ?? ''}',
              ),
            );
          }
          return SafeArea(
            child: InAppWebView(
              webViewEnvironment: webViewEnvironment,
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useHybridComposition: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
              initialUserScripts: UnmodifiableListView([script]),
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              onWebViewCreated: (controller) {
                _controller = controller
                  ..addJavaScriptHandler(handlerName: 'broGM', callback: _onGm)
                  ..addJavaScriptHandler(
                    handlerName: 'broLog',
                    callback: (args) => SmartDialog.showToast(
                      args.join(' '),
                      displayTime: const Duration(seconds: 4),
                    ),
                  );
              },
            ),
          );
        },
      ),
    );
  }
}
