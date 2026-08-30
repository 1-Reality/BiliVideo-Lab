import 'package:PiliBro/models/common/video/source_type.dart';
import 'package:PiliBro/models_new/later/data.dart';
import 'package:PiliBro/models_new/later/list.dart';
import 'package:PiliBro/pages/common/search/common_search_page.dart';
import 'package:PiliBro/pages/later/widgets/video_card_h_later.dart';
import 'package:PiliBro/pages/later_search/controller.dart';
import 'package:PiliBro/utils/grid.dart';
import 'package:PiliBro/utils/page_utils.dart';
import 'package:PiliBro/utils/request_utils.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LaterSearchPage extends StatefulWidget {
  const LaterSearchPage({super.key});

  @override
  State<LaterSearchPage> createState() => _LaterSearchPageState();
}

class _LaterSearchPageState
    extends CommonSearchPageState<LaterSearchPage, LaterData, LaterItemModel>
    with GridMixin {
  @override
  final LaterSearchController controller = Get.put(
    LaterSearchController(),
    tag: Utils.generateRandomString(8),
  );

  @override
  List<Widget>? get multiSelectActions {
    final btnStyle = TextButton.styleFrom(visualDensity: .compact);
    final textStyle = TextStyle(
      color: ColorScheme.of(context).onSurfaceVariant,
    );
    return [
      TextButton(
        style: btnStyle,
        onPressed: () => RequestUtils.onCopyOrMove<LaterItemModel>(
          context: context,
          isCopy: true,
          ctr: controller,
          mediaId: null,
          mid: controller.mid,
        ),
        child: Text('复制', style: textStyle),
      ),
      TextButton(
        style: btnStyle,
        onPressed: () => RequestUtils.onCopyOrMove<LaterItemModel>(
          context: context,
          isCopy: false,
          ctr: controller,
          mediaId: null,
          mid: controller.mid,
        ),
        child: Text('移动', style: textStyle),
      ),
    ];
  }

  @override
  Widget buildList(List<LaterItemModel> list) {
    return SliverGrid.builder(
      gridDelegate: gridDelegate,
      itemBuilder: (context, index) {
        if (index == list.length - 1) {
          controller.onLoadMore();
        }
        final item = list[index];
        return VideoCardHLater(
          index: index,
          videoItem: item,
          ctr: controller,
          onViewLater: (cid) {
            PageUtils.toVideoPage(
              bvid: item.bvid,
              cid: cid,
              cover: item.pic,
              title: item.title,
              dimension: item.dimension,
              extraArguments: {
                'oid': item.aid,
                'sourceType': SourceType.watchLater,
                'count': controller.count,
                'favTitle': '稍后再看',
                'mediaId': controller.mid,
                'desc': false,
                'isContinuePlaying': index != 0,
              },
            );
          },
        );
      },
      itemCount: list.length,
    );
  }
}
