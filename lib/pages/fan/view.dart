import 'package:PiliBro/common/widgets/dialog/dialog.dart';
import 'package:PiliBro/models_new/follow/list.dart';
import 'package:PiliBro/pages/fan/controller.dart';
import 'package:PiliBro/pages/follow_type/view.dart';
import 'package:PiliBro/pages/follow_type/widgets/item.dart';
import 'package:PiliBro/pages/share/view.dart' show UserModel;
import 'package:PiliBro/utils/parse_int.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class FansPage extends StatefulWidget {
  const FansPage({
    super.key,
    this.showName = true,
    this.onSelect,
  });

  final bool showName;
  final ValueChanged<UserModel>? onSelect;

  @override
  State<FansPage> createState() => _FansPageState();

  static void toFansPage({dynamic mid, String? name}) {
    if (mid == null) {
      return;
    }
    Get.toNamed(
      '/fan',
      arguments: {
        'mid': safeToInt(mid),
        'name': name,
      },
    );
  }
}

class _FansPageState extends FollowTypePageState<FansPage> {
  @override
  late final FansController controller;
  late final flag = widget.onSelect == null && controller.isOwner;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      FansController(widget.showName),
      tag: Get.arguments?['mid']?.toString() ?? Utils.generateRandomString(8),
    );
  }

  @override
  PreferredSizeWidget? get appBar => widget.showName
      ? AppBar(
          title: controller.isOwner
              ? const Text('我的粉丝')
              : Obx(() {
                  final name = controller.name.value;
                  if (name != null) return Text('$name的粉丝');
                  return const SizedBox.shrink();
                }),
        )
      : null;

  @override
  Widget buildItem(int index, FollowItemModel item) {
    void onRemove() => showConfirmDialog(
      context: context,
      title: Text('确定移除 ${item.uname} ？'),
      onConfirm: () => controller.onRemoveFan(index, item.mid),
    );

    return FollowTypeItem(
      item: item,
      onTap: () {
        if (widget.onSelect != null) {
          widget.onSelect!(
            UserModel(
              mid: item.mid,
              name: item.uname!,
              avatar: item.face!,
              selected: true,
            ),
          );
          return;
        }
        Get.toNamed('/member?mid=${item.mid}');
      },
      onLongPress: flag ? onRemove : null,
      onSecondaryTap: flag && !PlatformUtils.isMobile ? onRemove : null,
    );
  }
}
