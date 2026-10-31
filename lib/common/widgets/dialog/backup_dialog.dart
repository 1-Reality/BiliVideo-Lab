import 'dart:convert' show jsonDecode;

import 'package:PiliBro/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliBro/services/backup_seal.dart';
import 'package:PiliBro/services/backup_service.dart';
import 'package:PiliBro/utils/date_utils.dart';
import 'package:PiliBro/utils/device_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_utils.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// Exporting: the last choice is ticked. Restoring: only [present] can be
/// ticked, and all of it is.
Future<Set<BackupPart>?> selectBackupParts(
  BuildContext context, {
  required String title,
  required Iterable<BackupPart> offered,
  Set<BackupPart>? present,
  String? note,
}) async {
  final parts = [
    for (final part in offered)
      if (part.available) part,
  ];
  final enabled = {
    for (final part in parts)
      if (present?.contains(part) ?? true) part,
  };
  final stored = GStorage.setting.get(SettingBoxKey.backupParts) as List?;
  final last = stored == null
      ? {
          for (final part in BackupPart.values)
            if (!BackupPart.sealed.contains(part) &&
                part != BackupPart.launchYears &&
                part != BackupPart.cdnDiagnostics)
              part,
        }
      : {for (final name in stored) ?BackupPart.byName[name]};
  final selected = present == null ? last.intersection(enabled) : {...enabled};
  final result = await showDialog<Set<BackupPart>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              if (note != null) Text(note),
              for (final part in parts)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(part.label),
                  value: selected.contains(part),
                  onChanged: enabled.contains(part)
                      ? (value) => setState(
                          () => value!
                              ? selected.add(part)
                              : selected.remove(part),
                        )
                      : null,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => Get.back(result: selected),
            child: const Text('确定'),
          ),
        ],
      ),
    ),
  );
  if (result != null && present == null) {
    // Parts this dialog did not offer keep their remembered state.
    await GStorage.setting.put(SettingBoxKey.backupParts, [
      for (final part in {...last.difference(enabled), ...result}) part.name,
    ]);
  }
  return result;
}

/// A different database version leaves everything greyed out.
Future<Set<BackupPart>?> selectRestoreParts(
  BuildContext context,
  Map manifest, {
  bool textOnly = false,
}) {
  final version = manifest['databaseVersion'];
  final same = version == GStorage.databaseVersion;
  return selectBackupParts(
    context,
    title: '恢复',
    offered: textOnly
        ? BackupPart.values.where((part) => part.text)
        : BackupPart.values,
    present: same
        ? {
            for (final name in (manifest['parts'] as Map).keys)
              ?BackupPart.byName[name],
          }
        : const <BackupPart>{},
    note: same
        ? null
        : '这份备份是数据库 $version，当前是 ${GStorage.databaseVersion}，不能恢复',
  );
}

