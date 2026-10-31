import 'package:PiliBro/common/widgets/custom_icon.dart';
import 'package:PiliBro/models/common/dynamic/dynamics_type.dart';
import 'package:PiliBro/models/dynamics/result.dart'
    show DynamicsDataModel, ItemModulesModel;
import 'package:PiliBro/pages/main/controller.dart';
import 'package:PiliBro/pages/setting/models/model.dart';
import 'package:PiliBro/pages/setting/widgets/select_dialog.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide RefreshIndicator;

List<SettingsModel> get dynSettings => [
  SplitModel(
    normalModel: const NormalModel.split(
      title: '检查未读动态',
      subtitle: '点击设置检查周期（秒）',
      leading: Icon(Icons.notifications_none),
    ),
    switchModel: SwitchModel.split(
      defaultVal: true,
      setKey: SettingBoxKey.checkDynamic,
      onChanged: (value) => Get.find<MainController>().checkDynamic = value,
      onTap: _showDynDialog,
    ),
  ),
  SwitchModel(
    title: '显示动态警告争议信息',
    leading: const Icon(Icons.warning_amber_rounded),
    setKey: SettingBoxKey.showDynDispute,
    defaultVal: true,
    onChanged: (val) => ItemModulesModel.showDynDispute = val,
  ),
  getBanWordModel(
    title: '动态关键词过滤',
    key: SettingBoxKey.banWordForDyn,
    onChanged: (value) {
      DynamicsDataModel.banWordForDyn = value;
      DynamicsDataModel.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  const SwitchModel(
    title: '发布/转发动态反诈',
    subtitle: '发布/转发动态后检查动态是否可见',
    leading: Icon(CustomIcons.shield_published),
    setKey: SettingBoxKey.enableCreateDynAntifraud,
    defaultVal: true,
  ),
  SwitchModel(
    title: '屏蔽带货动态',
    leading: const Icon(CustomIcons.shopping_bag_not_interested),
    setKey: SettingBoxKey.antiGoodsDyn,
    defaultVal: false,
    onChanged: (value) => DynamicsDataModel.antiGoodsDyn = value,
  ),
  const SwitchModel(
    title: '动态/专栏详情页展示底部操作栏',
    leading: Icon(Icons.more_horiz),
    setKey: SettingBoxKey.showDynActionBar,
    defaultVal: true,
  ),
  NormalModel(
    title: '动态展示',
    leading: const Icon(Icons.dynamic_feed_rounded),
    getSubtitle: () => '当前优先展示「${Pref.defaultDynamicType.label}」',
    onTap: _showDefDynDialog,
  ),
  SwitchModel(
    title: '显示动态互动内容',
    subtitle: '开启后则在动态卡片底部显示互动内容（如关注的人点赞、热评等）',
    leading: const Icon(Icons.quickreply_outlined),
    setKey: SettingBoxKey.showDynInteraction,
    defaultVal: true,
    onChanged: (val) => ItemModulesModel.showDynInteraction = val,
  ),
];

void _showDynDialog(BuildContext context) {
  String dynamicPeriod = (Pref.dynamicPeriod ~/ 1000).toString();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('检查周期'),
      content: TextFormField(
        autofocus: true,
        initialValue: dynamicPeriod,
        keyboardType: TextInputType.number,
        onChanged: (value) => dynamicPeriod = value,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(suffixText: 's'),
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
          onPressed: () {
            try {
              final val = int.parse(dynamicPeriod) * 1000;
              Get.back();
              GStorage.setting.put(SettingBoxKey.dynamicPeriod, val);
              Get.find<MainController>().setDynamicPeriod(val);
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

Future<void> _showDefDynDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<DynamicsTabType>(
    context: context,
    builder: (context) => SelectDialog<DynamicsTabType>(
      title: '动态展示',
      value: Pref.defaultDynamicType,
      values: DynamicsTabType.values.take(4).map((e) => (e, e.label)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.defaultDynamicType, res.index);
    setState();
  }
}
