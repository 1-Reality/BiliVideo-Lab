import 'package:PiliBro/models/model_video.dart';
import 'package:PiliBro/utils/storage_pref.dart';

abstract final class RecommendFilter {
  static int minDurationForRcmd = Pref.minDurationForRcmd;
  static int minPlayForRcmd = Pref.minPlayForRcmd;
  static int minLikeRatioForRecommend = Pref.minLikeRatioForRecommend;
  static bool exemptFilterForFollowed = Pref.exemptFilterForFollowed;
  static RegExp rcmdRegExp = RegExp(
    Pref.banWordForRecommend,
    caseSensitive: false,
  );
  static bool enableFilter = rcmdRegExp.pattern.isNotEmpty;

  /// 生效范围，位义见 RcmdFilterScope；各项阈值都是 0 且没有关键词时直接为 0，
  /// 调用处一次比较就跳过。任一过滤设置改动后调 [compile]
  static int scope = _scope();

  static int _scope() =>
      minDurationForRcmd == 0 &&
          minPlayForRcmd == 0 &&
          minLikeRatioForRecommend == 0 &&
          !enableFilter
      ? 0
      : Pref.rcmdFilterScope.index;

  static void compile() => scope = _scope();

  /// 首页推荐
  static bool filter(BaseVideoItemModel videoItem) {
    return scope & 1 != 0 &&
        !(videoItem.isFollowed && exemptFilterForFollowed) &&
        filterAll(videoItem);
  }

  /// 热门、排行：直接看原始数据
  static bool filterHot(String title, int? like, int? view) {
    return scope & 1 != 0 &&
        (filterTitle(title) || filterLikeRatio(like, view));
  }

  static bool filterLikeRatio(int? like, int? view) {
    return view != null &&
        ((view > -1 && view < minPlayForRcmd) ||
            (like != null &&
                like > -1 &&
                like * 100 < minLikeRatioForRecommend * view));
  }

  static bool filterTitle(String title) {
    return enableFilter && rcmdRegExp.hasMatch(title);
  }

  static bool filterAll(BaseVideoItemModel videoItem) {
    return (videoItem.duration > 0 &&
            videoItem.duration < minDurationForRcmd) ||
        filterLikeRatio(videoItem.stat.like, videoItem.stat.view) ||
        filterTitle(videoItem.title);
  }
}
