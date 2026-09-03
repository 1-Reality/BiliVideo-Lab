import 'dart:math';

import 'package:PiliBro/models/common/search/article_search_type.dart';
import 'package:PiliBro/models/search/result.dart';
import 'package:PiliBro/pages/search/widgets/search_text.dart';
import 'package:PiliBro/pages/search_panel/controller.dart';
import 'package:PiliBro/utils/extension/context_ext.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

class SearchArticleController
    extends SearchPanelController<SearchArticleData, SearchArticleItemModel> {
  static final _articleIdRegExp = RegExp(
    r'^cv(id)?(\d+)',
    caseSensitive: false,
  );

  SearchArticleController({
    required super.keyword,
    required super.searchType,
    required super.tag,
  });

  @override
  void onInit() {
    super.onInit();
    articleZoneType = ArticleZoneType.all.obs;
    jump2Article();
  }

  void jump2Article() {
    final match = _articleIdRegExp.matchAsPrefix(keyword);
    final cvid = match?.end == keyword.length ? match?.group(2) : null;
    if (cvid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.toNamed(
          '/articlePage',
          parameters: {
            'id': cvid,
            'type': 'read',
          },
        );
      });
    }
  }

  Rx<ArticleOrderType> articleOrderType = ArticleOrderType.totalrank.obs;

  void onShowFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: min(640, context.mediaQueryShortestSide),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            top: 20,
            left: 16,
            right: 16,
            bottom: 100 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Text('排序', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ArticleOrderType.values.map(
                  (e) {
                    final isCurr = e == articleOrderType.value;
                    return SearchText(
                      text: e.label,
                      onTap: (_) {
                        articleOrderType.value = e;
                        order = e.order;
                        onSortSearch(label: e.label);
                      },
                      bgColor: isCurr
                          ? theme.colorScheme.secondaryContainer
                          : null,
                      textColor: isCurr
                          ? theme.colorScheme.onSecondaryContainer
                          : null,
                    );
                  },
                ).toList(),
              ),
              const SizedBox(height: 20),
              const Text('分区', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ArticleZoneType.values.map(
                  (e) {
                    final isCurr = e == articleZoneType!.value;
                    return SearchText(
                      text: e.label,
                      onTap: (_) {
                        articleZoneType!.value = e;
                        onSortSearch(label: e.label);
                      },
                      bgColor: isCurr
                          ? theme.colorScheme.secondaryContainer
                          : null,
                      textColor: isCurr
                          ? theme.colorScheme.onSecondaryContainer
                          : null,
                    );
                  },
                ).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
