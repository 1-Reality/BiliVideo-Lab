import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:PiliBro/utils/android/android_helper.dart';
import 'package:PiliBro/utils/path_utils.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as path;

/// 哥哥科技 router scripts, fetched from ScriptCat and kept on disk. Nothing
/// here runs until a launch slot or the router page asks for it.
abstract final class BroTechScripts {
  static const list = <({String name, int id})>[
    (name: '中兴', id: 6194),
    (name: '小米', id: 6592),
    (name: '锐捷', id: 8445),
    (name: '华为', id: 6803),
    (name: '中兴光猫', id: 8455),
    (name: '华硕', id: 6675),
    (name: '腾达', id: 8073),
    (name: 'TP-LINK', id: 6674),
    (name: 'H3C', id: 8075),
  ];

  static File file(int index) => File(
    path.join(appSupportDirPath, 'BroTech', '${list[index].id}.user.js'),
  );

  static final _pending = <int, Future<Uint8List?>>{};

  /// Downloads one script and replaces the local copy when the bytes differ.
  /// Returns the bytes now on disk, or null when nothing usable arrived.
  static Future<Uint8List?> refresh(int index) =>
      _pending[index] ??= _refresh(index).whenComplete(() => _pending.remove(index));

  /// Why the last download of each script produced nothing, for the page.
  static final lastError = <int, String>{};

  static Future<Uint8List?> _refresh(int index) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    final Uint8List bytes;
    try {
      final response = await (await client.getUrl(
        Uri.parse(
          'https://scriptcat.org/scripts/code/${list[index].id}/x.user.js',
        ),
      )).close();
      if (response.statusCode != 200) {
        lastError[index] = 'HTTP ${response.statusCode}';
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await response
          .forEach(builder.add)
          .timeout(const Duration(seconds: 30));
      bytes = builder.takeBytes();
    } catch (e) {
      lastError[index] = e.toString();
      return null;
    } finally {
      client.close();
    }
    // A captive portal answers 200 with its login page; never let that
    // overwrite a working copy.
    if (!latin1
        .decode(bytes.sublist(0, bytes.length < 4096 ? bytes.length : 4096))
        .contains('==UserScript==')) {
      lastError[index] = '下载内容不是脚本（${bytes.length} B）';
      return null;
    }
    lastError.remove(index);
    final target = file(index);
    if (await target.exists() && await target.length() == bytes.length) {
      final local = await target.readAsBytes();
      var same = true;
      for (var i = 0; i < bytes.length; i++) {
        if (local[i] != bytes[i]) {
          same = false;
          break;
        }
      }
      if (same) return bytes;
    }
    await target.parent.create(recursive: true);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(target.path);
    return bytes;
  }

  /// Source for the router page: the local copy when there is one, so the
  /// page opens at once; ScriptCat only when nothing is cached yet. Newer
  /// versions arrive through the launch rotation.
  static Future<String?> load(int index) async {
    final target = file(index);
    if (await target.exists()) return target.readAsString();
    final bytes = await refresh(index);
    return bytes == null ? null : utf8.decode(bytes);
  }

  static final _virtual = RegExp('tun|wg|ppp|rmnet|vpn|wireguard', caseSensitive: false);

  /// Router address to prefill: the default gateway, else this device's
  /// private IPv4 with the last octet set to 1.
  static Future<String> defaultHost() async {
    if (Platform.isAndroid) {
      final gateway = PiliAndroidHelper.defaultGateway();
      if (gateway != null) return gateway;
    }
    for (final interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    )) {
      if (_virtual.hasMatch(interface.name)) continue;
      for (final address in interface.addresses) {
        final r = address.rawAddress;
        if (r[0] == 192 && r[1] == 168 ||
            r[0] == 10 ||
            r[0] == 172 && r[1] >= 16 && r[1] < 32) {
          return '${r[0]}.${r[1]}.${r[2]}.1';
        }
      }
    }
    return '192.168.1.1';
  }
}

/// Injection moments offered to the user. The script's own @run-at is not
/// consulted. `load` is not a userscript standard; it waits for window load.
enum BroTechRunAt {
  start('document-start', '文档开始'),
  body('document-body', 'body 出现时'),
  end('document-end', '文档结束（默认）'),
  idle('document-idle', '文档结束后空闲时'),
  load('load', '页面完全加载后（非标准）');

