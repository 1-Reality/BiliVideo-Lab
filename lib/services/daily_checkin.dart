import 'package:PiliBro/http/api.dart';
import 'package:PiliBro/http/constants.dart';
import 'package:PiliBro/http/init.dart';
import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 每日任务里要专门去做的几项，正常使用就有的登录、观看经验不另外做。
/// 当天首次打开时一起发：漫画签到与阅读、分享视频、大会员积分签到与每日经验（大会员）、
/// 银瓜子换硬币（开关）。今天已做过的算成功；全部成功提示一次，有失败就列出失败项
abstract final class DailyCheckin {
  static bool get _vip => Pref.userInfoCache?.vipStatus == 1;

  static Options _form([Map<String, String>? headers]) => Options(
    contentType: Headers.formUrlEncodedContentType,
    headers: headers,
    extra: {'account': Accounts.main},
  );

  // 漫画阅读按今年第几天打开轮流读的漫画与它的第一话，共 8 本
  static const _comics = [
    (28616, 492793),
    (29665, 570343),
    (28455, 529969),
    (28509, 485290),
    (27652, 401045),
    (26985, 359465),
    (26405, 366704),
    (28390, 481060),
  ];

  static void onNewDay(int day) {
    if (!Accounts.main.isLogin) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _report([
        _manga(),
        _mangaRead(_comics[day & 7]),
        _share(),
        if (_vip) ...[_vipPoints(), _vipExp()],
        if (Pref.silver2coin) _silver2coin(),
      ]),
    );
  }

  static Future<void> _report(List<Future<String?>> tasks) async {
    final failed = (await Future.wait(tasks)).nonNulls;
    SmartDialog.showToast(
      failed.isEmpty ? '今日签到全部完成，经验已到账' : failed.join('\n'),
    );
  }

  static final _done = RegExp(
    '已签|重复|duplicate|already|余额不足',
    caseSensitive: false,
  );

  // 返回 null 表示成功或今天已做过，否则是给人看的失败原因
  static String? _check(String name, Response res, [int? doneCode]) {
    final data = res.data;
    final code = data is Map ? data['code'] : null;
    final msg = data is Map ? '${data['message'] ?? data['msg'] ?? ''}' : '';
    if (code == 0 || (doneCode != null && code == doneCode) || msg.contains(_done)) {
      return null;
    }
    return '$name失败：${code ?? ''} $msg';
  }

  static Future<String?> _manga() async => _check(
    '漫画签到',
    await Request().post(
      'https://manga.bilibili.com/twirp/activity.v1.Activity/ClockIn',
      queryParameters: {'platform': 'android'},
      options: _form()
        ..validateStatus = (status) =>
            status != null && (status >= 200 && status < 300 || status == 400),
    ),
  );

  // 直接上报一条阅读记录
  static Future<String?> _mangaRead((int, int) comic) async => _check(
    '漫画阅读',
    await Request().post(
      'https://manga.bilibili.com/twirp/bookshelf.v1.Bookshelf/AddHistory',
      queryParameters: {
        'platform': 'android',
        'comic_id': comic.$1,
        'ep_id': comic.$2,
      },
      options: _form(),
    ),
  );

  static Future<String?> _silver2coin() async => _check(
    '银瓜子换硬币',
    await Request().post(
      '${HttpString.liveBaseUrl}/xlive/revenue/v1/wallet/silver2coin',
      data: {'csrf': Accounts.main.csrf, 'csrf_token': Accounts.main.csrf},
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

  static Future<String?> _share() async => _check(
    '分享视频',
    await Request().post(
      '/x/web-interface/share/add',
      data: {'bvid': 'BV1PtR7B8ECC', 'csrf': Accounts.main.csrf, 'source': 'web_normal'},
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