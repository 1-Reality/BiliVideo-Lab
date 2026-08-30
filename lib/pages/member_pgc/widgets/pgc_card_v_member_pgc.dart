import 'package:PiliBro/common/style.dart';
import 'package:PiliBro/common/widgets/image/image_save.dart';
import 'package:PiliBro/common/widgets/image/network_img_layer.dart';
import 'package:PiliBro/models_new/space/space_archive/item.dart';
import 'package:PiliBro/utils/page_utils.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

// 视频卡片 - 垂直布局
class PgcCardVMemberPgc extends StatelessWidget {
  const PgcCardVMemberPgc({
    super.key,
    required this.item,
  });

  final SpaceArchiveItem item;

  @override
  Widget build(BuildContext context) {
    void onLongPress() => imageSaveDialog(
      title: item.title,
      cover: item.cover,
    );
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: Style.mdRadius),
      child: InkWell(
        borderRadius: Style.mdRadius,
        onTap: () => PageUtils.viewPgc(seasonId: item.param),
        onLongPress: onLongPress,
        onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 0.75,
              child: LayoutBuilder(
                builder: (context, boxConstraints) {
                  return NetworkImgLayer(
                    src: item.cover,
                    width: boxConstraints.maxWidth,
                    height: boxConstraints.maxHeight,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 5, 0, 3),
              child: Text(
                item.title,
                textAlign: TextAlign.start,
                style: const TextStyle(
                  letterSpacing: 0.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
