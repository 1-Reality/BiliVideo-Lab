import 'package:PiliBro/common/constants.dart';
import 'package:PiliBro/common/dial_prefix.dart';
import 'package:PiliBro/common/widgets/loading_widget/http_error.dart';
import 'package:PiliBro/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliBro/common/widgets/view_insets_safe_area.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/pages/login/controller.dart';
import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/extension/size_ext.dart';
import 'package:PiliBro/utils/extension/widget_ext.dart';
import 'package:PiliBro/utils/image_utils.dart';
import 'package:PiliBro/utils/page_utils.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:url_launcher/url_launcher.dart';

final _noWhitespaceFormatters = [
  FilteringTextInputFormatter.deny(RegExp(r'\s')),
];

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialIndex = 1});

  final int initialIndex;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final LoginPageController _loginPageCtr;
  // 二维码生成时间
  bool showPassword = false;
  GlobalKey globalKey = GlobalKey();
  // 还没有任何账号时先挑推荐口味，挑完再进登录方式
  late bool _choosing = !Accounts.main.isLogin;

  void _pick(LoginPlan plan) {
    LoginPageController.plan = plan;
    // 手机 token 只有短信登录给得了；平板直接扫码，拿到的就是平板 token
    _loginPageCtr.tabController.index = plan == LoginPlan.hd ? 2 : 1;
    setState(() => _choosing = false);
  }

  Widget _planChooser(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    Widget card(
      LoginPlan plan,
      IconData icon,
      String title,
      String desc, {
      String? badge,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: badge == null
            ? colorScheme.surfaceContainerLow
            : colorScheme.primaryContainer.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: badge == null
              ? BorderSide.none
              : BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _pick(plan),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: badge == null
                        ? colorScheme.secondaryContainer
                        : colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: badge == null
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
    return SingleChildScrollView(
      padding: padding + const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '先挑个推荐口味',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '决定首页给你推什么，也决定接下来用哪种方式登录。挑错了也没关系，设置里随时能改。',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          card(
            LoginPlan.phone,
            Icons.phone_android_outlined,
            '安卓 App 模式',
            '和原版手机 App 最像，推荐更个性化，越刷越懂你',
          ),
          card(
            LoginPlan.hd,
            Icons.tablet_android_outlined,
            '平板 HD 模式',
            '平板版自己的推荐池，和手机、网页都不太一样，常有新鲜内容',
          ),
          card(
            LoginPlan.all,
            Icons.auto_awesome_outlined,
            '我全都要',
            '手机和平板的推荐混着刷，评论区的属地和回复关系也一次配齐',
            badge: '省心',
          ),
          card(
            LoginPlan.any,
            Icons.tune_outlined,
            '万能模式',
            '先按手机推荐来，以后想换哪种、想怎么混，都在设置里自己调',
          ),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _choosing = false),
              child: Text(
                '跳过，直接登录',
                style: TextStyle(color: colorScheme.outline),
              ),
            ),
          ),
        ],
      ),
    ).constraintWidth();
  }

  @override
  void initState() {
    super.initState();
    _loginPageCtr = Get.put(
      LoginPageController(initialIndex: widget.initialIndex),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loginPageCtr.didChangeDependencies(context);
  }

  Widget loginByQRCode(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text('使用 bilibili 官方 App 扫码登录'),
        const SizedBox(height: 20),
        Obx(
          () => Text(
            '剩余有效时间: ${_loginPageCtr.qrCodeLeftTime} 秒',
            style: TextStyle(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: theme.colorScheme.primaryFixedDim,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              autofocus: widget.initialIndex == 2,
              onPressed: _loginPageCtr.refreshQRCode,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新二维码'),
            ),
            TextButton.icon(
              onPressed: () async {
                SmartDialog.showLoading(msg: '正在生成截图');
                final boundary =
                    globalKey.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 3);
                final byteData = await image.toByteData(format: .png);
                final pngBytes = byteData!.buffer.asUint8List();
                image.dispose();
                SmartDialog.dismiss();
                final picName =
                    "${Constants.appName}_loginQRCode_${_loginPageCtr.codeInfo.value.data.authCode.hashCode.toUnsigned(32).toRadixString(16)}";
                ImageUtils.saveByteImg(bytes: pngBytes, fileName: picName);
              },
              icon: const Icon(Icons.save),
              label: const Text('保存至相册'),
            ),
            if (kDebugMode || PlatformUtils.isMobile)
              TextButton.icon(
                onPressed: () => PageUtils.launchURL(
                  'bilibili://browser?url=${Uri.encodeComponent(_loginPageCtr.codeInfo.value.data.url)}',
                  mode: LaunchMode.externalNonBrowserApplication,
                ),
                icon: const Icon(Icons.open_in_browser_outlined),
                label: const Text('其他应用打开'),
              ),
          ],
        ),
        RepaintBoundary(
          key: globalKey,
          child: Obx(
            () => switch (_loginPageCtr.codeInfo.value) {
              Loading() => const SizedBox(
                height: 200,
                width: 200,
                child: m3eLoading,
              ),
              Success(:final response) => Container(
                width: 200,
                height: 200,
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: PrettyQrView.data(
                  data: response.url,
                  decoration: const PrettyQrDecoration(
                    shape: PrettyQrSquaresSymbol(
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              Error(:final errMsg) => HttpError(
                isSliver: false,
                errMsg: errMsg,
                onReload: _loginPageCtr.refreshQRCode,
              ),
            },
          ),
        ),
        const SizedBox(height: 10),
        Obx(
          () => Text(
            _loginPageCtr.statusQRCode.value,
            style: TextStyle(color: theme.colorScheme.secondaryFixedDim),
          ),
        ),
        Obx(
          () {
            final url = _loginPageCtr.codeInfo.value.dataOrNull?.url ?? '';
            return GestureDetector(
              onTap: () => Utils.copyText(
                url,
                toastText: '已复制到剪贴板，可粘贴至已登录的app私信处发送，然后点击已发送的链接打开',
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Text(
                  url,
                  style: theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '请务必在 ${Constants.appName} 开源仓库等可信渠道下载安装。',
            style: theme.textTheme.labelSmall!.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget loginByCookie(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        const Text('使用Cookie登录'),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '使用App端Api实现的功能将不可用',
            style: theme.textTheme.labelMedium!.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: TextField(
            minLines: 1,
            maxLines: 10,
            controller: _loginPageCtr.cookieTextController,
            inputFormatters: _noWhitespaceFormatters,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.cookie_outlined),
              border: const UnderlineInputBorder(),
              labelText: 'Cookie',
              suffixIcon: IconButton(
                onPressed: _loginPageCtr.cookieTextController.clear,
                icon: const Icon(Icons.clear),
              ),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _loginPageCtr.loginByCookie,
          icon: const Icon(Icons.login),
          label: const Text('登录'),
        ),
      ],
    );
  }

  Widget loginByPassword(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text('使用账号密码登录'),
        const SizedBox(height: 20),
        Padding(
          padding: const .symmetric(horizontal: 20),
          child: AutofillGroup(
            child: Column(
              spacing: 10,
              children: [
                TextField(
                  controller: _loginPageCtr.usernameTextController,
                  autofillHints: const [
                    AutofillHints.telephoneNumber,
                    AutofillHints.email,
                  ],
                  inputFormatters: _noWhitespaceFormatters,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.account_box),
                    border: const UnderlineInputBorder(),
                    labelText: '账号',
                    hintText: '邮箱/手机号',
                    suffixIcon: IconButton(
                      onPressed: _loginPageCtr.usernameTextController.clear,
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                ),
                TextField(
                  obscureText: !showPassword,
                  keyboardType: TextInputType.visiblePassword,
                  inputFormatters: _noWhitespaceFormatters,
                  controller: _loginPageCtr.passwordTextController,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.password),
                    border: const UnderlineInputBorder(),
                    labelText: '密码',
                    suffixIcon: IconButton(
                      onPressed: _loginPageCtr.passwordTextController.clear,
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            const SizedBox(width: 10),
            Checkbox(
              value: showPassword,
              onChanged: (value) => setState(() => showPassword = value!),
            ),
            const Text('显示密码'),
            const Spacer(),
            TextButton(
              onPressed: () {
                //https://passport.bilibili.com/h5-app/passport/login/findPassword
                //https://passport.bilibili.com/passport/findPassword
                showDialog(
                  context: context,
                  builder: (context) => SimpleDialog(
                    clipBehavior: Clip.hardEdge,
                    title: const Text('忘记密码？'),
                    contentPadding: const .only(top: 2, bottom: 16),
                    children: [
                      const Padding(
                        padding: .fromLTRB(25, 0, 25, 10),
                        child: Text("试试扫码、手机号登录，或选择"),
                      ),
                      ListTile(
                        title: const Text(
                          '找回密码（手机版）',
                        ),
                        leading: const Icon(Icons.smartphone_outlined),
                        subtitle: const Text(
                          'https://passport.bilibili.com/h5-app/passport/login/findPassword',
                        ),
                        dense: false,
                        onTap: () => Get
                          ..back()
                          ..toNamed(
                            '/webview',
                            parameters: {
                              'url': 'https://passport.bilibili.com/h5-app/passport/login/findPassword',
                              'type': 'url',
                              'pageTitle': '忘记密码',
                            },
                          ),
                      ),
                      ListTile(
                        title: const Text('找回密码（电脑版）'),
                        leading: const Icon(Icons.desktop_windows_outlined),
                        subtitle: const Text(
                          'https://passport.bilibili.com/pc/passport/findPassword',
                        ),
                        dense: false,
                        onTap: () => Get
                          ..back()
                          ..toNamed(
                            '/webview',
                            parameters: {
                              'url': 'https://passport.bilibili.com/pc/passport/findPassword',
                              'type': 'url',
                              'pageTitle': '忘记密码',
                              'uaType': 'pc',
                            },
                          ),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('忘记密码'),
            ),
            const SizedBox(width: 20),
          ],
        ),
        OutlinedButton.icon(
          onPressed: _loginPageCtr.loginByPassword,
          icon: const Icon(Icons.login),
          label: const Text('登录'),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '根据 bilibili 官方登录接口规范，密码将在本地加盐、加密后传输。\n'
            '盐与公钥均由官方提供；以 RSA/ECB/PKCS1Padding 方式加密。\n'
            '账号密码仅用于该登录接口，不予保存；本地仅存储登录凭证。\n'
            '请务必在 ${Constants.appName} 开源仓库等可信渠道下载安装。',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall!.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget loginBySmS(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text('使用手机短信验证码登录'),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: DecoratedBox(
            decoration: UnderlineTabIndicator(
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Builder(
                  builder: (context) {
                    return PopupMenuButton(
                      padding: EdgeInsets.zero,
                      tooltip:
                          '选择国际冠码，'
                          '当前为${_loginPageCtr.selectedCountryCodeId.cname}，'
                          '+${_loginPageCtr.selectedCountryCodeId.countryId}',
                      onSelected: (item) {
                        _loginPageCtr.selectedCountryCodeId = item;
                        (context as Element).markNeedsBuild();
                      },
                      initialValue: _loginPageCtr.selectedCountryCodeId,
                      itemBuilder: (_) => Login.dialPrefix.map((item) {
                        return PopupMenuItem(
                          value: item,
                          child: Row(
                            children: [
                              Text(item.cname),
                              const Spacer(),
                              Text("+${item.countryId}"),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "+${_loginPageCtr.selectedCountryCodeId.countryId}",
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 24,
                  child: VerticalDivider(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _loginPageCtr.telTextController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      labelText: '手机号',
                      suffixIcon: IconButton(
                        onPressed: _loginPageCtr.telTextController.clear,
                        icon: const Icon(Icons.clear),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: DecoratedBox(
            decoration: UnderlineTabIndicator(
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _loginPageCtr.smsCodeTextController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.sms_outlined),
                      border: InputBorder.none,
                      labelText: '验证码',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
                Obx(
                  () => TextButton.icon(
                    onPressed: _loginPageCtr.smsSendCooldown > 0
                        ? null
                        : _loginPageCtr.sendSmsCode,
                    icon: const Icon(Icons.send),
                    label: Text(
                      _loginPageCtr.smsSendCooldown > 0
                          ? '等待${_loginPageCtr.smsSendCooldown}秒'
                          : '获取验证码',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _loginPageCtr.loginBySmsCode,
          icon: const Icon(Icons.login),
          label: const Text('登录'),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '手机号仅用于 bilibili 官方发送验证码与登录接口，不予保存；\n'
            '本地仅存储登录凭证。\n'
            '请务必在 ${Constants.appName} 开源仓库等可信渠道下载安装。',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall!.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  late EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    padding =
        MediaQuery.viewPaddingOf(context).copyWith(top: 0) +
        const EdgeInsets.only(bottom: 25);
    final isLandscape = !MediaQuery.sizeOf(context).isPortrait;
    return SimpleScaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '关闭',
          icon: const Icon(Icons.close_outlined),
          onPressed: Get.back,
        ),
        title: Row(
          children: [
            const Text('登录'),
            if (isLandscape && !_choosing)
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TabBar(
                    isScrollable: true,
                    dividerHeight: 0,
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(Icons.password), Text(' 密码')],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(Icons.sms_outlined), Text(' 短信')],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(Icons.qr_code), Text(' 扫码')],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cookie_outlined),
                            Text(' Cookie'),
                          ],
                        ),
                      ),
                    ],
                    controller: _loginPageCtr.tabController,
                  ),
                ),
              ),
          ],
        ),
      ),
      body: _choosing
          ? _planChooser(theme)
          : Column(
        children: [
          if (!isLandscape)
            TabBar(
              tabs: const [
                Tab(icon: Icon(Icons.password), text: '密码'),
                Tab(icon: Icon(Icons.sms_outlined), text: '短信'),
                Tab(icon: Icon(Icons.qr_code), text: '扫码'),
                Tab(icon: Icon(Icons.cookie_outlined), text: 'Cookie'),
              ],
              controller: _loginPageCtr.tabController,
            ),
          Expanded(
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis == Axis.horizontal) {
                  FocusScope.of(context).unfocus();
                }
                return false;
              },
              child: ViewInsetsSafeArea(
                child: tabBarView(
                  controller: _loginPageCtr.tabController,
                  children: [
                    tabViewOuter(loginByPassword(theme)),
                    tabViewOuter(loginBySmS(theme)),
                    tabViewOuter(loginByQRCode(theme)),
                    tabViewOuter(loginByCookie(theme)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget tabViewOuter(Widget child) {
    return SingleChildScrollView(
      padding: padding,
      child: child.constraintWidth(),
    );
  }
}