  const BroTechRunAt(this.key, this.label);
  final String key;
  final String label;
}

/// The parts of a userscript header the injector reads. @include/@match/
/// @exclude and @run-at are deliberately ignored: the user already chose this
/// script for this router page, so it is injected into every page of that
/// WebView at the moment picked in [BroTechRunAt].
class UserScriptMeta {
  UserScriptMeta._(this.values, this.noframes);

  final Map<String, List<String>> values;
  final bool noframes;

  static final _line = RegExp(r'^//\s*@([\w:.-]+)(?:\s+(.*?))?\s*$');

  factory UserScriptMeta.parse(String source) {
    final values = <String, List<String>>{};
    var noframes = false;
    final start = source.indexOf('==UserScript==');
    final end = source.indexOf('==/UserScript==');
    if (start >= 0 && end > start) {
      for (final raw in const LineSplitter().convert(
        source.substring(start, end),
      )) {
        final m = _line.firstMatch(raw.trim());
        if (m == null) continue;
        final key = m[1]!;
        if (key == 'noframes') {
          noframes = true;
        } else {
          (values[key] ??= []).add(m[2] ?? '');
        }
      }
    }
    return UserScriptMeta._(values, noframes);
  }

  String? first(String key) => values[key]?.first;
}

/// GM storage, one Hive box opened the first time a router page needs it.
abstract final class BroTechGmStore {
  static Future<Box<String>>? _box;

  static Future<Box<String>> get box => _box ??= Hive.openBox<String>('broTechGm');

  static Future<Map<String, String>> snapshot(int id) async {
    final b = await box;
    final prefix = '$id/';
    return {
      for (final key in b.keys)
        if (key is String && key.startsWith(prefix))
          key.substring(prefix.length): b.get(key)!,
    };
  }

  static Future<void> put(int id, String key, String? json) async {
    final b = await box;
    if (json == null) {
      await b.delete('$id/$key');
    } else {
      await b.put('$id/$key', json);
    }
  }
}

/// Builds the injected source: GM shim plus the script, inside one closure.
/// Values are baked in so GM_getValue stays synchronous; writes go to Dart.
UserScript buildBroTechUserScript({
  required int id,
  required String source,
  required UserScriptMeta meta,
  required Map<String, String> values,
  required BroTechRunAt runAt,
}) {
  final info = jsonEncode({
    'script': {
      for (final k in const [
        'name',
        'namespace',
        'version',
        'description',
        'author',
        'icon',
      ])
        if (meta.first(k) != null) k: meta.first(k),
    },
    'scriptHandler': 'PiliBro',
  });
  final schedule = switch (runAt) {
    BroTechRunAt.start || BroTechRunAt.end => '__run();',
    BroTechRunAt.body =>
      "document.body?__run():new MutationObserver((_,o)=>{if(document.body){o.disconnect();__run();}}).observe(document,{childList:true,subtree:true});",
    BroTechRunAt.idle => '(window.requestIdleCallback||setTimeout)(__run);',
    BroTechRunAt.load =>
      "document.readyState==='complete'?__run():window.addEventListener('load',__run,{once:true});",
  };
  final patched = source.replaceFirst(
    RegExp(r'injectMode:\s*\d+'),
    'injectMode: 3',
  );
  final js =
      '''
(()=>{const __v=${jsonEncode(values)},__q=[];
const __c=(...a)=>{const b=window.flutter_inappwebview;b&&b.callHandler?b.callHandler(...a):__q.push(a);};
window.addEventListener('flutterInAppWebViewPlatformReady',()=>{for(const a of __q.splice(0))window.flutter_inappwebview.callHandler(...a);});
const __p=(k,j)=>__c('broGM',$id,k,j);
window.addEventListener('error',e=>__c('broLog','错误 '+e.message+' @'+e.filename+':'+e.lineno));
const GM_info=$info,unsafeWindow=window;
const GM_getValue=(k,d)=>Object.prototype.hasOwnProperty.call(__v,k)?JSON.parse(__v[k]):d;
const GM_setValue=(k,v)=>{const j=JSON.stringify(v);if(j===undefined)return GM_deleteValue(k);__v[k]=j;__p(k,j);};
const GM_deleteValue=k=>{delete __v[k];__p(k,null);};
const GM_listValues=()=>Object.keys(__v);
const __run=()=>{__c('broLog','已注入（${runAt.key}）'+location.href);try{
$patched
}catch(e){__c('broLog','错误 '+(e&&e.stack||e));}};
$schedule
})();
''';
  return UserScript(
    groupName: 'broTech',
    source: js,
    injectionTime: runAt == BroTechRunAt.start || runAt == BroTechRunAt.body
        ? UserScriptInjectionTime.AT_DOCUMENT_START
        : UserScriptInjectionTime.AT_DOCUMENT_END,
    forMainFrameOnly: meta.noframes,
  );
}

