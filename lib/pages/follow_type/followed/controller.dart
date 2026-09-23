import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/user.dart';
import 'package:PiliBro/models_new/follow/data.dart';
import 'package:PiliBro/pages/follow_type/controller.dart';

class FollowedController extends FollowTypeController {
  @override
  Future<LoadingState<FollowData>> customGetData() =>
      UserHttp.followedUp(mid: mid, pn: page);
}
