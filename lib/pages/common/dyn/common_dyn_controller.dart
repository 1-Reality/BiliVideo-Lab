import 'package:PiliBro/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliBro/grpc/reply.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/models_new/dynamic/dyn_mention/item.dart';
import 'package:PiliBro/pages/common/reply/fold/reply_fold_mixin.dart';
import 'package:PiliBro/pages/common/reply/reply_controller.dart';
import 'package:PiliBro/pages/common/reply/vote/reply_vote_mixin.dart';
import 'package:PiliBro/utils/reply_scheme_helper.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:get/get.dart';

mixin DynReplyLocateMixin on MainReplyLocateMixin {
  int? targetSecondRpId; // jump

  @override
  void onAnimRootReply(ReplyInfo rootReply) {
    if (args[secondRpIdKey] case final int secondRpId) {
      args.remove(rootRpIdKey);
      targetRootRpId = rootRpId;
      targetSecondRpId = secondRpId;
    } else {
      super.onAnimRootReply(rootReply);
    }
  }
}

abstract class CommonDynController extends ReplyController<MainListReply>
    with ReplyVoteMixin, BaseReplyFoldMixin<MainListReply>, ReplyFoldMixin {
  CommonDynController({super.count});

  MentionItem? get mentionItem => null;

  late final RxBool showTitle = false.obs;

  late final horizontalPreview = Pref.horizontalPreview;
  late final List<double> ratio = Pref.dynamicDetailRatio;

  late final showDynActionBar = Pref.showDynActionBar;

  @override
  Future<LoadingState<MainListReply>> customGetData() => ReplyGrpc.mainList(
    type: replyType,
    oid: oid,
    rpid: rootRpId,
    mode: mode,
    cursorNext: cursorNext,
    offset: paginationReply?.nextOffset,
  );
}
