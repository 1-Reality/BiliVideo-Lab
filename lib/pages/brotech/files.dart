import 'dart:convert' show jsonEncode;
import 'dart:io' show Platform;

import 'package:PiliBro/main.dart' show webViewEnvironment;
import 'package:PiliBro/utils/page_utils.dart';
import 'package:PiliBro/utils/share_utils.dart';
import 'package:PiliBro/utils/storage_utils.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_svg/flutter_html_svg.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as md;
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

const _root = 'assets/BroTech/';

final Future<List<String>> _assets = AssetManifest.loadFromAssetBundle(
  rootBundle,
).then((m) => [for (final a in m.listAssets()) if (a.startsWith(_root)) a]);

/// Each top folder mirrors one ucxn repository; the root stands for the
/// Home Assistant integration.
String _repo(String asset) => switch (asset.substring(_root.length)) {
  final p when p.startsWith('general/') => 'Bro-Stat',
  final p when p.startsWith('ZTE/') => 'ZTE-Stat_Max',
  final p when p.startsWith('Mi/') => 'Mi-Stat_Max',
  _ => 'ZTE-Stat_HA',
};

/// The licences and notes shipped in assets/BroTech, browsed as folders.
class BroTechFilesPage extends StatelessWidget {
  const BroTechFilesPage({super.key, this.dir = _root});

