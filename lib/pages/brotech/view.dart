import 'dart:async';
import 'dart:collection';
import 'dart:io' show FileStat, FileSystemEntityType, Platform;

import 'package:PiliBro/main.dart' show webViewEnvironment;
import 'package:PiliBro/services/brotech_scripts.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 路由器高级统计与增强: saved entries on top, the fixed brand list below.
class BroTechPage extends StatefulWidget {
  const BroTechPage({super.key});

  @override
  State<BroTechPage> createState() => _BroTechPageState();
}

class _BroTechPageState extends State<BroTechPage> {
  static const _runAtKey = 'broTechRunAt';
  final _host = TextEditingController();
  late BroTechRunAt _runAt = BroTechRunAt.values.firstWhere(
    (e) => e.key == GStorage.localCache.get(_runAtKey),
    orElse: () => BroTechRunAt.end,
  );
  List<BroTechPreset> _presets = const [];
  late Future<List<FileStat?>> _cached = _stat();

  static Future<List<FileStat?>> _stat() => Future.wait([
    for (var i = 0; i < BroTechScripts.list.length; i++)
      BroTechScripts.file(i)
          .stat()
          .then((s) => s.type == FileSystemEntityType.notFound ? null : s),
  ]);

  static String _pad(int v, [int w = 2]) => v.toString().padLeft(w, '0');

  static String _micro(int us) =>
      '${us ~/ 1000000}.${_pad(us % 1000000, 6)}';

  /// Within 10 days: how long ago. Older: the local time. Both at the full
  /// microsecond precision DateTime carries.
  static String _when(DateTime t) {
    final ago = DateTime.now().difference(t);
    if (ago.inDays >= 10) {
      return '${t.year}-${_pad(t.month)}-${_pad(t.day)} '
          '${_pad(t.hour)}:${_pad(t.minute)}:${_pad(t.second)}'
          '.${_pad(t.millisecond * 1000 + t.microsecond, 6)}';
    }
    final d = ago.inDays;
    final h = ago.inHours % 24;
    final m = ago.inMinutes % 60;
    return '${d > 0 ? '$d 天 ' : ''}${d + h > 0 ? '$h 小时 ' : ''}'
        '${d + h + m > 0 ? '$m 分 ' : ''}'
        '${_micro(ago.inMicroseconds % 60000000)} 秒前';
  }

  static final _group = RegExp(r'\B(?=(\d{3})+$)');

  static String _status(int index, FileStat? stat) {
    if (stat == null) return '未缓存';
    final parts = ['${stat.size.toString().replaceAll(_group, '\u202f')} B'];
    final checked = BroTechScripts.checkedAt(index);
    if (checked != null) {
      parts.add('上次检查 ${_when(checked)}');
      final spent = stat.modified.difference(checked);
      if (!spent.isNegative) {
        parts.add('更新用时 ${_micro(spent.inMicroseconds)} s');
      }
    }
    return parts.join(' · ');
  }

  @override
  void initState() {
    super.initState();
    BroTechScripts.defaultHost().then((host) {
      if (mounted && _host.text.isEmpty) _host.text = 'http://$host';
    });
    BroTechPresets.load().then((value) {
      if (mounted) setState(() => _presets = value);
    });
  }

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _savePresets() => BroTechPresets.save(_presets);

