import 'package:PiliBro/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliBro/common/widgets/loading_widget/http_error.dart';
import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/common/widgets/view_sliver_safe_area.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/models_new/sub/sub/list.dart';
import 'package:PiliBro/pages/subscription/controller.dart';
import 'package:PiliBro/pages/subscription/widgets/item.dart';
import 'package:PiliBro/utils/grid.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SubPage extends StatefulWidget {
  const SubPage({super.key});

  @override
  State<SubPage> createState() => _SubPageState();
}

class _SubPageState extends State<SubPage> with GridMixin {
  final SubController _subController = Get.put(SubController());

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(title: const Text('我的订阅')),
      body: refreshIndicator(
        onRefresh: _subController.onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            ViewSliverSafeArea(
              sliver: Obx(
                () => _buildBody(_subController.loadingState.value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(LoadingState<List<SubItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() => gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  if (index == response.length - 1) {
                    _subController.onLoadMore();
                  }
                  final item = response[index];
                  return SubItem(
                    item: item,
                    cancelSub: () => _subController.cancelSub(item),
                  );
                },
                itemCount: response.length,
              )
            : HttpError(onReload: _subController.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _subController.onReload,
      ),
    };
  }
}
