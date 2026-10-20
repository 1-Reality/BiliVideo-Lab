import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/common/widgets/view_safe_area.dart';
import 'package:PiliBro/models/common/video/video_type.dart';
import 'package:PiliBro/services/watch_log_service.dart';
import 'package:PiliBro/utils/page_utils.dart';
import 'package:material_ui/material_ui.dart';

/// The per-session watch log kept on this device (WatchLogService), as
/// opposed to the account history on Bilibili's servers.
class WatchLogPage extends StatefulWidget {
  const WatchLogPage({super.key});

  @override
  State<WatchLogPage> createState() => _WatchLogPageState();
}

class _WatchLogPageState extends State<WatchLogPage> {
  late Future<List<Map<String, dynamic>>> _records = WatchLogService.records();

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _time(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${t.year}-${_two(t.month)}-${_two(t.day)} '
        '${_two(t.hour)}:${_two(t.minute)}';
  }

  static String _length(num ms) {
    final seconds = ms ~/ 1000;
    final h = seconds ~/ 3600;
    final m = seconds ~/ 60 % 60;
    final s = seconds % 60;
    return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
  }

  Widget _item(Map<String, dynamic> r) {
    final start = r['t0'] as int? ?? 0;
    final watched = r['a'] as num? ?? 0;
    final crashed = r['x'] == 1;
    if (r['k'] == 'l') {
      return ListTile(
        leading: const Icon(Icons.live_tv_outlined),
        title: Text('直播 · ${r['un'] ?? 'UID ${r['up'] ?? '?'}'}'),
        subtitle: Text(
          '${_time(start)} · 观看 ${_length(watched)}${crashed ? ' · 异常结束' : ''}',
        ),
      );
    }

    final media = r['m'] as num? ?? 0;
    final duration = r['d'] as num? ?? 0;
    final furthest = r['mx'] as num? ?? 0;
    final title = r['ti'] ?? r['bv'] ?? 'cid ${r['cid'] ?? '?'}';
    final line1 = [
      _time(start),
      '观看 ${_length(watched)}',
      if (watched > 0) '${(media / watched).toStringAsFixed(2)}×',
      if (duration > 0)
        '到 ${_length(furthest)}／${_length(duration)}',
      if (r['done'] == 1) '看完',
      if (crashed) '异常结束',
    ].join(' · ');
    final line2 = [
      ?r['un'],
      ?r['q'],
      ?r['cd'],
      ?r['nw'],
    ].join(' · ');

    final bvid = r['bv'] as String?;
    final aid = r['av'] as int?;
    final cid = r['cid'] as int?;
    final type = VideoType.values.asNameMap()[r['ct']];
    return ListTile(
      title: Text(
        r['et'] == null ? '$title' : '$title · ${r['et']}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(line2.isEmpty ? line1 : '$line1\n$line2'),
      // Offline files ('local') and records without ids cannot be reopened.
      onTap: type == null || cid == null || (bvid == null && aid == null)
          ? null
          : () => PageUtils.toVideoPage(
              videoType: type,
              bvid: bvid,
              aid: aid,
              cid: cid,
              epId: r['ep'] as int?,
              seasonId: r['ss'] as int?,
              title: r['ti'] as String?,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('本机记录的详细历史'),
        actions: [
          IconButton(
            tooltip: '重新读取',
            onPressed: () =>
                setState(() => _records = WatchLogService.records()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ViewSafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _records,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('读取失败：${snapshot.error}'));
            }
            final records = snapshot.data;
            if (records == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (records.isEmpty) {
              return const Center(child: Text('还没有本机观看记录'));
            }
            return ListView.builder(
              padding: .only(
                bottom: MediaQuery.viewPaddingOf(context).bottom + 48,
              ),
              itemCount: records.length,
              itemBuilder: (context, index) => _item(records[index]),
            );
          },
        ),
      ),
    );
  }
}
