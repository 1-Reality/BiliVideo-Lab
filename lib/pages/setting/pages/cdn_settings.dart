import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/pages/setting/models/video_settings.dart';
import 'package:material_ui/material_ui.dart';

class CdnSettingsPage extends StatelessWidget {
  const CdnSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const quickPlaybackSettings = {'自动同步', '视频同步', '硬解模式'};
    final settings = videoSettings
        .where(
          (item) =>
              item.effectiveTitle.contains('CDN') ||
              quickPlaybackSettings.contains(item.effectiveTitle),
        )
        .toList(growable: false);
    return SimpleScaffold(
      appBar: AppBar(title: const Text('CDN 设置与诊断')),
      body: ListView.builder(
        itemCount: settings.length,
        itemBuilder: (context, index) => settings[index].widget,
      ),
    );
  }
}
