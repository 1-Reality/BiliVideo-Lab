import 'dart:io' show Platform;

import 'package:PiliBro/common/widgets/custom_icon.dart';
import 'package:PiliBro/grpc/reply.dart';
import 'package:PiliBro/models/common/reply/reply_sort_type.dart';
import 'package:PiliBro/pages/setting/models/model.dart';
import 'package:PiliBro/pages/setting/widgets/select_dialog.dart';
import 'package:PiliBro/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart' hide RefreshIndicator;

List<SettingsModel> get replySettings => [
  const SwitchModel(
    title: '显示视频评论',
    leading: Icon(MdiIcons.commentTextOutline),
    setKey: SettingBoxKey.showVideoReply,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '显示番剧评论',
    leading: Icon(MdiIcons.commentTextOutline),
    setKey: SettingBoxKey.showBangumiReply,
    defaultVal: true,
  ),
  NormalModel(
    title: '评论折叠行数',
    subtitle: '0行为不折叠',
    leading: const Icon(Icons.compress),
    getTrailing: (theme) => Text(
      '${ReplyItemGrpc.replyLengthLimit}行',
      style: theme.textTheme.titleSmall,
    ),
    onTap: _showReplyLengthDialog,
  ),
  const SwitchModel(
    title: '记录评论',
    leading: Icon(Icons.message_outlined),
    setKey: SettingBoxKey.saveReply,
    defaultVal: true,
    needReboot: true,
  ),
  const SwitchModel(
    title: '发评反诈',
    subtitle: '发送评论后检查评论是否可见',
    leading: Icon(CustomIcons.shield_reply),
    setKey: SettingBoxKey.enableCommAntifraud,
    defaultVal: true,
  ),
  if (Platform.isAndroid)
    const SwitchModel(
      title: '使用「哔哩发评反诈」检查评论',
      subtitle: '若未安装该应用，可能会导致上一开关失效；但哥哥科技版已经缓解该问题！',
      leading: Icon(
        FontAwesomeIcons.b,
        size: 22,
      ),
      setKey: SettingBoxKey.biliSendCommAntifraud,
      defaultVal: false,
    ),
  SwitchModel(
    title: '屏蔽带货评论',
    leading: const Icon(CustomIcons.shopping_bag_not_interested),
    setKey: SettingBoxKey.antiGoodsReply,
    defaultVal: false,
    onChanged: (value) => ReplyGrpc.antiGoodsReply = value,
  ),
  const NormalModel(
    title: '屏蔽评论@数量',
    getSubtitle: _replyAtBlockSubtitle,
    leading: Icon(Icons.pin_outlined),
    onTap: _showReplyAtBlockDialog,
  ),
  const SwitchModel(
    title: '屏蔽只包含@的评论',
    leading: Icon(Icons.alternate_email),
    setKey: SettingBoxKey.blockAtOnlyReply,
    onChanged: _onBlockAtOnlyReplyChanged,
  ),
  const SwitchModel(
    title: '屏蔽复制简介评论',
    leading: Icon(Icons.summarize),
    setKey: SettingBoxKey.filterIntro,
    defaultVal: false,
  ),
  getBanWordModel(
    title: '评论关键词过滤',
    key: SettingBoxKey.banWordForReply,
    onChanged: (value) {
      ReplyGrpc.replyRegExp = value;
      ReplyGrpc.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  SwitchModel(
    title: '评论区搜索关键词',
    subtitle: '展示评论区搜索关键词',
    leading: const Icon(Icons.search_outlined),
    setKey: SettingBoxKey.enableWordRe,
    defaultVal: true,
    onChanged: (value) => ReplyItemGrpc.enableWordRe = value,
  ),
  const SwitchModel(
    title: '默认展示评论区',
    subtitle: '在视频详情页默认切换至评论区页（仅Tab型布局）',
    leading: Icon(Icons.mode_comment_outlined),
    setKey: SettingBoxKey.defaultShowComment,
    defaultVal: false,
  ),
  NormalModel(
    title: '评论展示',
    leading: const Icon(Icons.whatshot_outlined),
    getSubtitle: () => '当前优先展示「${Pref.replySortType.desc}」',
    onTap: _showReplySortDialog,
  ),
  NormalModel(
    title: '楼中楼评论展示',
    leading: const Icon(Icons.subdirectory_arrow_right_outlined),
    getSubtitle: () => '当前优先展示「${Pref.reply2SortType.reply2Title}」',
    onTap: _showReply2SortDialog,
  ),
];

void _showReplyLengthDialog(BuildContext context, VoidCallback setState) {
  String replyLengthLimit = ReplyItemGrpc.replyLengthLimit.toString();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('评论折叠行数'),
      content: TextFormField(
        autofocus: true,
        initialValue: replyLengthLimit,
        keyboardType: TextInputType.number,
        onChanged: (value) => replyLengthLimit = value,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(suffixText: '行'),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () async {
            try {
              final val = int.parse(replyLengthLimit);
              Get.back();
              ReplyItemGrpc.replyLengthLimit = val == 0 ? null : val;
              await GStorage.setting.put(SettingBoxKey.replyLengthLimit, val);
              setState();
            } catch (e) {
              SmartDialog.showToast(e.toString());
            }
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

String _replyAtBlockSubtitle() {
  final blockReplyAtCount = Pref.blockReplyAtCount;
  if (blockReplyAtCount == null) {
    return '禁用';
  }
  return '屏蔽$blockReplyAtCount个@及以上的评论';
}

Future<void> _showReplyAtBlockDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  void onChanged([int? value]) {
    Get.back();
    ReplyGrpc.blockReplyAtCount = value;
    GStorage.setting
        .put(SettingBoxKey.blockReplyAtCount, value)
        .whenComplete(setState);
  }

  var countStr = Pref.blockReplyAtCount?.toString();
  await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('屏蔽@的数量'),
      content: TextFormField(
        autofocus: true,
        keyboardType: .number,
        initialValue: countStr,
        onChanged: (value) => countStr = value,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      actions: [
        TextButton(
          onPressed: onChanged,
          child: const Text('禁用'),
        ),
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () {
            try {
              final count = int.parse(countStr!);
              onChanged(count > 0 ? count : null);
            } catch (e) {
              SmartDialog.showToast(e.toString());
            }
          },
          child: const Text('确认'),
        ),
      ],
    ),
  );
}

void _onBlockAtOnlyReplyChanged(bool value) =>
    ReplyGrpc.blockAtOnlyReply = value;

Future<void> _showReplySortDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<ReplySortType>(
    context: context,
    builder: (context) => SelectDialog<ReplySortType>(
      title: '评论展示',
      value: Pref.replySortType,
      values: ReplySortType.values.take(2).map((e) => (e, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.replySortType, res.index);
    setState();
  }
}

Future<void> _showReply2SortDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<ReplySortType>(
    context: context,
    builder: (context) => SelectDialog<ReplySortType>(
      title: '评论楼中楼展示',
      value: Pref.reply2SortType,
      values: ReplySortType.values
          .take(2)
          .map((e) => (e, e.reply2Title))
          .toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.reply2SortType, res.index);
    setState();
  }
}
