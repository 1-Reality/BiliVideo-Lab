import 'package:PiliBro/common/widgets/image/network_img_layer.dart';
import 'package:PiliBro/models/search/search_esports.dart';
import 'package:PiliBro/pages/match_info/widgets/match_info_item.dart';
import 'package:PiliBro/utils/app_scheme.dart';
import 'package:PiliBro/utils/date_utils.dart';
import 'package:PiliBro/utils/page_utils.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:material_ui/material_ui.dart';

class SearchEsportsItem extends StatelessWidget {
  const SearchEsportsItem({
    super.key,
    required this.item,
  });

  final SearchEsports item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final contest = item.contest.first;
    return Padding(
      padding: const .symmetric(vertical: 5),
      child: Center(
        child: GestureDetector(
          behavior: .opaque,
          onTap: () => Get.toNamed(
            '/matchInfo',
            parameters: {'cid': contest.id.toString()},
          ),
          child: buildContestItem(colorScheme, contest),
        ),
      ),
    );
  }
}
