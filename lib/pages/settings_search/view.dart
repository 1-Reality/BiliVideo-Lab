import 'package:PiliBro/common/widgets/loading_widget/http_error.dart';
import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/common/widgets/view_insets_safe_area.dart';
import 'package:PiliBro/common/widgets/view_sliver_safe_area.dart';
import 'package:PiliBro/pages/search/controller.dart' show DebounceStreamState;
import 'package:PiliBro/pages/setting/models/audio_settings.dart';
import 'package:PiliBro/pages/setting/models/dm_settings.dart';
import 'package:PiliBro/pages/setting/models/dyn_settings.dart';
import 'package:PiliBro/pages/setting/models/extra_settings.dart';
import 'package:PiliBro/pages/setting/models/model.dart';
import 'package:PiliBro/pages/setting/models/play_settings.dart';
import 'package:PiliBro/pages/setting/models/privacy_settings.dart';
import 'package:PiliBro/pages/setting/models/recommend_settings.dart';
import 'package:PiliBro/pages/setting/models/reply_settings.dart';
import 'package:PiliBro/pages/setting/models/style_settings.dart';
import 'package:PiliBro/pages/setting/models/video_settings.dart';
import 'package:PiliBro/utils/grid.dart';
import 'package:PiliBro/utils/waterfall.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SettingsSearchPage extends StatefulWidget {
  const SettingsSearchPage({super.key});

  @override
  State<SettingsSearchPage> createState() => _SettingsSearchPageState();
}

class _SettingsSearchPageState
    extends DebounceStreamState<SettingsSearchPage, String> {
  final _textEditingController = TextEditingController();
  final RxList<SettingsModel> _list = <SettingsModel>[].obs;
  late final _settings = [
    ...extraSettings,
    ...dmSettings,
    ...replySettings,
    ...dynSettings,
    ...privacySettings,
    ...recommendSettings,
    ...videoSettings,
    ...playSettings,
    ...audioSettings,
    NormalModel(
      title: '极高码率 H.264 自动切换 H.265',
      subtitle: 'PC 网络联动状态：画质门限、码率门限',
      onTap: (context, setState) => Get.toNamed('/networkPolicy'),
    ),
    ...styleSettings,
  ];

  @override
  void onValueChanged(String value) {
    if (value.isEmpty) {
      _list.clear();
    } else {
      value = value.toLowerCase();
      _list.value = _settings
          .where(
            (item) =>
                item.effectiveTitle.toLowerCase().contains(value) ||
                item.effectiveSubtitle?.toLowerCase().contains(value) == true,
          )
          .toList();
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              if (_textEditingController.text.isNotEmpty) {
                _textEditingController.clear();
                _list.clear();
              } else {
                Get.back();
              }
            },
            icon: const Icon(Icons.clear),
          ),
          const SizedBox(width: 10),
        ],
        title: TextField(
          autofocus: true,
          controller: _textEditingController,
          textAlignVertical: TextAlignVertical.center,
          onChanged: ctr!.add,
          decoration: const InputDecoration(
            isDense: true,
            hintText: '搜索',
            visualDensity: .standard,
            border: InputBorder.none,
          ),
        ),
      ),
      body: ViewInsetsSafeArea(
        child: CustomScrollView(
          slivers: [
            ViewSliverSafeArea(
              sliver: Obx(
                () => _list.isEmpty
                    ? const HttpError()
                    : SliverMasonryGrid(
                        gridDelegate: gridDelegate,
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _list[index].widget,
                          childCount: _list.length,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  late final gridDelegate = SliverSimpleGridDelegateWithMaxCrossAxisExtent_(
    maxCrossAxisExtent: Grid.smallCardWidth * 2,
  );
}
