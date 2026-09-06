import 'dart:async' show FutureOr;
import 'dart:convert' show utf8, jsonDecode, jsonEncode;

import 'package:PiliBro/common/style.dart';
import 'package:PiliBro/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliBro/utils/extension/theme_ext.dart';
import 'package:PiliBro/utils/storage_utils.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart'
    show Clipboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show FocusManager, KeyEventResult;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/base16/github.dart';
import 'package:re_highlight/styles/github-dark.dart';

void exportToClipBoard({
  required ValueGetter<String> onExport,
}) {
  Utils.copyText(onExport());
}

void exportToLocalFile({
  required ValueGetter<String> onExport,
  required ValueGetter<String> localFileName,
}) {
  final res = utf8.encode(onExport());
  StorageUtils.saveBytes2File(
    name:
        'pilibro_${localFileName()}_'
        '${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}.json',
    bytes: res,
    allowedExtensions: const ['json'],
  );
}

const _qrTargetPageBytes = 1273;
const _qrMaxPages = 17;

Future<void> exportToQrCode(
  BuildContext context, {
  required ValueGetter<String> onExport,
}) async {
  final data = jsonEncode(jsonDecode(onExport()));
  final bytes = utf8.encode(data).length;
  var pageCount =
      (bytes + _qrTargetPageBytes - 1) ~/ _qrTargetPageBytes;
  if (pageCount > _qrMaxPages) pageCount = _qrMaxPages;

  final chunks = _splitQrData(data, bytes, pageCount);
  final List<QrImage> images;
  try {
    images = [
      for (final chunk in chunks)
        QrImage(
          QrCode.fromData(
            data: chunk,
            errorCorrectLevel: QrErrorCorrectLevel.L,
          ),
        ),
    ];
  } on InputTooLongException {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置内容过多'),
        content: Text(
          '当前设置数据为 $bytes 字节，17 张标准二维码仍无法容纳。'
          '请改用剪贴板或文件导出。',
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    return;
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    useSafeArea: false,
    builder: (_) => _QrExportDialog(images: images),
  );
}

List<String> _splitQrData(String data, int totalBytes, int pageCount) {
  if (pageCount <= 1) return [data];

  final chunks = <String>[];
  var buffer = StringBuffer();
  var chunkBytes = 0;
  var remainingBytes = totalBytes;
  var remainingPages = pageCount;
  var targetBytes =
      (remainingBytes + remainingPages - 1) ~/ remainingPages;

  for (final rune in data.runes) {
    buffer.writeCharCode(rune);
    chunkBytes += switch (rune) {
      <= 0x7F => 1,
      <= 0x7FF => 2,
      <= 0xFFFF => 3,
      _ => 4,
    };

    if (chunks.length < pageCount - 1 && chunkBytes >= targetBytes) {
      chunks.add(buffer.toString());
      buffer = StringBuffer();
      remainingBytes -= chunkBytes;
      remainingPages--;
      targetBytes =
          (remainingBytes + remainingPages - 1) ~/ remainingPages;
      chunkBytes = 0;
    }
  }
  chunks.add(buffer.toString());
  return chunks;
}

class _QrExportDialog extends StatefulWidget {
  const _QrExportDialog({required this.images});

  final List<QrImage> images;

  @override
  State<_QrExportDialog> createState() => _QrExportDialogState();
}

class _QrExportDialogState extends State<_QrExportDialog> {
  static const _decoration = PrettyQrDecoration(
    shape: PrettyQrSquaresSymbol(),
    background: Colors.white,
    quietZone: PrettyQrQuietZone.modules(4),
  );

  int _index = 0;
  late final KeyEventResult Function(KeyEvent) _keyHandler;

  @override
  void initState() {
    super.initState();
    _keyHandler = _handleKeyEvent;
    FocusManager.instance.addEarlyKeyEventHandler(_keyHandler);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_keyHandler);
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => _index > 0 ? _index - 1 : _index,
      LogicalKeyboardKey.arrowRight =>
        _index + 1 < widget.images.length ? _index + 1 : _index,
      LogicalKeyboardKey.arrowUp => 0,
      LogicalKeyboardKey.arrowDown => widget.images.length - 1,
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    if (next != _index) setState(() => _index = next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.images[_index];
    final colorScheme = ColorScheme.of(context);

    return Dialog.fullscreen(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        minimum: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final proposedSideWidth = constraints.maxWidth * 0.14;
            final sideWidth = proposedSideWidth < 72
                ? 72.0
                : proposedSideWidth > 220
                ? 220.0
                : proposedSideWidth;

            return Row(
              children: [
                SizedBox(
                  width: sideWidth,
                  child: _buildLeftHint(context),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, qrConstraints) {
                      final maxQrSide =
                          qrConstraints.maxWidth < qrConstraints.maxHeight
                          ? qrConstraints.maxWidth
                          : qrConstraints.maxHeight;
                      final devicePixelRatio =
                          MediaQuery.devicePixelRatioOf(context);
                      final moduleCount = image.moduleCount + 8;
                      final physicalSide =
                          (maxQrSide * devicePixelRatio).floor();
                      final pixelsPerModule = physicalSide ~/ moduleCount;
                      final qrSide = pixelsPerModule > 0
                          ? pixelsPerModule * moduleCount / devicePixelRatio
                          : maxQrSide;

                      return Center(
                        child: SizedBox.square(
                          dimension: qrSide,
                          child: PrettyQrView(
                            qrImage: image,
                            decoration: _decoration,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: sideWidth,
                  child: _buildRightHint(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeftHint(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    if (widget.images.length == 1) {
      return Center(
        child: Text('1 / 1', style: style, textAlign: TextAlign.center),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('↑ 第一张', style: style, textAlign: TextAlign.center),
        const SizedBox(height: 28),
        Text(
          '${_index + 1} / ${widget.images.length}',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        Text('← 上一张', style: style, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildRightHint(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    if (widget.images.length == 1) {
      return Center(
        child: Text('扫描即为 JSON', style: style, textAlign: TextAlign.center),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('下一张 →', style: style, textAlign: TextAlign.center),
        const SizedBox(height: 28),
        Text('按序拼接', style: style, textAlign: TextAlign.center),
        const SizedBox(height: 28),
        Text('最后一张 ↓', style: style, textAlign: TextAlign.center),
      ],
    );
  }
}

Future<void> importFromClipBoard<T>(
  BuildContext context, {
  required String title,
  required ValueGetter<String> onExport,
  required FutureOr<void> Function(T json) onImport,
  bool showConfirmDialog = true,
}) async {
  final data = await Clipboard.getData('text/plain');
  if (data?.text case final text? when (text.isNotEmpty)) {
    if (!context.mounted) return;
    final T json;
    final String formatText;
    try {
      json = jsonDecode(text);
      formatText = Utils.jsonEncoder.convert(json);
    } catch (e) {
      SmartDialog.showToast('解析json失败：$e');
      return;
    }
    bool? executeImport;
    if (showConfirmDialog) {
      final highlight = Highlight()..registerLanguage('json', langJson);
      final result = highlight.highlight(
        code: formatText,
        language: 'json',
      );
      late TextSpanRenderer renderer;
      bool? isDarkMode;
      executeImport = await showDialog<bool>(
        context: context,
        builder: (context) {
          final colorScheme = ColorScheme.of(context);
          final isDark = colorScheme.isDark;
          if (isDark != isDarkMode) {
            isDarkMode = isDark;
            renderer = TextSpanRenderer(
              null,
              isDark ? githubDarkTheme : githubTheme,
            );
            result.render(renderer);
          }
          return AlertDialog(
            title: Text('是否导入如下$title？'),
            content: SingleChildScrollView(
              child: Text.rich(renderer.span!),
            ),
            actions: [
              TextButton(
                onPressed: Get.back,
                child: Text('取消', style: TextStyle(color: colorScheme.outline)),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
    } else {
      executeImport = true;
    }
    if (executeImport ?? false) {
      try {
        await onImport(json);
        SmartDialog.showToast('导入成功');
      } catch (e) {
        SmartDialog.showToast('导入失败：$e');
      }
    }
  } else {
    SmartDialog.showToast('剪贴板无数据');
    return;
  }
}

Future<void> importFromLocalFile<T>({
  required FutureOr<void> Function(T json) onImport,
}) async {
  final result = await FilePicker.pickFile(
    type: .custom,
    allowedExtensions: const ['json', 'txt'],
  );
  if (result != null) {
    final data = await result.xFile.readAsString();
    final T json;
    try {
      json = jsonDecode(data);
    } catch (e) {
      SmartDialog.showToast('解析json失败：$e');
      return;
    }
    try {
      await onImport(json);
      SmartDialog.showToast('导入成功');
    } catch (e) {
      SmartDialog.showToast('导入失败：$e');
    }
  }
}

void importFromInput<T>(
  BuildContext context, {
  required String title,
  required FutureOr<void> Function(T json) onImport,
}) {
  final key = GlobalKey<FormFieldState<String>>();
  late T json;
  String? forceErrorText;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('输入$title'),
      constraints: Style.dialogFixedConstraints,
      content: TextFormField(
        key: key,
        minLines: 4,
        maxLines: 12,
        autofocus: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          errorMaxLines: 3,
        ),
        validator: (value) {
          if (forceErrorText != null) return forceErrorText;
          try {
            json = jsonDecode(value!) as T;
            return null;
          } catch (e) {
            return '解析json失败：$e';
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(
              color: ColorScheme.of(context).outline,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            if (key.currentState?.validate() == true) {
              try {
                await onImport(json);
                Get.back();
                SmartDialog.showToast('导入成功');
                return;
              } catch (e) {
                forceErrorText = '导入失败：$e';
              }
              key.currentState?.validate();
              forceErrorText = null;
            }
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

Future<void> showImportExportDialog<T>(
  BuildContext context, {
  required String title,
  required ValueGetter<String> onExport,
  required FutureOr<void> Function(T json) onImport,
  required ValueGetter<String> localFileName,
}) => showDialog(
  context: context,
  builder: (context) {
    const style = TextStyle(fontSize: 15);
    return SimpleDialog(
      clipBehavior: .hardEdge,
      title: Text('导入/导出$title'),
      children: [
        DialogOption(
          child: const Text('导出至剪贴板', style: style),
          onPressed: () {
            Get.back();
            exportToClipBoard(onExport: onExport);
          },
        ),
        DialogOption(
          child: const Text('导出文件至本地', style: style),
          onPressed: () {
            Get.back();
            exportToLocalFile(onExport: onExport, localFileName: localFileName);
          },
        ),
        Divider(
          height: 1,
          color: ColorScheme.of(context).outline.withValues(alpha: 0.1),
        ),
        DialogOption(
          child: const Text('输入', style: style),
          onPressed: () {
            Get.back();
            importFromInput<T>(context, title: title, onImport: onImport);
          },
        ),
        DialogOption(
          child: const Text('从剪贴板导入', style: style),
          onPressed: () {
            Get.back();
            importFromClipBoard<T>(
              context,
              title: title,
              onExport: onExport,
              onImport: onImport,
            );
          },
        ),
        DialogOption(
          child: const Text('从本地文件导入', style: style),
          onPressed: () {
            Get.back();
            importFromLocalFile<T>(onImport: onImport);
          },
        ),
      ],
    );
  },
);