  Future<void> _launch(BroTechPreset preset, {required bool isNew}) async {
    String? user;
    String? pass;
    await Get.to(
      () => BroTechWebPage(
        preset: preset,
        onCredential: (u, p) {
          user = u;
          pass = p;
        },
      ),
    );
    if (!mounted) return;
    setState(() => _cached = _stat());
    if (isNew) {
      preset
        ..user = user
        ..pass = pass;
      if (await _edit(preset, title: '保存为快捷入口？') == true) {
        setState(() => _presets = [..._presets, preset]);
        await _savePresets();
      }
    } else if (pass != null && pass != preset.pass) {
      final update = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('更新已保存的密码？'),
          content: Text('「${preset.title}」这次登录用了新密码'),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('不用')),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('更新'),
            ),
          ],
        ),
      );
      if (update == true) {
        preset
          ..user = user
          ..pass = pass;
        await _savePresets();
      }
    }
  }

  /// Edits [preset] in place. Returns true to keep it, false to delete it,
  /// null when cancelled.
  Future<bool?> _edit(
    BroTechPreset preset, {
    required String title,
    bool deletable = false,
  }) {
    final name = TextEditingController(text: preset.name);
    final host = TextEditingController(text: preset.host);
    final user = TextEditingController(text: preset.user);
    final pass = TextEditingController(text: preset.pass);
    var id = preset.id;
    var runAt = preset.runAt;
    var obscure = true;
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: '名称（可不填）',
                    hintText: BroTechScripts.list[preset.index].name,
                  ),
                ),
                DropdownButtonFormField<int>(
                  initialValue: id,
                  decoration: const InputDecoration(labelText: '品牌'),
                  items: [
                    for (final e in BroTechScripts.list)
                      DropdownMenuItem(value: e.id, child: Text(e.name)),
                  ],
                  onChanged: (value) => id = value!,
                ),
                TextField(
                  controller: host,
                  decoration: const InputDecoration(labelText: '地址'),
                ),
                DropdownButtonFormField<BroTechRunAt>(
                  initialValue: runAt,
                  decoration: const InputDecoration(labelText: '注入时机'),
                  items: [
                    for (final e in BroTechRunAt.values)
                      DropdownMenuItem(value: e, child: Text(e.label)),
                  ],
                  onChanged: (value) => runAt = value!,
                ),
                if (Platform.isAndroid) ...[
                  TextField(
                    controller: user,
                    decoration: const InputDecoration(
                      labelText: '账号（后台只有密码框时留空）',
                    ),
                  ),
                  TextField(
                    controller: pass,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: '密码（仅保存在本机）',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (deletable)
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text(
                  '删除',
                  style: TextStyle(color: ColorScheme.of(context).error),
                ),
              ),
            TextButton(onPressed: Get.back, child: const Text('取消')),
            TextButton(
              onPressed: () {
                String? text(TextEditingController c) =>
                    c.text.isEmpty ? null : c.text;
                preset
                  ..id = id
                  ..host = host.text.trim()
                  ..runAt = runAt
                  ..name = text(name)
                  ..user = text(user)
                  ..pass = text(pass);
                Get.back(result: true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editExisting(BroTechPreset preset) async {
    final keep = await _edit(preset, title: '编辑快捷入口', deletable: true);
    if (keep == null) return;
    setState(() {
      if (!keep) _presets = [..._presets]..remove(preset);
    });
    await _savePresets();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: TextStyle(color: colorScheme.primary, fontSize: 13),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('路由器高级统计与增强（哥哥科技原创）')),
      body: ListView(
        children: [
          if (_presets.isNotEmpty) ...[
            header('快捷入口（长按编辑）'),
            for (final preset in _presets)
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(preset.title),
                subtitle: Text(
                  preset.runAt == BroTechRunAt.end
                      ? preset.host
                      : '${preset.host} · ${preset.runAt.key}',
                ),
                trailing: preset.pass == null
                    ? null
                    : const Icon(Icons.key_outlined, size: 18),
                onTap: () => _launch(preset, isNew: false),
                onLongPress: () => _editExisting(preset),
              ),
          ],
          header('新建：填好地址和注入时机后点品牌'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: '路由器后台地址',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<BroTechRunAt>(
              initialValue: _runAt,
              decoration: const InputDecoration(
                labelText: '注入时机（忽略脚本自带的 @run-at）',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final e in BroTechRunAt.values)
                  DropdownMenuItem(value: e, child: Text('${e.label} · ${e.key}')),
              ],
              onChanged: (value) {
                _runAt = value!;
                GStorage.localCache.put(_runAtKey, value.key);
              },
            ),
          ),
          FutureBuilder<List<FileStat?>>(
            future: _cached,
            builder: (context, snapshot) => Column(
              children: [
                for (final (index, script) in BroTechScripts.list.indexed)
                  ListTile(
                    title: Text(script.name),
                    subtitle: Text(
                      '脚本猫 ${script.id} · ${_status(index, snapshot.data?[index])}'
                      '${BroTechScripts.lastError[index] == null ? '' : '\n上次下载失败：${BroTechScripts.lastError[index]}'}',
                    ),
                    onTap: () => _launch(
                      BroTechPreset(
                        id: script.id,
                        host: _host.text.trim(),
                        runAt: _runAt,
                      ),
                      isNew: true,
                    ),
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
  const BroTechWebPage({
    super.key,
    required this.preset,
    required this.onCredential,
  });

  final BroTechPreset preset;

  /// The last user name and password typed into the page (Android only).
  final void Function(String user, String pass) onCredential;

  @override
  State<BroTechWebPage> createState() => _BroTechWebPageState();
}

class _BroTechWebPageState extends State<BroTechWebPage> {
  late final int _index = widget.preset.index;
  late final int _id = widget.preset.id;
  late final Future<UserScript?> _ready = _prepare();
  late String _source;
  late UserScriptMeta _meta;
  late Map<String, String> _values;
  InAppWebViewController? _controller;
  Timer? _reregister;

  Future<UserScript?> _prepare() async {
    final source = await BroTechScripts.load(_index);
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
    runAt: widget.preset.runAt,
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

  Future<void> _fill() async {
    final ok = await _controller?.evaluateJavascript(
      source:
          '(()=>{let ok=false;for(const f of [window,...Array.from(window.frames)])'
          'try{ok=f.__broFill(true)||ok}catch(e){}return ok})()',
    );
    if (ok != true) SmartDialog.showToast('没有找到可见的密码框');
  }

  @override
  void dispose() {
    _reregister?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final credentials = Platform.isAndroid;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.preset.title),
        actions: [
          if (credentials && widget.preset.pass != null)
            IconButton(
              tooltip: '填充密码',
              onPressed: _fill,
              icon: const Icon(Icons.key_outlined),
            ),
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
                  Text('本地还没有缓存，正在从脚本猫下载'),
                ],
              ),
            );
          }
          final script = snapshot.data;
          if (script == null) {
            return Center(
              child: Text(
                '脚本下载失败，本地也没有缓存：'
                '${snapshot.error ?? BroTechScripts.lastError[_index] ?? ''}',
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
              initialUserScripts: UnmodifiableListView([
                script,
                if (credentials)
                  buildBroTechCredentialScript(
                    user: widget.preset.user,
                    pass: widget.preset.pass,
                  ),
              ]),
              initialUrlRequest: URLRequest(
                url: WebUri(
                  widget.preset.host.contains('://')
                      ? widget.preset.host
                      : 'http://${widget.preset.host}',
                ),
              ),
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
                if (credentials) {
                  controller.addJavaScriptHandler(
                    handlerName: 'broCred',
                    callback: (args) => widget.onCredential(
                      args[1] as String,
                      args[0] as String,
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
