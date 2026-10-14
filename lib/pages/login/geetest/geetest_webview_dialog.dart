import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Platform;

import 'package:PiliBro/http/browser_ua.dart';
import 'package:PiliBro/http/init.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/main.dart';
import 'package:PiliBro/plugin/linux_webview.dart';
import 'package:PiliBro/utils/accounts/account.dart';
import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class GeetestWebviewDialog extends StatefulWidget {
  const GeetestWebviewDialog(this.gt, this.challenge, {super.key});

  final String gt;
  final String challenge;

  @override
  State<GeetestWebviewDialog> createState() => _GeetestWebviewDialogState();

  static Future<Map<String, dynamic>?> geetest(String gt, String challenge) {
    return showDialog<Map<String, dynamic>>(
      context: Get.context!,
      builder: (context) => GeetestWebviewDialog(gt, challenge),
    );
  }
}

class _GeetestWebviewDialogState extends State<GeetestWebviewDialog> {
  static const _geetestJsUri =
      'https://static.geetest.com/static/js/fullpage.0.0.0.js';

  // The WebView's own reason for the geetest script failing to load; the page
  // itself only sees that Geetest is undefined.
  String? _scriptError;

  // A captcha that never appears blocks login, so the reason stays on screen
  // long enough to read or screenshot.
  static void _toastError(String detail) => SmartDialog.showToast(
    '验证码加载失败：$detail',
    displayTime: const Duration(seconds: 10),
  );

  late final Future<LoadingState<String>> _future;

  static String _showJs(String response) =>
      'if(typeof Geetest=="undefined"){document.body.textContent="验证码加载失败";R("error","geetest script load failed")}'
      'else{t=Geetest($response).onSuccess(()=>R("success",t.getValidate())).onError(o=>R("error",o)).onClose(o=>R("close",o));t.onReady(()=>t.verify())}';

  @override
  void initState() {
    super.initState();
    _future = _getConfig(widget.gt, widget.challenge);
  }

  static Future<LoadingState<String>> _getConfig(
    String gt,
    String challenge,
  ) async {
    final res = await Request().get<String>(
      'https://api.geetest.com/gettype.php',
      queryParameters: {'gt': gt},
      options: Options(
        responseType: ResponseType.plain,
        extra: {'account': const NoAccount()},
      ),
    );
    if (res.data case final String data) {
      if (data.startsWith('(') && data.endsWith(')')) {
        final Map<String, dynamic> config;
        try {
          config = jsonDecode(data.substring(1, data.length - 1));
        } catch (e) {
          return Error(e.toString());
        }
        if (config['status'] == 'success') {
          return Success(
            jsonEncode(
              config['data'] as Map<String, dynamic>..addAll({
                "gt": gt,
                "challenge": challenge,
                "offline": false,
                "new_captcha": true,
                "product": "bind",
                "width": "100%",
                "https": true,
                "protocol": "https://",
              }),
            ),
          );
        }
        return Error(data);
      }
    }
    return Error(res.data['message']);
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isLinux) {
      return AlertDialog(
        title: const Text('验证码'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: FutureBuilder(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final config = snapshot.data!;
              if (config case Error()) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _toastError(config.toString());
                    Get.back();
                  }
                });
                return const SizedBox.shrink();
              }
              final response = (config as Success<String>).response;
              final html =
                  '''
<!DOCTYPE html><html><head></head><body>
<script src="$_geetestJsUri"></script>
<script>
  R=(n,o)=>window.webkit.messageHandlers.msgToNative.postMessage(n+':'+JSON.stringify(o))
  ${_showJs(response)}
</script>
</body></html>
''';
              return LinuxWebview(
                initialHtml: html,
                userAgent: BrowserUa.mob,
                incognito: true,
                onWebMessageReceived: (msg) {
                  final msgStr = msg.toString();
                  if (msgStr.startsWith("success:")) {
                    final dataStr = msgStr.substring("success:".length);
                    try {
                      final data = jsonDecode(dataStr);
                      Get.back(result: data);
                    } catch (e) {
                      debugPrint('geetest decode error: $e');
                    }
                  } else if (msgStr.startsWith("error:")) {
                    _toastError(msgStr.substring(6));
                  } else if (msgStr.startsWith('close:')) {
                    Get.back();
                  }
                },
              );
            },
          ),
        ),
      );
    }

    return Stack(
      children: [
        InAppWebView(
          webViewEnvironment: webViewEnvironment,
          initialSettings: InAppWebViewSettings(
            clearCache: true,
            javaScriptEnabled: true,
            forceDark: ForceDark.AUTO,
            useHybridComposition: false,
            algorithmicDarkeningAllowed: true,
            useShouldOverrideUrlLoading: true,
            userAgent: BrowserUa.mob,
            mixedContentMode: .MIXED_CONTENT_ALWAYS_ALLOW,

            incognito: true,
            allowFileAccess: false,
            allowsLinkPreview: false,
            allowContentAccess: false,
            useOnDownloadStart: false,
            geolocationEnabled: false,
            thirdPartyCookiesEnabled: false,
            enterpriseAuthenticationAppLinkPolicyEnabled: false,
            saveFormData: false,
            safeBrowsingEnabled: false,
            isFraudulentWebsiteWarningEnabled: false,
            domStorageEnabled: false,
            databaseEnabled: false,
            cacheEnabled: false,
            cacheMode: .LOAD_NO_CACHE,

            horizontalScrollBarEnabled: false,
            verticalScrollBarEnabled: false,
            overScrollMode: .NEVER,

            pageZoom: Platform.isIOS ? 3 : 1,
          ),
          initialData: InAppWebViewInitialData(
            data:
                '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width"></head><body><script src="$_geetestJsUri"></script><script>R=(n,o)=>window.flutter_inappwebview?.callHandler(n,o)</script></body></html>',
          ),
          onWebViewCreated: (ctr) {
            ctr
                            ..addJavaScriptHandler(
                handlerName: 'success',
                callback: (args) {
                  if (args.isNotEmpty) {
                    if (args[0] case Map<String, dynamic> data) {
                      Get.back(result: data);
                      return;
                    }
                  }
                  debugPrint('geetest invalid result: $args');
                },
              )
              ..addJavaScriptHandler(
                handlerName: 'error',
                callback: (args) {
                  final error = args.isEmpty ? null : args.first;
                  _toastError(
                    error is Map
                        ? '${error['error_code'] ?? error['code'] ?? ''} '
                              '${error['msg'] ?? error['user_error'] ?? error}'
                        : _scriptError ?? '$error',
                  );
                },
              )
              ..addJavaScriptHandler(
                handlerName: 'close',
                callback: (args) => Get.back(),
              );
          },
          onReceivedError: (_, request, error) {
            if (request.url.toString() == _geetestJsUri) {
              _scriptError = error.description;
            }
          },
          onReceivedHttpError: (_, request, response) {
            if (request.url.toString() == _geetestJsUri) {
              _scriptError =
                  'HTTP ${response.statusCode} ${response.reasonPhrase ?? ''}';
            }
          },
          onLoadStop: (ctr, _) async {
            final config = await _future;
            if (!mounted) return;
            if (config case Success(:final response)) {
              ctr.evaluateJavascript(source: _showJs(response));
            } else {
              _toastError(config.toString());
              Get.back();
            }
          },
        ),
        Positioned(
          left: 8,
          top: 8,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: Get.back,
            tooltip: '关闭',
          ),
        ),
      ],
    );
  }
}
