import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  /// Source for the router page: a fresh copy if ScriptCat answers within
  /// 3 s, otherwise the local copy, otherwise whatever the download yields.
  static Future<String?> load(int index) async {
    final download = refresh(index);
    final target = file(index);
    try {
      final bytes = await download.timeout(const Duration(seconds: 3));
      if (bytes != null) return utf8.decode(bytes);
    } on TimeoutException {
      // The download keeps going and still lands on disk for next time.
    }
    if (await target.exists()) return target.readAsString();
    final bytes = await download;
    return bytes == null ? null : utf8.decode(bytes);
  }
}

/// The parts of a userscript header the injector reads. @include/@match/
/// @exclude and @run-at are deliberately ignored: the user already chose this
/// script for this router page, so it is injected into every page of that
/// WebView at document end.
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
  final js =
      '''
(()=>{const __v=${jsonEncode(values)},__q=[];
const __c=(...a)=>{const b=window.flutter_inappwebview;b&&b.callHandler?b.callHandler(...a):__q.push(a);};
window.addEventListener('flutterInAppWebViewPlatformReady',()=>{for(const a of __q.splice(0))window.flutter_inappwebview.callHandler(...a);});
const __p=(k,j)=>__c('broGM',$id,k,j);
__c('broLog','已注入 '+location.href);
window.addEventListener('error',e=>__c('broLog','错误 '+e.message+' @'+e.filename+':'+e.lineno));
const GM_info=$info,unsafeWindow=window;
const GM_getValue=(k,d)=>Object.prototype.hasOwnProperty.call(__v,k)?JSON.parse(__v[k]):d;
const GM_setValue=(k,v)=>{const j=JSON.stringify(v);if(j===undefined)return GM_deleteValue(k);__v[k]=j;__p(k,j);};
const GM_deleteValue=k=>{delete __v[k];__p(k,null);};
const GM_listValues=()=>Object.keys(__v);
try{
$source
}catch(e){__c('broLog','错误 '+(e&&e.stack||e));}
})();
''';
  return UserScript(
    groupName: 'broTech',
    source: js,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
    forMainFrameOnly: meta.noframes,
  );
}