  /// Ends with '/'.
  final String dir;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final repo = _repo(dir);
    return Scaffold(
      appBar: AppBar(
        title: Text(dir.substring('assets/'.length, dir.length - 1)),
      ),
      body: FutureBuilder(
        future: _assets,
        builder: (context, snapshot) {
          final folders = <String>{};
          final files = <String>[];
          for (final a in snapshot.data ?? const <String>[]) {
            if (!a.startsWith(dir)) continue;
            final rest = a.substring(dir.length);
            final slash = rest.indexOf('/');
            if (slash < 0) {
              files.add(rest);
            } else {
              folders.add(rest.substring(0, slash));
            }
          }
          int byName(String a, String b) =>
              a.toLowerCase().compareTo(b.toLowerCase());
          return ListView(
            children: [
              for (final name in folders.toList()..sort(byName))
                ListTile(
                  leading: const Icon(Icons.folder_rounded),
                  title: Text(name),
                  onTap: () => Get.to(
                    () => BroTechFilesPage(dir: '$dir$name/'),
                    preventDuplicates: false,
                  ),
                ),
              for (final name in files..sort(byName))
                ListTile(
                  leading: Icon(
                    name.toLowerCase().endsWith('.svg')
                        ? Icons.image_outlined
                        : Icons.description_outlined,
                  ),
                  title: Text(name),
                  onTap: () => Get.to(() => BroTechDocPage(asset: '$dir$name')),
                ),
              Card.filled(
                margin: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                color: colorScheme.secondaryContainer,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(FontAwesomeIcons.github),
                  title: const Text('上 GitHub 获取源文件'),
                  subtitle: Text('顺手给我点个 Star 哟～　ucxn/$repo'),
                  trailing: const Icon(Icons.star_rounded, color: Colors.amber),
                  onTap: () =>
                      PageUtils.inAppWebview('https://github.com/ucxn/$repo'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// GitHub alert colours, shared by both renderers.
const _alerts = {
  'note': 0xFF4493F8,
  'tip': 0xFF3FB950,
  'important': 0xFFAB7DF8,
  'warning': 0xFFD29922,
  'caution': 0xFFF85149,
};

/// marked has no GitHub alerts: turn a blockquote opening with [!TYPE] into
/// the same markup the markdown package emits.
const _alertScript = r'''<script>for(const q of document.querySelectorAll('blockquote')){
const p=q.firstElementChild,m=p&&p.innerHTML.match(/^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*/i);if(!m)continue;
const t=m[1].toLowerCase();q.className='markdown-alert markdown-alert-'+t;
p.innerHTML=p.innerHTML.slice(m[0].length);if(!p.innerHTML.trim())p.remove();
const h=document.createElement('p');h.className='markdown-alert-title';
h.textContent=t[0].toUpperCase()+t.slice(1);q.prepend(h)}</script>''';

final Future<String> _marked = rootBundle.loadString(
  'assets/web/marked.umd.js',
);

/// Pinching (or Ctrl + wheel, or a trackpad pinch) sets the body font size
/// instead of magnifying the page, so the text reflows to the width; the line
/// between the fingers stays put.
const _zoom = r'''<script>(()=>{
const b=document.body,e=document.documentElement,f=parseFloat(getComputedStyle(b).fontSize);
let k=1,k0=1,d=1;
const z=(n,y)=>{const r=(scrollY+y)/e.scrollHeight;k=Math.min(Math.max(n,.5),4);
b.style.fontSize=f*k+'px';scrollTo(0,r*e.scrollHeight-y)};
const g=t=>Math.hypot(t[0].clientX-t[1].clientX,t[0].clientY-t[1].clientY);
const o={passive:false};
addEventListener('touchstart',v=>{if(v.touches.length==2){d=g(v.touches);k0=k}},o);
addEventListener('touchmove',v=>{const t=v.touches;if(t.length==2){v.preventDefault();
z(k0*g(t)/d,(t[0].clientY+t[1].clientY)/2)}},o);
addEventListener('wheel',v=>{if(v.ctrlKey){v.preventDefault();z(k*Math.exp(-v.deltaY/300),v.clientY)}},o);
addEventListener('gesturestart',v=>{v.preventDefault();k0=k},o);
if(!('ontouchstart' in window))addEventListener('gesturechange',v=>{v.preventDefault();z(k0*v.scale,v.clientY)},o);
})()</script>''';

/// One file of the tree. 刷新 swaps between two renderers: a WebView (the
/// bundled marked.js, fully offline as KiyomiPDF does with PDF.js; pinch
/// resizes the text) and Flutter (the markdown package into flutter_html),
/// the only one on Linux, which has no WebView here. SVG is a picture either
/// way.
class BroTechDocPage extends StatefulWidget {
  const BroTechDocPage({super.key, required this.asset});

  final String asset;

  @override
  State<BroTechDocPage> createState() => _BroTechDocPageState();
}

class _BroTechDocPageState extends State<BroTechDocPage> {
  bool _web = !Platform.isLinux;

  late final String _name = widget.asset.substring(
    widget.asset.lastIndexOf('/') + 1,
  );
  late final String _lower = _name.toLowerCase();
  late final bool _isMd =
      _lower.endsWith('.md') || _lower.endsWith('.markdown');

  // Served as if from the file's place in its repository, so relative
  // images load from GitHub and relative links can be mapped back here.
  late final String _dir = widget.asset.substring(
    0,
    widget.asset.lastIndexOf('/') + 1,
  );
  late final String _raw = () {
    final top = _dir.length > _root.length
        ? _dir.indexOf('/', _root.length) + 1
        : _root.length;
    return 'https://raw.githubusercontent.com/ucxn/${_repo(widget.asset)}/main/'
        '${_dir.substring(top)}';
  }();
  late final String _self = _raw + _name;

  late final Future<String> _text = rootBundle.loadString(widget.asset);
  late final Future<List<String>> _page = Future.wait([_text, _marked]);
  late final Future<dom.Document> _doc = _text.then((text) {
    final doc = html_parser.parse(
      md.markdownToHtml(text, extensionSet: md.ExtensionSet.gitHubWeb),
    );
    final base = Uri.parse(_self);
    for (final e in doc.querySelectorAll('[href],[src]')) {
      for (final k in const ['href', 'src']) {
        final v = e.attributes[k];
        if (v != null && !v.startsWith('#')) {
          // flutter_svg cannot lay out Shields' scaled, length-fitted text;
          // raster.shields.io serves the same badge as PNG.
          e.attributes[k] = base
              .resolve(v)
              .toString()
              .replaceFirst('https://img.shields.io/', 'https://raster.shields.io/');
        }
      }
    }
    return doc;
  });

  static String _css(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static Widget _when<T>(Future<T> future, Widget Function(T) child) =>
      FutureBuilder<T>(
        future: future,
        builder: (_, s) =>
            s.hasData ? child(s.data as T) : const SizedBox.shrink(),
      );

  /// Files of this tree open here, anything else in the in-app browser.
  Future<void> _open(String url) async {
    if (url.startsWith(_raw)) {
      final target = _dir + url.substring(_raw.length).split('#').first;
      if ((await _assets).contains(target)) {
        Get.to(() => BroTechDocPage(asset: target), preventDuplicates: false);
        return;
      }
    }
    PageUtils.inAppWebview(url);
  }

  /// Hands the file itself to the system share sheet. On Windows (whose
  /// share sheet is unreliable) and Linux (which has none) the same button
  /// saves it instead.
  Future<void> _share() async {
    final data = await rootBundle.load(widget.asset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (Platform.isWindows || Platform.isLinux) {
      return StorageUtils.saveBytes2File(
        name: _name,
        bytes: bytes,
      );
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes)],
        // Without it share_plus names the temp file <uuid>.bin.
        fileNameOverrides: [_name],
        sharePositionOrigin: await ShareUtils.sharePositionOrigin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svg = _lower.endsWith('.svg');
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          if (!svg && !Platform.isLinux)
            IconButton(
              tooltip: '刷新',
              onPressed: () => setState(() => _web = !_web),
              icon: const Icon(Icons.refresh_rounded),
            ),
          IconButton(
            tooltip: '分享',
            onPressed: _share,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: svg
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SvgPicture.asset(widget.asset),
                ),
              )
            : _web
            ? _when(_page, (v) => _webView(v[0], v[1]))
            : _isMd
            ? _when(_doc, _html)
            : _when(
                _text,
                (text) => SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    text,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _webView(String text, String marked) {
    final c = ColorScheme.of(context);
    final size = MediaQuery.textScalerOf(context).scale(_isMd ? 17 : 15);
    final line = _css(c.outlineVariant);
    final code = _css(c.surfaceContainerHighest);
    // '<' escaped so no tag inside the text can end the script.
    final json = jsonEncode(text).replaceAll('<', r'\u003c');
    final content = _isMd
        ? '<script>$marked</script>'
              '<script>document.write(marked.parse($json))</script>'
              '$_alertScript'
        : '<pre class="t"></pre>'
              '<script>document.body.firstChild.textContent=$json</script>';
    return InAppWebView(
      webViewEnvironment: webViewEnvironment,
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        useShouldOverrideUrlLoading: true,
        supportZoom: false,
      ),
      initialData: InAppWebViewInitialData(
        baseUrl: WebUri(_self),
        data:
            '<!doctype html><html><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1,'
            'maximum-scale=1,user-scalable=no">'
            '<style>'
            'body{margin:0;padding:16px;font:${size}px/1.6 system-ui,sans-serif;'
            'color:${_css(c.onSurface)};overflow-wrap:break-word}'
            'a{color:${_css(c.primary)};text-decoration:none}'
            'img{max-width:100%}'
            'h1,h2{padding-bottom:.3em;border-bottom:1px solid $line}'
            'code,pre{font-family:ui-monospace,monospace;background:$code;border-radius:6px}'
            'code{padding:.15em .35em;font-size:90%}'
            'pre{padding:12px;overflow:auto;font-size:90%}'
            'pre code{padding:0;background:none;font-size:inherit}'
            'pre.t{margin:0;padding:0;background:none;white-space:pre-wrap;'
            'font-size:inherit;line-height:1.5}'
            'table{display:block;overflow:auto;border-collapse:collapse}'
            'th,td{padding:6px 12px;border:1px solid $line}'
            'blockquote{margin:0;padding:0 1em;color:${_css(c.onSurfaceVariant)};'
            'border-left:4px solid $line}'
            'hr{border:0;border-top:1px solid $line}'
            '.markdown-alert{color:inherit}'
            '.markdown-alert-title{font-weight:600;margin:.5em 0}'
            '${_alerts.entries.map((e) => '.markdown-alert-${e.key}{border-left-color:${_css(Color(e.value))}}'
                '.markdown-alert-${e.key} .markdown-alert-title{color:${_css(Color(e.value))}}').join()}'
            '</style></head><body>'
            '$content$_zoom</body></html>',
      ),
      shouldOverrideUrlLoading: (controller, action) async {
        // The page itself (about:blank / data: where no base URL is
        // honoured) and its own anchors stay; links leave it.
        final url = Uri.decodeFull(action.request.url.toString());
        if (!url.startsWith('http') || url.split('#').first == _self) {
          return .ALLOW;
        }
        _open(url);
        return .CANCEL;
      },
    );
  }

  Widget _html(dom.Document doc) {
    final c = ColorScheme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Html.fromElement(
        documentElement: doc.documentElement,
        extensions: const [
          SvgHtmlExtension(),
          TableHtmlExtension(),
        ],
        style: {
          'html': Style(
            fontSize: FontSize(17),
            lineHeight: const LineHeight(1.6),
          ),
          'a': Style(color: c.primary, textDecoration: TextDecoration.none),
          '.markdown-alert': Style(
            margin: Margins.only(top: 8, bottom: 8),
            padding: HtmlPaddings.only(left: 12),
            border: Border(left: BorderSide(width: 4, color: c.outlineVariant)),
          ),
          '.markdown-alert-title': Style(fontWeight: FontWeight.w600),
          for (final MapEntry(:key, :value) in _alerts.entries) ...{
            '.markdown-alert-$key': Style(
              border: Border(left: BorderSide(width: 4, color: Color(value))),
            ),
            '.markdown-alert-$key .markdown-alert-title': Style(
              color: Color(value),
            ),
          },
          'th,td': Style(
            padding: HtmlPaddings.symmetric(horizontal: 12, vertical: 6),
            border: Border.all(color: c.outlineVariant),
          ),
        },
        onLinkTap: (url, _, _) {
          if (url != null) _open(Uri.decodeFull(url));
        },
      ),
    );
  }
}
