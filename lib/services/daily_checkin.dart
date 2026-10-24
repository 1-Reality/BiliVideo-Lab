import 'package:PiliBro/http/api.dart';
import 'package:PiliBro/http/init.dart';
import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 每日任务里要专门去做的几项，正常使用就有的登录、观看经验不另外做。
/// 当天首次打开：漫画签到与阅读、大会员积分签到；当天第一次上报观看进度成功后：
/// 分享正在看的视频、领大会员每日经验。今天已做过的算成功，只在失败时提示
abstract final class DailyCheckin {
  /// 当天还没分享、没领大会员经验，等第一次观看上报
  static bool watchPending = false;

  static bool get _vip => Pref.userInfoCache?.vipStatus == 1;

  static Options _form([Map<String, String>? headers]) => Options(
    contentType: Headers.formUrlEncodedContentType,
    headers: headers,
    extra: {'account': Accounts.main},
  );

  static void onNewDay() {
    if (!Accounts.main.isLogin) return;
    watchPending = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _report([_manga(), _mangaRead(), if (_vip) _vipPoints()]),
    );
  }

  static void onWatched(Object bvid) {
    watchPending = false;
    _report([_share(bvid), if (_vip) _vipExp()]);
  }

  static Future<void> _report(List<Future<String?>> tasks) async {
    final failed = (await Future.wait(tasks)).nonNulls;
    if (failed.isNotEmpty) SmartDialog.showToast(failed.join('\n'));
  }

  static final _done = RegExp(
    '已签|重复|duplicate|already',
    caseSensitive: false,
  );

  // 返回 null 表示成功或今天已做过，否则是给人看的失败原因
  static String? _check(String name, Response res, [int? doneCode]) {
    final data = res.data;
    final code = data is Map ? data['code'] : null;
    final msg = data is Map ? '${data['message'] ?? data['msg'] ?? ''}' : '';
    if (code == 0 || code == doneCode || msg.contains(_done)) return null;
    return '$name失败：${code ?? ''} $msg';
  }

  static Future<String?> _manga() async => _check(
    '漫画签到',
    await Request().post(
      'https://manga.bilibili.com/twirp/activity.v1.Activity/ClockIn',
      queryParameters: {'platform': 'android'},
      options: _form(),
    ),
  );

  // 直接上报一条阅读记录，漫画与 BiliBiliToolPro 默认用的同一话
  static Future<String?> _mangaRead() async => _check(
    '漫画阅读',
    await Request().post(
      'https://manga.bilibili.com/twirp/bookshelf.v1.Bookshelf/AddHistory',
      queryParameters: {
        'platform': 'android',
        'comic_id': 27355,
        'ep_id': 381662,
      },
      options: _form(),
    ),
  );

  static Future<String?> _vipPoints() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _check(
      '大会员积分签到',
      await Request().post(
        '/pgc/activity/score/task/sign2',
        queryParameters: {
          'mobi_app': 'android',
          'platform': 'android',
          'csrf': Accounts.main.csrf,
        },
        data: {'device': 'phone', 't': now, 'ts': now ~/ 1000},
        options: _form({
          'referer': 'https://big.bilibili.com/mobile/bigPoint/task',
        }),
      ),
    );
  }

  static Future<String?> _share(Object bvid) async => _check(
    '分享视频',
    await Request().post(
      '/x/web-interface/share/add',
      data: {'bvid': bvid, 'csrf': Accounts.main.csrf, 'source': 'web_normal'},
      options: _form(),
    ),
  );

  // 与「我的」页手动领取同一个请求；69198：今天已领过
  static Future<String?> _vipExp() async => _check(
    '大会员每日经验',
    await Request().post(
      Api.vipExpAdd,
      queryParameters: {'mid': Accounts.main.mid, 'csrf': Accounts.main.csrf},
      options: _form(),
    ),
    69198,
  );
}