import 'dart:async';
import 'dart:io' show Platform;

import 'package:PiliBro/common/assets.dart';
import 'package:PiliBro/common/style.dart';
import 'package:PiliBro/common/widgets/custom_icon.dart';
import 'package:PiliBro/common/widgets/flutter/list_tile.dart';
import 'package:PiliBro/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliBro/common/widgets/image/network_img_layer.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/user.dart';
import 'package:PiliBro/models/common/nav_bar_config.dart';
import 'package:PiliBro/models_new/fav/fav_folder/list.dart';
import 'package:PiliBro/pages/coin_log/controller.dart';
import 'package:PiliBro/pages/common/common_page.dart';
import 'package:PiliBro/pages/exp_log/controller.dart';
import 'package:PiliBro/pages/home/view.dart';
import 'package:PiliBro/pages/log_table/view.dart';
import 'package:PiliBro/pages/login/controller.dart';
import 'package:PiliBro/pages/login_devices/view.dart';
import 'package:PiliBro/pages/login_log/controller.dart';
import 'package:PiliBro/pages/main/controller.dart';
import 'package:PiliBro/pages/mine/controller.dart';
import 'package:PiliBro/pages/mine/widgets/item.dart';
import 'package:PiliBro/utils/android/android_helper.dart';
import 'package:PiliBro/utils/bili_utils.dart';
import 'package:PiliBro/utils/cache_manager.dart';
import 'package:PiliBro/utils/extension/get_ext.dart';
import 'package:PiliBro/utils/extension/num_ext.dart';
import 'package:PiliBro/utils/extension/string_ext.dart';
import 'package:PiliBro/utils/extension/theme_ext.dart';
import 'package:PiliBro/utils/page_utils.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/share_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class MinePage extends StatefulWidget {
  const MinePage({super.key, this.showBackBtn = false});

  final bool showBackBtn;

  @override
  State<MinePage> createState() => _MediaPageState();
}

