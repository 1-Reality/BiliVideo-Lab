import 'dart:async';
import 'dart:collection';

import 'package:PiliBro/main.dart' show webViewEnvironment;
import 'package:PiliBro/services/brotech_scripts.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  void _open(int index) {
    final url = _host.text.trim();
    GStorage.localCache.put(_hostKey, url);
    Get.to(() => BroTechWebPage(index: index, url: url));
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
          for (final (index, script) in BroTechScripts.list.indexed)
            ListTile(
              title: Text(script.name),
              subtitle: Text('脚本猫 ${script.id}'),
              onTap: () => _open(index),
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
            return const Center(child: CircularProgressIndicator());
          }
          final script = snapshot.data;
          if (script == null) {
            return Center(
              child: Text('脚本下载失败，本地也没有缓存：${snapshot.error ?? ''}'),
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
                  ..addJavaScriptHandler(handlerName: 'broGM', callback: _onGm);
              },
            ),
          );
        },
      ),
    );
  }
}
