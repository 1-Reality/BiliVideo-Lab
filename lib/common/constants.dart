abstract final class Constants {
  static const appName = 'PiliBro';
  static const sourceCodeUrl = 'https://github.com/ucxn/Bili.Libre.Speed';
  static const sourceBranch = 'dev';
  static const sourceBranchUrl = '$sourceCodeUrl/tree/$sourceBranch';

  static const baseHeaders = {
    // 'referer': HttpString.baseUrl,
    'env': 'prod',
    'app-key': 'android64',
    'x-bili-aurora-zone': 'sh001',
  };

  static final urlRegex = RegExp(
    r'https?://[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]',
  );

  static const goodsUrlPrefix = "https://gaoneng.bilibili.com/tetris";

  // 'itemOpusStyle,opusBigCover,onlyfansVote,endFooterHidden,decorationCard,onlyfansAssetsV2,ugcDelete,onlyfansQaCard,editable,opusPrivateVisible,avatarAutoTheme,sunflowerStyle,cardsEnhance,eva3CardOpus,eva3CardVideo,eva3CardComment,eva3CardVote,eva3CardUser'
  static const dynFeatures = 'itemOpusStyle,listOnlyfans,onlyfansQaCard';
}
