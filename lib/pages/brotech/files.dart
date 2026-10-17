import 'dart:convert' show jsonEncode;
import 'dart:io' show Platform;

import 'package:PiliBro/main.dart' show webViewEnvironment;
import 'package:PiliBro/utils/page_utils.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

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
                  leading: const FaIcon(FontAwesomeIcons.github),
                  title: const Text('上 GitHub 获取源文件'),
                  subtitle: Text('顺手给我点个 Star 哟～　ucxn/$repo'),
                  trailing: const Icon(Icons.star_rounded, color: Colors.amber),
                  onTap: () => PageUtils.launchURL('https://github.com/ucxn/$repo'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One file: Markdown through the bundled marked.js in a WebView, fully
/// offline (as KiyomiPDF does with PDF.js); SVG as a picture; anything else,
/// and Markdown where there is no WebView, as plain text.
class BroTechDocPage extends StatelessWidget {
  const BroTechDocPage({super.key, required this.asset});

  final String asset;

  static String _css(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final name = asset.substring(asset.lastIndexOf('/') + 1);
    final lower = name.toLowerCase();
    final Widget body;
    if (lower.endsWith('.svg')) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SvgPicture.asset(asset),
        ),
      );
    } else if ((lower.endsWith('.md') || lower.endsWith('.markdown')) &&
        !Platform.isLinux) {
      body = _markdown(context);
    } else {
      body = FutureBuilder(
        future: rootBundle.loadString(asset),
        builder: (context, snapshot) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            snapshot.data ?? '',
            style: const TextStyle(fontFamily: 'monospace', height: 1.5),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _markdown(BuildContext context) {
    final c = ColorScheme.of(context);
    // Served as if from the file's place in its repository, so relative
    // images load from GitHub and relative links can be mapped back here.
    final dir = asset.substring(0, asset.lastIndexOf('/') + 1);
    final top = dir.length > _root.length
        ? dir.indexOf('/', _root.length) + 1
        : _root.length;
    final raw =
        'https://raw.githubusercontent.com/ucxn/${_repo(asset)}/main/'
        '${dir.substring(top)}';
    final self = raw + asset.substring(dir.length);
    return FutureBuilder(
      future: Future.wait([
        rootBundle.loadString(asset),
        rootBundle.loadString('assets/web/marked.umd.js'),
      ]),
      builder: (context, snapshot) {
        final [md, marked] = snapshot.data ?? const ['', ''];
        if (marked.isEmpty) return const SizedBox.shrink();
        final line = _css(c.outlineVariant);
        final code = _css(c.surfaceContainerHighest);
        return InAppWebView(
          webViewEnvironment: webViewEnvironment,
          initialSettings: InAppWebViewSettings(
            transparentBackground: true,
            useShouldOverrideUrlLoading: true,
          ),
          initialData: InAppWebViewInitialData(
            baseUrl: WebUri(self),
            data:
                '<!doctype html><html><head><meta charset="utf-8">'
                '<meta name="viewport" content="width=device-width,initial-scale=1">'
                '<style>'
                'body{margin:0;padding:16px;font:15px/1.6 system-ui,sans-serif;'
                'color:${_css(c.onSurface)};overflow-wrap:break-word}'
                'a{color:${_css(c.primary)};text-decoration:none}'
                'img{max-width:100%}'
                'h1,h2{padding-bottom:.3em;border-bottom:1px solid $line}'
                'code,pre{font-family:ui-monospace,monospace;background:$code;border-radius:6px}'
                'code{padding:.15em .35em;font-size:90%}'
                'pre{padding:12px;overflow:auto}pre code{padding:0;background:none}'
                'table{display:block;overflow:auto;border-collapse:collapse}'
                'th,td{padding:6px 12px;border:1px solid $line}'
                'blockquote{margin:0;padding:0 1em;color:${_css(c.onSurfaceVariant)};'
                'border-left:4px solid $line}'
                'hr{border:0;border-top:1px solid $line}'
                '</style><script>$marked</script></head><body>'
                // '<' escaped so no tag inside the text can end the script.
                '<script>document.write(marked.parse('
                '${jsonEncode(md).replaceAll('<', r'<')}))</script>'
                '</body></html>',
          ),
          shouldOverrideUrlLoading: (controller, action) async {
            // The page itself (about:blank / data: where no base URL is
            // honoured) and its own anchors stay; links leave it.
            final url = Uri.decodeFull(action.request.url.toString());
            if (!url.startsWith('http') || url.split('#').first == self) {
              return .ALLOW;
            }
            if (url.startsWith(raw)) {
              final target = dir + url.substring(raw.length).split('#').first;
              if ((await _assets).contains(target)) {
                Get.to(
                  () => BroTechDocPage(asset: target),
                  preventDuplicates: false,
                );
                return .CANCEL;
              }
            }
            PageUtils.launchURL(url);
            return .CANCEL;
          },
        );
      },
    );
  }
}