class _MediaPageState extends CommonPageState<MinePage>
    with AutomaticKeepAliveClientMixin {
  final MineController controller = Get.putOrFind(MineController.new);
  late final MainController _mainController = Get.find<MainController>();

  @override
  bool get wantKeepAlive => true;

  bool get checkPage =>
      _mainController.navigationBars[0] != NavigationBarType.mine &&
      _mainController.selectedIndex.value == 0;

  @override
  bool onNotificationType1(UserScrollNotification notification) =>
      !checkPage && super.onNotificationType1(notification);

  @override
  bool onNotificationType2(ScrollNotification notification) =>
      !checkPage && super.onNotificationType2(notification);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    return Column(
      children: [
        Padding(
          padding: const .symmetric(vertical: 10),
          child: _buildHeaderActions,
        ),
        Expanded(
          child: Material(
            type: .transparency,
            child: refreshIndicator(
              onRefresh: controller.onRefresh,
              child: onBuild(
                ListView(
                  padding: const .only(bottom: 100),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildUserInfo(theme, secondary),
                    _buildActions(secondary),
                    _buildQuickActions(secondary),
                    Obx(
                      () => controller.loadingState.value is Loading
                          ? const SizedBox.shrink()
                          : _buildFav(theme, secondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionBody(Widget icon, String title) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 80),
    child: AspectRatio(
      aspectRatio: 1,
      child: Column(
        spacing: 6,
        mainAxisSize: .min,
        mainAxisAlignment: .center,
        children: [
          icon,
          Text(title, style: const TextStyle(fontSize: 13)),
        ],
      ),
    ),
  );

  Widget _actionButton({
    required Widget icon,
    required String title,
    required VoidCallback onTap,
  }) => Flexible(
    child: InkWell(
      onTap: onTap,
      borderRadius: Style.mdRadius,
      child: _actionBody(icon, title),
    ),
  );

  Widget _buildActions(Color primary) => Row(
    mainAxisAlignment: .spaceEvenly,
    children: controller.list
        .map(
          (e) => _actionButton(
            icon: Icon(e.icon, color: primary),
            title: e.title,
            onTap: e.onTap,
          ),
        )
        .toList(),
  );

  Widget _buildQuickActions(Color primary) => Row(
    mainAxisAlignment: .spaceEvenly,
    children: [
      _actionButton(
        icon: Icon(MdiIcons.cloudOutline, color: primary),
        title: 'CDN设置',
        onTap: () => Get.toNamed('/cdnSettings'),
      ),
      _actionButton(
        icon: Icon(Icons.lan_outlined, color: primary),
        title: '智能网优',
        onTap: () => Get.toNamed('/networkPolicy'),
      ),
      _actionButton(
        icon: Icon(Icons.screen_rotation_outlined, color: primary),
        title: '屏幕旋转',
        onTap: () => Get.toNamed('/orientationSettings'),
      ),
      Flexible(
        child: PopupMenuButton<void>(
          tooltip: '创作中心',
          itemBuilder: (_) => _creatorMenuItems(),
          child: _actionBody(
            SvgPicture.asset(
              'assets/images/creator_center.svg',
              width: 24,
              height: 24,
            ),
            '创作中心',
          ),
        ),
      ),
    ],
  );

  PopupMenuItem<void> _creatorMenuItem(
    Widget icon,
    String title,
    VoidCallback onTap,
  ) => PopupMenuItem<void>(
    onTap: onTap,
    child: Row(
      mainAxisSize: .min,
      children: [
        SizedBox(width: 24, child: Center(child: icon)),
        const SizedBox(width: 10),
        Text(title),
      ],
    ),
  );

  List<PopupMenuEntry<void>> _creatorMenuItems() {
    final userInfo = controller.userInfo.value;
    final mid = userInfo.mid;
    final loggedIn = controller.accountService.isLogin.value;
    return [
      if (mid != null)
        _creatorMenuItem(
          const Icon(Icons.share_outlined, size: 19),
          '分享我的主页',
          _shareHomepage,
        ),
      if (PlatformUtils.isMobile && mid != null)
        _creatorMenuItem(
          const Icon(Icons.add_box_outlined, size: 19),
          '添加至桌面',
          _createShortcut,
        ),
      if (loggedIn) ...[
        _creatorMenuItem(
          const Icon(Icons.create_outlined, size: 19),
          '创作中心',
          () => _openInternalWeb(
            'https://member.bilibili.com/platform/home',
          ),
        ),
        if ((userInfo.vipStatus ?? 0) > 0)
          _creatorMenuItem(
            const Icon(Icons.upcoming_outlined, size: 19),
            '大会员经验',
            () => unawaited(_vipExpAdd()),
          ),
        _creatorMenuItem(
          const Icon(Icons.devices, size: 18),
          '登录设备',
          () => Get.to(const LoginDevicesPage()),
        ),
        _creatorMenuItem(
          const Icon(Icons.login, size: 18),
          '登录记录',
          () => Get.to(
            const LogPage(),
            arguments: LoginLogController(),
          ),
        ),
        _creatorMenuItem(
          const Icon(FontAwesomeIcons.b, size: 16),
          '硬币记录',
          () => Get.to(
            const LogPage(),
            arguments: CoinLogController(),
          ),
        ),
        _creatorMenuItem(
          const Icon(Icons.linear_scale, size: 18),
          '经验记录',
          () => Get.to(
            const LogPage(),
            arguments: ExpLogController(),
          ),
        ),
        _creatorMenuItem(
          const Icon(Icons.settings_outlined, size: 19),
          '空间设置',
          () => Get.toNamed('/spaceSetting'),
        ),
      ],
      const PopupMenuDivider(),
      _creatorMenuItem(
        const Icon(Icons.search, size: 19),
        '百度',
        () => _openInternalWeb('https://www.baidu.com'),
      ),
      _creatorMenuItem(
        const Icon(Icons.public, size: 19),
        'Google',
        () => _openInternalWeb('https://www.google.com'),
      ),
      _creatorMenuItem(
        const Icon(FontAwesomeIcons.github, size: 18),
        'GitHub',
        () => _openInternalWeb('https://github.com'),
      ),
      _creatorMenuItem(
        const Icon(Icons.language_outlined, size: 19),
        '浏览器',
        () => unawaited(_showBrowserDialog()),
      ),
    ];
  }

  Widget get _buildHeaderActions {
    const iconSize = 22.0;
    const padding = EdgeInsets.all(8);
    const style = ButtonStyle(tapTargetSize: .shrinkWrap);
    return Row(
      spacing: 5,
      mainAxisAlignment: .end,
      children: [
        if (widget.showBackBtn)
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 8),
                child: BackButton(),
              ),
            ),
          ),
        if (!_mainController.hasHome) ...[
          IconButton(
            iconSize: iconSize,
            padding: padding,
            style: style,
            tooltip: '搜索',
            onPressed: () => Get.toNamed('/search'),
            icon: const Icon(Icons.search),
          ),
          msgBadge(_mainController),
        ],
        IconButton(
          iconSize: iconSize,
          padding: padding,
          style: style,
          tooltip: '离线缓存',
          onPressed: () => Get.toNamed('/download'),
          icon: const Icon(CustomIcons.folderDownloadOutline),
        ),
        if (GStorage.reply != null)
          IconButton(
            iconSize: iconSize,
            padding: padding,
            style: style,
            tooltip: '评论记录',
            onPressed: () => Get.toNamed('/myReply'),
            icon: const Icon(Icons.message_outlined),
          ),
        Obx(
          () {
            final anonymity = MineController.anonymity.value;
            return IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: "${anonymity ? '退出' : '进入'}无痕模式",
              onPressed: MineController.onChangeAnonymity,
              icon: anonymity
                  ? const Icon(MdiIcons.incognito)
                  : const Icon(MdiIcons.incognitoOff),
            );
          },
        ),
        IconButton(
          iconSize: iconSize,
          padding: padding,
          style: style,
          tooltip: '切换账号',
          onPressed: () => LoginPageController.switchAccountDialog(context),
          icon: const Icon(Icons.switch_account_outlined),
        ),
        Obx(
          () {
            return IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: '切换至${controller.nextThemeType.desc}主题',
              onPressed: controller.onChangeTheme,
              icon: controller.themeType.value.icon,
            );
          },
        ),
        IconButton(
          iconSize: iconSize,
          padding: padding,
          style: style,
          tooltip: '设置',
          onPressed: () => Get.toNamed('/setting', preventDuplicates: false),
          icon: const Icon(Icons.settings_outlined),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildUserInfo(ThemeData theme, Color secondary) {
    final style = TextStyle(
      fontSize: theme.textTheme.titleMedium!.fontSize,
      fontWeight: FontWeight.bold,
    );
    final labelStyle = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.outline,
    );
    final coinLabelStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      color: theme.colorScheme.outline,
    );
    final coinValStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      fontWeight: FontWeight.bold,
      color: secondary,
    );
    return Obx(() {
      final userInfo = controller.userInfo.value;
      final levelInfo = userInfo.levelInfo;
      final hasLevel = levelInfo != null;
      final isVip = userInfo.vipStatus != null && userInfo.vipStatus! > 0;
      final userStat = controller.userStat.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: .opaque,
            onTap: controller.onLogin,
            onLongPress: () {
              Feedback.forLongPress(context);
              controller.onLogin(true);
            },
            onSecondaryTap: PlatformUtils.isMobile
                ? null
                : () => controller.onLogin(true),
            child: Row(
              mainAxisSize: .min,
              children: [
                const SizedBox(width: 20),
                userInfo.face != null
                    ? Stack(
                        clipBehavior: .none,
                        children: [
                          NetworkImgLayer(
                            src: userInfo.face,
                            type: .avatar,
                            width: 55,
                            height: 55,
                          ),
                          if (isVip)
                            Positioned(
                              right: -1,
                              bottom: -2,
                              child: SvgPicture.asset(
                                Assets.vipIcon,
                                height: 19,
                                semanticsLabel: "大会员",
                              ),
                            ),
                        ],
                      )
                    : ClipOval(
                        child: Image.asset(
                          width: 55,
                          height: 55,
                          cacheHeight: 55.cacheSize(context),
                          Assets.avatarPlaceHolder,
                          semanticLabel: "默认头像",
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: .min,
                    mainAxisAlignment: .center,
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          Flexible(
                            child: Text(
                              userInfo.uname ?? '点击登录',
                              style: theme.textTheme.titleMedium!.copyWith(
                                height: 1,
                                color: isVip && userInfo.vipType == 2
                                    ? theme.colorScheme.vipColor
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ),
                          BiliUtils.levelPicture(
                            levelInfo?.currentLevel ?? 0,
                            isSeniorMember: userInfo.isSeniorMember == 1,
                            height: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '硬币 ',
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: userInfo.money?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "      经验 ",
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: levelInfo?.currentExp?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "/${levelInfo?.nextExp ?? '-'}",
                              style: coinLabelStyle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 225),
                        child: LinearProgressIndicator(
                          minHeight: 2.25,
                          value: hasLevel
                              ? levelInfo.currentExp! / levelInfo.nextExp!
                              : 0,
                          backgroundColor: theme.colorScheme.outline.withValues(
                            alpha: 0.4,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(secondary),
                          stopIndicatorColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: .spaceEvenly,
            children: [
              _btn(
                count: userStat.dynamicCount,
                countStyle: style,
                name: '动态',
                labelStyle: labelStyle,
                onTap: () => controller.push('memberDynamics'),
              ),
              _btn(
                count: userStat.following,
                countStyle: style,
                name: '关注',
                labelStyle: labelStyle,
                onTap: () => controller.push('follow'),
              ),
              _btn(
                count: userStat.follower,
                countStyle: style,
                name: '粉丝',
                labelStyle: labelStyle,
                onTap: () => controller.push('fan'),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _btn({
    required int? count,
    required TextStyle countStyle,
    required String name,
    required TextStyle? labelStyle,
    required VoidCallback onTap,
  }) {
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: Style.mdRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: AspectRatio(
            aspectRatio: 1,
            child: Column(
              spacing: 4,
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                Text(
                  count?.toString() ?? '-',
                  style: countStyle,
                ),
                Text(
                  name,
                  style: labelStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openInternalWeb(String url) => Get.toNamed(
    '/webview',
    parameters: {'url': url},
  );

  void _shareHomepage() {
    final mid = controller.userInfo.value.mid;
    if (mid != null) {
      ShareUtils.shareText('https://space.bilibili.com/$mid');
    }
  }

  void _createShortcut() {
    final userInfo = controller.userInfo.value;
    final mid = userInfo.mid;
    if (mid == null) return;
    if (Platform.isIOS) {
      PageUtils.launchURL(
        'https://www.bilibili.com/blackboard/disablelink/go-to-up-space.html?mid=$mid',
      );
    } else if (Platform.isAndroid) {
      unawaited(_createShortcutAndroid());
    }
  }

  Future<void> _createShortcutAndroid() async {
    final userInfo = controller.userInfo.value;
    final mid = userInfo.mid;
    final face = userInfo.face;
    final name = userInfo.uname;
    if (mid == null || face == null || name == null) return;
    SmartDialog.showLoading();
    try {
      final file = await CacheManager.manager.getSingleFile(
        '$face@200w_200h.webp'.http2https,
      );
      PiliAndroidHelper.createShortcut(
        mid.toString(),
        'bilibili://space/$mid',
        name,
        file.path,
      );
    } catch (e) {
      SmartDialog.showToast(e.toString());
    } finally {
      SmartDialog.dismiss();
    }
  }

  Future<void> _vipExpAdd() async {
    final res = await UserHttp.vipExpAdd();
    if (res.isSuccess) {
      SmartDialog.showToast('领取成功');
    } else {
      res.toast();
    }
  }

  Future<void> _showBrowserDialog() async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('浏览器'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'example.com 或 https://example.com',
          ),
          onSubmitted: (value) => Get.back(result: value.trim()),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          TextButton(
            onPressed: () => Get.back(result: controller.text.trim()),
            child: const Text('打开'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (input == null || input.isEmpty) return;
    final url = RegExp(
      r'^https?://',
      caseSensitive: false,
    ).hasMatch(input)
        ? input
        : 'https://$input';
    _openInternalWeb(url);
  }

  void _autoRefresh() => Future.delayed(
    const Duration(milliseconds: 150),
    () => controller.onRefresh(isManual: false),
  );

  Widget _buildFav(ThemeData theme, Color secondary) {
    return Column(
      children: [
        Divider(
          height: 20,
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
        ListTile(
          onTap: () => Get.toNamed('/fav')?.whenComplete(_autoRefresh),
          dense: true,
          title: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '我的收藏  ',
                    style: TextStyle(
                      fontSize: theme.textTheme.titleMedium!.fontSize,
                      fontWeight: .bold,
                    ),
                  ),
                  if (controller.favFolderCount != null)
                    TextSpan(
                      text: "${controller.favFolderCount}  ",
                      style: TextStyle(
                        fontSize: theme.textTheme.titleSmall!.fontSize,
                        color: secondary,
                      ),
                    ),
                  WidgetSpan(
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          trailing: IconButton(
            tooltip: '刷新',
            onPressed: controller.onRefresh,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ),
        _buildFavBody(theme, secondary, controller.loadingState.value),
      ],
    );
  }

  Widget _buildFavBody(
    ThemeData theme,
    Color secondary,
    LoadingState loadingState,
  ) {
    return switch (loadingState) {
      Loading() => const SizedBox.shrink(),
      Success(:final response) => Builder(
        builder: (context) {
          List<FavFolderInfo>? favFolderList = response.list;
          if (favFolderList == null || favFolderList.isEmpty) {
            return const SizedBox.shrink();
          }
          bool flag = (controller.favFolderCount ?? 0) > favFolderList.length;
          return SizedBox(
            height: 200,
            child: ListView.separated(
              controller: controller.scrollController,
              padding: const .only(left: 20, top: 10, right: 20),
              itemCount: response.list.length + (flag ? 1 : 0),
              itemBuilder: (context, index) {
                if (flag && index == favFolderList.length) {
                  return Padding(
                    padding: const .only(bottom: 35),
                    child: Center(
                      child: IconButton(
                        tooltip: '查看更多',
                        style: ButtonStyle(
                          padding: const WidgetStatePropertyAll(.zero),
                          backgroundColor: WidgetStatePropertyAll(
                            theme.colorScheme.secondaryContainer.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        onPressed: () =>
                            Get.toNamed('/fav')?.whenComplete(_autoRefresh),
                        icon: Icon(
                          Icons.arrow_forward_ios,
                          size: 18,
                          color: secondary,
                        ),
                      ),
                    ),
                  );
                } else {
                  return FavFolderItem(
                    heroTag: Utils.generateRandomString(8),
                    item: response.list[index],
                    onPop: _autoRefresh,
                  );
                }
              },
              scrollDirection: .horizontal,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
            ),
          );
        },
      ),
      Error(:final errMsg) => SizedBox(
        height: 160,
        child: Center(
          child: Text(
            errMsg ?? '',
            textAlign: .center,
          ),
        ),
      ),
    };
  }
}
