import 'dart:convert' show utf8;

import 'package:PiliBro/http/video.dart';
import 'package:PiliBro/models/home/rcmd/result.dart';
import 'package:PiliBro/utils/accounts/account.dart';
import 'package:PiliBro/utils/bili_device.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:crypto/crypto.dart' show sha1;

/// 从 App 推荐点开的视频，照官方 App（参考 BBSpace）在打开和离开时各报一次播放，
/// 带上它来自哪张推荐卡。只在这两个时刻发请求，不碰播放过程
class RcmdReport {
  RcmdReport._(this._item, this._account, this._token);

  /// 这张卡来自的那一端账号没有 token，或者匿名取推荐，就不报
  static RcmdReport? of(RcmdVideoItemAppModel item) {
    final identity = VideoHttp.rcmdIdentity(item.cursor.app);
    if (identity == null) return null;
    return RcmdReport._(item, identity.$1, identity.$2);
  }

  static const _fromSpmid = 'tm.recommend.0.0';

  final RcmdVideoItemAppModel _item;
  final LoginAccount _account;
  final String _token;
  final _begin = DateTime.now();
  late final _session = sha1
      .convert(
        utf8.encode(
          '${BiliDevice.buvid}${_begin.millisecondsSinceEpoch}'
          '${Utils.random.nextInt(1 << 30)}',
        ),
      )
      .toString();
  late final int _cid;
  // 开始包的响应里给出的服务器时间，结束包要带回去
  Future<Object?>? _startTs;

  Map<String, dynamic> _params() => {
    'session': _session,
    'mid': _account.mid,
    'aid': _item.aid,
    'cid': _cid,
    'type': 3,
    'sub_type': 0,
    'quality': 0,
    'video_duration': _item.duration,
    'play_type': 1,
    'network_type': 1,
    'play_status': 0,
    'user_status': 0,
    'auto_play': 0,
    'play_mode': 1,
    'is_auto_qn': 1,
    'cur_language': '',
    'oaid': '',
    'from': 7,
    'from_spmid': _fromSpmid,
    'spmid': 'united.player-video-detail.0.0',
    'polaris_action_id': _item.cursor.actionId,
    'extra': '{"from_outer_spmid":"$_fromSpmid"}',
    'track_id': ?_item.trackId,
    'report_flow_data': ?_item.reportFlowData,
  };

  void start(int cid) {
    _cid = cid;
    _startTs = VideoHttp.heartBeatMobile(_item.cursor.app, _account, _token, {
      ..._params(),
      'start_ts': 0,
      'total_time': 0,
      'paused_time': 0,
      'played_time': 0,
      'last_play_progress_time': 0,
      'max_play_progress_time': 0,
      'actual_played_time': 0,
      'list_play_time': 0,
      'miniplayer_play_time': 0,
    }).then(
      (res) => switch (res.data) {
        {'data': {'ts': final ts}} => ts,
        _ => null,
      },
      onError: (_) => null,
    );
  }

  /// [progress] 离开时的播放位置（秒）
  Future<void> end(int progress) async {
    final total = DateTime.now().difference(_begin).inSeconds;
    final played = progress < total ? progress : total;
    VideoHttp.heartBeatMobile(_item.cursor.app, _account, _token, {
      ..._params(),
      'start_ts': await _startTs ?? 0,
      'total_time': total,
      'paused_time': total - played,
      'played_time': played,
      'last_play_progress_time': progress,
      'max_play_progress_time': progress,
      'actual_played_time': played,
      'list_play_time': 0,
      'miniplayer_play_time': 0,
    }).ignore();
  }
}