/// Null when cancelled. Empty is a valid password.
Future<String?> askBackupPassword(
  BuildContext context, {
  required bool export,
  bool retry = false,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(export ? '设置备份密码' : '输入备份密码'),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        decoration: InputDecoration(
          helperText: export ? '登录信息和路由器后台用它加密，导入时要输入' : null,
          errorText: retry ? '密码不对，或者这一项被改动过' : null,
        ),
        onSubmitted: (value) => Get.back(result: value),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(export ? '取消' : '跳过这两项'),
        ),
        FilledButton(
          onPressed: () => Get.back(result: controller.text),
          child: const Text('确定'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Asks for the password when [parts] holds a sealed part, then runs [export]
/// with the derived key; does nothing when the password is cancelled.
Future<void> sealedExport(
  BuildContext context,
  Set<BackupPart> parts,
  Future<void> Function(BackupSeal? seal) export,
) async {
  await BackupService.prepare(parts);
  BackupSeal? seal;
  if (parts.any(BackupPart.sealed.contains)) {
    if (!context.mounted) return;
    final password = await askBackupPassword(context, export: true);
    if (password == null) return;
    SmartDialog.showLoading(msg: '生成密钥');
    try {
      seal = await BackupSeal.create(password);
    } finally {
      SmartDialog.dismiss();
    }
  }
  await export(seal);
}

void toastRestored(List<BackupPart> skipped) => SmartDialog.showToast(
  skipped.isEmpty
      ? '恢复成功'
      : '恢复成功，${skipped.map((e) => e.label).join('、')}未恢复',
);

Future<void> exportBackupFile(
  Set<BackupPart> parts,
  String name, {
  BackupSeal? seal,
}) async {
  try {
    await StorageUtils.saveBytes2File(
      name:
          'pilibro_${name}_${DateFormatUtils.only0_9.format(DateTime.now())}.zip',
      bytes: await BackupService.zip(parts, seal: seal),
      allowedExtensions: const ['zip'],
    );
  } catch (e) {
    SmartDialog.showToast('导出失败：$e');
  }
}

Future<void> _importFile(BuildContext context) async {
  final result = await FilePicker.pickFile(
    type: .custom,
    allowedExtensions: const ['zip'],
  );
  if (result == null || !context.mounted) return;
  try {
    if (await BackupService.restoreZip(
          result.xFile.path,
          (manifest) => selectRestoreParts(context, manifest),
          (retry) => askBackupPassword(context, export: false, retry: retry),
        )
        case final skipped?) {
      toastRestored(skipped);
    }
  } catch (e) {
    SmartDialog.showToast('恢复失败：$e');
  }
}

Future<void> _importText(BuildContext context) async {
  final text = (await Clipboard.getData('text/plain'))?.text;
  if (text == null || text.isEmpty) {
    SmartDialog.showToast('剪贴板无数据');
    return;
  }
  if (!context.mounted) return;
  try {
    if (await BackupService.restoreJson(
          jsonDecode(text),
          (json) => selectRestoreParts(context, json, textOnly: true),
          (retry) => askBackupPassword(context, export: false, retry: retry),
        )
        case final skipped?) {
      toastRestored(skipped);
    }
  } catch (e) {
    SmartDialog.showToast('恢复失败：$e');
  }
}

Future<void> showBackupMenu(BuildContext context) => showDialog(
  context: context,
  builder: (dialogContext) {
    const style = TextStyle(fontSize: 15);
    return SimpleDialog(
      clipBehavior: .hardEdge,
      title: const Text('备份与恢复'),
      children: [
        DialogOption(
          onPressed: () async {
            Get.back();
            final parts = await selectBackupParts(
              context,
              title: '导出至剪贴板',
              offered: BackupPart.values.where((part) => part.text),
            );
            if (parts != null && context.mounted) {
              await sealedExport(
                context,
                parts,
                (seal) async =>
                    Utils.copyText(BackupService.exportJson(parts, seal: seal)),
              );
            }
          },
          child: const Text('导出至剪贴板', style: style),
        ),
        DialogOption(
          onPressed: () async {
            Get.back();
            final parts = await selectBackupParts(
              context,
              title: '导出文件至本地',
              offered: BackupPart.values,
            );
            if (parts != null && context.mounted) {
              await sealedExport(
                context,
                parts,
                (seal) => exportBackupFile(
                  parts,
                  'backup_${DeviceUtils.platformName}',
                  seal: seal,
                ),
              );
            }
          },
          child: const Text('导出文件至本地', style: style),
        ),
        Divider(
          height: 1,
          color: ColorScheme.of(dialogContext).outline.withValues(alpha: 0.1),
        ),
        DialogOption(
          onPressed: () {
            Get.back();
            _importText(context);
          },
          child: const Text('从剪贴板导入', style: style),
        ),
        DialogOption(
          onPressed: () {
            Get.back();
            _importFile(context);
          },
          child: const Text('从本地文件导入', style: style),
        ),
      ],
    );
  },
);
