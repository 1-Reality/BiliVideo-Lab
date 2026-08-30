import 'package:PiliBro/common/widgets/scroll_physics.dart' show ReloadMixin;
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/video.dart';
import 'package:PiliBro/models/model_hot_video_item.dart';
import 'package:PiliBro/models_new/popular/popular_series_list/list.dart';
import 'package:PiliBro/models_new/popular/popular_series_one/config.dart';
import 'package:PiliBro/models_new/popular/popular_series_one/data.dart';
import 'package:PiliBro/pages/common/common_list_controller.dart';
import 'package:PiliBro/utils/extension/iterable_ext.dart';
import 'package:get/get.dart';

class PopularSeriesController
    extends CommonListController<PopularSeriesOneData, HotVideoItemModel>
    with ReloadMixin {
  late int number;

  final config = Rxn<PopularSeriesConfig>();
  String? reminder;
  List<PopularSeriesListItem>? seriesList;

  @override
  void onInit() {
    super.onInit();
    _getSeriesList();
  }

  Future<void> _getSeriesList() async {
    final res = await VideoHttp.popularSeriesList();
    if (res case Success(:final response)) {
      if (response != null && response.isNotEmpty) {
        number = response.first.number!;
        seriesList = response;
        queryData();
      } else {
        loadingState.value = const Success(null);
      }
    } else {
      loadingState.value = res as Error;
    }
  }

  @override
  List<HotVideoItemModel>? getDataList(PopularSeriesOneData response) {
    config.value = response.config;
    reminder = response.reminder;
    return response.list;
  }

  @override
  Future<LoadingState<PopularSeriesOneData>> customGetData() =>
      VideoHttp.popularSeriesOne(number: number);

  @override
  Future<void> onReload() {
    if (seriesList.isNullOrEmpty) {
      return _getSeriesList();
    }
    reload = true;
    return super.onReload();
  }
}
