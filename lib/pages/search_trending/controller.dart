import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/search.dart';
import 'package:PiliBro/models_new/search/search_trending/data.dart';
import 'package:PiliBro/models_new/search/search_trending/list.dart';
import 'package:PiliBro/pages/common/common_list_controller.dart';

class SearchTrendingController
    extends CommonListController<SearchTrendingData, SearchTrendingItemModel> {
  int topCount = 0;

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  List<SearchTrendingItemModel>? getDataList(SearchTrendingData response) {
    topCount = response.topCount;
    return response.list;
  }

  @override
  Future<LoadingState<SearchTrendingData>> customGetData() =>
      SearchHttp.searchTrending(needsTop: true);
}
