import 'dart:io' show Platform;

import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/common/widgets/view_safe_area.dart';
import 'package:PiliBro/services/traffic_stats_service.dart';
import 'package:material_ui/material_ui.dart';

class TrafficStatsPage extends StatefulWidget {
  const TrafficStatsPage({super.key});

  @override
  State<TrafficStatsPage> createState() => _TrafficStatsPageState();
}

class _TrafficStatsPageState extends State<TrafficStatsPage> {
  late DateTime start = DateUtils.dateOnly(DateTime.now());
  late DateTime end = start;
  Map<String, dynamic> data = const {};

  static const labels = {
    'wifiBroadband': 'Wi-Fi · 等效宽带',
    'wifiCellular': 'Wi-Fi · 等效移网',
    'wiredBroadband': '有线 · 等效宽带',
    'wiredCellular': '有线 · 等效移网',
    'mobile': '真正蜂窝流量',
    'other': '其他网络',
  };

  String _label(String key) {
    if (key.startsWith('appObserved.')) {
      final network = key.substring('appObserved.'.length);
      return '本应用观察值 · ${labels[network] ?? network}';
    }
    if (key.startsWith('activeInterface.')) {
      final network = key.substring('activeInterface.'.length);
      return '活动网卡总量 · ${labels[network] ?? network}';
    }
    return labels[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final value = await TrafficStatsService.instance.snapshot(
      start: start,
      end: end,
    );
    if (mounted) setState(() => data = value);
  }

  Future<void> _selectRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: start, end: end),
    );
    if (range != null) {
      setState(() {
        start = DateUtils.dateOnly(range.start);
        end = DateUtils.dateOnly(range.end);
      });
      await _refresh();
    }
  }

  bool _inRange(String key) {
    final time = DateTime.tryParse('$key:00:00');
    return time != null &&
        !time.isBefore(start) &&
        time.isBefore(end.add(const Duration(days: 1)));
  }

  Map<String, ({int received, int sent})> _aggregate(
    Iterable<MapEntry<String, dynamic>> entries,
  ) {
    final result = <String, ({int received, int sent})>{};
    for (final entry in entries) {
      final hourly = entry.value as Map;
      for (final item in hourly.entries) {
        final raw = item.value as Map;
        final previous = result[item.key.toString()] ?? (received: 0, sent: 0);
        result[item.key.toString()] = (
          received:
              previous.received + (raw['received'] as num? ?? 0).toInt(),
          sent: previous.sent + (raw['sent'] as num? ?? 0).toInt(),
        );
      }
    }
    return result;
  }

  String _bytes(int value) {
    if (value >= 1000000000) return '${(value * 0.000000001).toStringAsFixed(3)} GB';
    if (value >= 1000000) return '${(value * 0.000001).toStringAsFixed(3)} MB';
    if (value >= 1000) return '${(value * 0.001).toStringAsFixed(3)} kB';
    return '$value B';
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  ({int received, int sent}) _sourceTotal(
    Map<String, ({int received, int sent})> totals,
    String prefix,
  ) => totals.entries
      .where((entry) => entry.key.startsWith(prefix))
      .fold(
        (received: 0, sent: 0),
        (sum, entry) => (
          received: sum.received + entry.value.received,
          sent: sum.sent + entry.value.sent,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.where((entry) => _inRange(entry.key)).toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final totals = _aggregate(entries);
    final received = totals.values.fold(0, (sum, item) => sum + item.received);
    final sent = totals.values.fold(0, (sum, item) => sum + item.sent);
    final appTotal = _sourceTotal(totals, 'appObserved.');
    final interfaceTotal = _sourceTotal(totals, 'activeInterface.');
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('应用流量统计'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ViewSafeArea(
        child: ListView(
          children: [
            if (Platform.isWindows)
              ValueListenableBuilder<WindowsTrafficLive?>(
                valueListenable: TrafficStatsService.instance.windowsLive,
                builder: (context, live, _) => Column(
                  children: [
                    ListTile(
                      title: const Text('本应用观察值 · 本次运行'),
                      subtitle: Text(
                        live == null
                            ? '正在连接进程内网络电表'
                            : '下行 ${_bytes(live.appReceived)} · 上行 ${_bytes(live.appSent)}',
                      ),
                      trailing: live == null
                          ? null
                          : Text('${_bytes(live.appReceiveRate.round())}/s'),
                    ),
                    ListTile(
                      title: const Text('活动网卡总量 · 本次运行'),
                      subtitle: Text(
                        live == null
                            ? '正在读取活动接口计数器'
                            : '下行 ${_bytes(live.interfaceReceived)} · 上行 ${_bytes(live.interfaceSent)}',
                      ),
                      trailing: live == null
                          ? null
                          : Text('${_bytes(live.interfaceReceiveRate.round())}/s'),
                    ),
                  ],
                ),
              ),
            ListTile(
              title: const Text('日期范围'),
              subtitle: Text('${_date(start)} 至 ${_date(end)}'),
              trailing: const Icon(Icons.date_range),
              onTap: _selectRange,
            ),
            if (Platform.isWindows) ...[
              ListTile(
                title: const Text('范围合计 · 本应用观察值'),
                subtitle: Text(
                  '下行 ${_bytes(appTotal.received)} · 上行 ${_bytes(appTotal.sent)}',
                ),
              ),
              ListTile(
                title: const Text('范围合计 · 活动网卡总量'),
                subtitle: Text(
                  '下行 ${_bytes(interfaceTotal.received)} · 上行 ${_bytes(interfaceTotal.sent)}',
                ),
              ),
            ] else
              ListTile(
                title: const Text('范围合计'),
                subtitle: Text('下行 ${_bytes(received)} · 上行 ${_bytes(sent)}'),
              ),
            const Divider(),
            for (final item in totals.entries)
              ListTile(
                title: Text(_label(item.key)),
                subtitle: Text(
                  '下行 ${_bytes(item.value.received)} · 上行 ${_bytes(item.value.sent)}',
                ),
              ),
            const Divider(),
            for (final entry in entries)
              ExpansionTile(
                title: Text(entry.key.replaceFirst('T', '  ')),
                subtitle: Builder(
                  builder: (_) {
                    final value = _aggregate([entry]);
                    if (Platform.isWindows) {
                      final app = _sourceTotal(value, 'appObserved.');
                      final interface = _sourceTotal(
                        value,
                        'activeInterface.',
                      );
                      return Text(
                        '应用 ↓${_bytes(app.received)} ↑${_bytes(app.sent)} · '
                        '网卡 ↓${_bytes(interface.received)} ↑${_bytes(interface.sent)}',
                      );
                    }
                    final rx = value.values.fold(
                      0,
                      (sum, item) => sum + item.received,
                    );
                    final tx = value.values.fold(0, (sum, item) => sum + item.sent);
                    return Text('下行 ${_bytes(rx)} · 上行 ${_bytes(tx)}');
                  },
                ),
                children: [
                  for (final item in _aggregate([entry]).entries)
                    ListTile(
                      dense: true,
                      title: Text(_label(item.key)),
                      subtitle: Text(
                        '下行 ${_bytes(item.value.received)} · 上行 ${_bytes(item.value.sent)}',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
