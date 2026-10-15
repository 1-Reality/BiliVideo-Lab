import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/pages/brotech/view.dart';
import 'package:PiliBro/pages/setting/models/model.dart';
import 'package:PiliBro/pages/setting/models/video_settings.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 音画设置: the same items as 设置 → 音视频设置, sorted into swipeable
/// cards. Anything not claimed by CDN, 画质 or 缓冲 falls into 杂项, so a new
/// video setting always shows up somewhere.
class AvSettingsPage extends StatelessWidget {
  const AvSettingsPage({super.key});

  static const _cdn = {
    'CDN 设置',
    '蜂窝网络 CDN 设置',
    '直播 CDN 设置',
    'CDN 测速',
    '音频不跟随 CDN 设置',
    'PC 网络状态联动判断',
    '首选解码格式',
    '蜂窝网络首选解码格式',
  };
  static const _quality = {
    '默认画质',
    '蜂窝网络画质',
    '默认音质',
    '蜂窝网络音质',
    '直播默认画质',
    '蜂窝网络直播默认画质',
    '硬解模式',
  };
  static const _buffer = {
    '缓冲大小',
    '缓冲时长',
    '真蜂窝缓冲大小',
    '真蜂窝缓冲时长',
    '弱网缓冲区和宽带缓冲区同步',
    '弱网缓冲大小',
    '弱网缓冲时长',
  };

  @override
  Widget build(BuildContext context) {
    final cdn = <SettingsModel>[];
    final quality = <SettingsModel>[];
    final buffer = <SettingsModel>[];
    final misc = <SettingsModel>[];
    for (final item in videoSettings) {
      final title = item.effectiveTitle;
      (_cdn.contains(title)
              ? cdn
              : _quality.contains(title)
              ? quality
              : _buffer.contains(title)
              ? buffer
              : misc)
          .add(item);
    }
    final colorScheme = ColorScheme.of(context);
    Widget list(List<SettingsModel> items, [Widget? tail]) => ListView.builder(
      itemCount: items.length + (tail == null ? 0 : 1),
      itemBuilder: (context, index) =>
          index < items.length ? items[index].widget : tail!,
    );
    return DefaultTabController(
      length: 4,
      child: SimpleScaffold(
        appBar: AppBar(
          title: const Text('音画设置'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TabBar(
                dividerHeight: 0,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
                labelColor: colorScheme.onSecondaryContainer,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                splashBorderRadius: const BorderRadius.all(Radius.circular(20)),
                tabs: const [
                  Tab(height: 36, text: 'CDN'),
                  Tab(height: 36, text: '画质'),
                  Tab(height: 36, text: '缓冲'),
                  Tab(height: 36, text: '杂项'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            list(
              cdn,
              ListTile(
                leading: const Icon(Icons.network_check),
                title: const Text('宽带网络诊断'),
                onTap: () => Get.to(() => const BroTechPage()),
              ),
            ),
            list(quality),
            list(buffer),
            list(misc),
          ],
        ),
      ),
    );
  }
}