/// One saved router entry. The same address may be saved any number of
/// times (several routers can sit at 192.168.1.1). user/pass are only ever
/// set on Android.
class BroTechPreset {
  BroTechPreset({
    required this.id,
    required this.host,
    required this.runAt,
    this.name,
    this.user,
    this.pass,
  });

  int id;
  String host;
  BroTechRunAt runAt;
  String? name;
  String? user;
  String? pass;

  int get index => BroTechScripts.list.indexWhere((e) => e.id == id);

  String get title => name?.isNotEmpty == true
      ? name!
      : BroTechScripts.list[index].name;

  Map<String, dynamic> toJson() => {
    'id': id,
    'host': host,
    'runAt': runAt.key,
    'name': ?name,
    'user': ?user,
    'pass': ?pass,
  };

  factory BroTechPreset.fromJson(Map json) => BroTechPreset(
    id: json['id'] as int,
    host: json['host'] as String,
    runAt: BroTechRunAt.values.firstWhere(
      (e) => e.key == json['runAt'],
      orElse: () => BroTechRunAt.end,
    ),
    name: json['name'] as String?,
    user: json['user'] as String?,
    pass: json['pass'] as String?,
  );
}

/// Saved entries, in a box of their own opened the first time the router
/// page is shown. Passwords stay in the app sandbox and never travel with
/// settings exports.
abstract final class BroTechPresets {
  static Future<Box<String>>? _box;

  static Future<Box<String>> get box => _box ??= Hive.openBox<String>('broTech');

  static Future<List<BroTechPreset>> load() async {
    final raw = (await box).get('presets');
    if (raw == null) return [];
    return [
      for (final e in jsonDecode(raw) as List)
        BroTechPreset.fromJson(e as Map),
    ].where((e) => e.index >= 0).toList();
  }

  static Future<void> save(List<BroTechPreset> presets) async => (await box)
      .put('presets', jsonEncode([for (final e in presets) e.toJson()]));
}

/// Android only: fills the first visible password box (and the text box
/// before it, when a user name is saved) as soon as one appears, exposes
/// window.__broFill(force) for the manual button, and reports passwords the
/// user types so they can be saved on the way out.
UserScript buildBroTechCredentialScript({String? user, String? pass}) =>
    UserScript(
      groupName: 'broCred',
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
      forMainFrameOnly: false,
      source:
          '''
(()=>{const P=${jsonEncode(pass ?? '')},U=${jsonEncode(user ?? '')};
const c=(...a)=>{const b=window.flutter_inappwebview;b&&b.callHandler&&b.callHandler(...a);};
const vis=e=>e.getClientRects().length>0;
const userOf=p=>{let u=null;for(const e of (p.form||document).querySelectorAll('input')){if(e===p)break;if(vis(e)&&/^(text|email|tel|)\$/.test(e.type))u=e;}return u;};
const set=(e,v)=>{Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(e,v);e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));};
const fill=f=>{if(!P)return false;const p=[...document.querySelectorAll('input[type=password]')].find(e=>vis(e)&&(f||!e.value));if(!p)return false;set(p,P);const u=U&&userOf(p);if(u&&(f||!u.value))set(u,U);return true;};
window.__broFill=fill;
document.addEventListener('change',e=>{const p=e.target;if(p instanceof HTMLInputElement&&p.type==='password'&&p.value&&p.value!==P){const u=userOf(p);c('broCred',p.value,u?u.value:'');}},true);
if(P&&!fill(false)){const o=new MutationObserver(()=>{if(fill(false))o.disconnect();});o.observe(document,{childList:true,subtree:true});setTimeout(()=>o.disconnect(),60000);}
})();
''',
    );
