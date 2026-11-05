import 'dart:async';
import 'dart:collection';
import 'dart:io' show FileStat, FileSystemEntityType, Platform;

import 'package:PiliBro/main.dart' show webViewEnvironment;
import 'package:PiliBro/pages/brotech/files.dart';
import 'package:PiliBro/services/brotech_scripts.dart';
import 'package:PiliBro/utils/device_utils.dart';
import 'package:PiliBro/utils/page_utils.dart';
import 'package:PiliBro/utils/permission_handler.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:flutter/services.dart';
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
  static const _localNetworkChannel = MethodChannel('pilibro/local_network');
  static const _runAtKey = 'broTechRunAt';
  static const _consentKey = 'broTechConsent';
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

  static String _micro(int us) {
    final s = us ~/ 1000000;
    return '$s.${_pad(us - s * 1000000, 6)}';
  }

  /// Within 10 days: how long ago. Older: the local time. Both at the full
  /// microsecond precision DateTime carries.
  static String _when(DateTime t) {
    var us = DateTime.now().difference(t).inMicroseconds;
    final d = us ~/ 86400000000;
    if (d > 9) {
      return '${t.year}-${_pad(t.month)}-${_pad(t.day)} '
          '${_pad(t.hour)}:${_pad(t.minute)}:${_pad(t.second)}'
          '.${_pad(t.millisecond * 1000 + t.microsecond, 6)}';
    }
    us -= d * 86400000000;
    final h = us ~/ 3600000000;
    us -= h * 3600000000;
    final m = us ~/ 60000000;
    return '${d > 0 ? '$d 天 ' : ''}${d + h > 0 ? '$h 小时 ' : ''}'
        '${d + h + m > 0 ? '$m 分 ' : ''}'
        '${_micro(us - m * 60000000)} 秒前';
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
    if (GStorage.localCache.get(_consentKey) != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final agreed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _BroTechConsent(),
        );
        if (agreed != true) Get.back();
      });
    }
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
    if (Platform.isAndroid &&
        await _localNetworkChannel.invokeMethod<bool>('ensureAccess') != true) {
      SmartDialog.showToast('未允许本地网络访问，无法打开路由器页面');
      return;
    }
    String? user;
    String? pass;
    var saved = !isNew;
    await Get.to(
      () => BroTechWebPage(
        preset: preset,
        onCredential: (u, p) {
          user = u;
          pass = p;
        },
        onSave: isNew
            ? () async {
                if (!saved) {
                  preset
                    ..user = user
                    ..pass = pass;
                }
                final keep = await _edit(
                  preset,
                  title: saved ? '编辑快捷入口' : '保存为快捷入口',
                );
                if (keep != true || !mounted) return;
                if (!saved) {
                  saved = true;
                  setState(() => _presets = [..._presets, preset]);
                }
                await _savePresets();
              }
            : null,
      ),
    );
    if (!mounted) return;
    setState(() => _cached = _stat());
    if (saved && pass != null && pass != preset.pass) {
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
      appBar: AppBar(
        title: Text.rich(
          TextSpan(
            text: '路由器高阶统计增强组件：哥哥科技原创',
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.top,
                child: IconButton(
                  tooltip: '使用须知：许可与说明',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const _BroTechConsent(persistConsent: false),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 24,
                    height: 24,
                  ),
                  iconSize: 15,
                  color: colorScheme.primary.withValues(alpha: 0.8),
                  icon: const Icon(Icons.gavel_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
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
          header('新建：填好地址和注入时机后点品牌<拒绝软漏油和万物皆“刷”机从我做起>'),
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

/// Shown once, before the router page is first used. The countdown lives in
/// this State alone: the licence page pushed on top leaves it running, and
/// closing the dialog drops it.
class _BroTechConsent extends StatefulWidget {
  const _BroTechConsent({this.persistConsent = true});

  /// False when the panel is reopened for viewing after the initial consent.
  final bool persistConsent;

  @override
  State<_BroTechConsent> createState() => _BroTechConsentState();
}

class _BroTechConsentState extends State<_BroTechConsent> {
  late final Timer _timer;
  int _left = 24;
  bool? _lan;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1250), (t) {
      if (WidgetsBinding.instance.lifecycleState != .resumed) return;
      if (--_left == 0) t.cancel();
      setState(() {});
    });
    if (Platform.isAndroid && DeviceUtils.sdkInt > 36) {
      Permission.accessLocalNetwork.isGranted.then((v) {
        if (mounted) setState(() => _lan = v);
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _requestLan() async {
    final status = await Permission.accessLocalNetwork.request();
    if (mounted) setState(() => _lan = status.isGranted);
  }

  Future<void> _agree() async {
    if (widget.persistConsent) {
      await GStorage.localCache.put(_BroTechPageState._consentKey, true);
    }
    Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final lan = _lan;
    final lanColor = lan == false ? colorScheme.error : Colors.green.shade600;
    Widget term(String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CircleAvatar(
            radius: 2,
            backgroundColor: colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium!.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
    Widget dev(IconData icon, Color color, String label, VoidCallback onTap) =>
        Expanded(
          child: Material(
            color: color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 4,
                  children: [
                    Icon(icon, color: color, size: 26),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.all(24),
      contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 12, 20, 16),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (24 - _left) * 0.04,
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                if (_left == 0)
                  Icon(Icons.check_rounded, size: 38, color: colorScheme.primary)
                else
                  Text(
                    '$_left',
                    style: textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '哥哥科技 Bro-Stat 增强组件',
            style: textTheme.headlineSmall!.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
              '若读完仍有时间\n'
              '可在下左方查看B站主页\n'
              '播放视频期间不影响时钟，看爽了可以正常返回。\n'
              '也可点右下角“支持”去我兄弟的闲鱼逛，有好的音像闲置',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.primary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  term('该程序从云端加载脚本，并缓存到您的设备里，以方便随时之需；不到 1MiB，实现非常绿色和优雅.'),
                  term('严格遵循哥哥科技显著署名许可证.'),
                  term('脚本中的任何“哥哥科技”名字，均不得被篡改、弱化，或以非预期名称方式呈现。'),
                ],
              ),
            ),
          ),
          if (lan != null) ...[
            const SizedBox(height: 12),
            Material(
              color: lanColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: lan ? null : _requestLan,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    spacing: 10,
                    children: [
                      Icon(
                        lan ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: lanColor,
                        size: 20,
                      ),
                      Expanded(
                        child: Text(
                          lan ? '本地网络权限已有' : '本地网络权限缺失，点击申请',
                          style: TextStyle(
                            color: lanColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (!lan)
                        Icon(Icons.chevron_right, color: lanColor, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            spacing: 10,
            children: [
              dev(
                Icons.person_add_alt_1_rounded,
                colorScheme.primary,
                '了解开发者\n'
                '查看B站主页',
                () => Get.toNamed('/member?mid=388010726'),
              ),
              dev(
                Icons.favorite_rounded,
                Colors.pink,
                '支持朋友/点击了解\n'
                '查看期间不影响计时',
                () => PageUtils.launchURL(
                  'https://www.goofish.com/personal?userId=2216485229713',
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Get.to(() => const BroTechFilesPage()),
          icon: const Icon(Icons.balance, size: 18),
          label: const Text('许可证'),
        ),
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text('拒绝'),
        ),
        FilledButton(
          onPressed: _left == 0 ? _agree : null,
          child: const Text('同意'),
        ),
      ],
    );
  }
}

class BroTechWebPage extends StatefulWidget {
  const BroTechWebPage({
    super.key,
    required this.preset,
    required this.onCredential,
    this.onSave,
  });

  final BroTechPreset preset;

  /// Only for an entry opened from the brand list: saves it as a shortcut.
  final Future<void> Function()? onSave;

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
          if (widget.onSave case final onSave?)
            IconButton(
              tooltip: '保存为快捷入口',
              onPressed: onSave,
              icon: const Icon(Icons.bookmark_add_outlined),
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