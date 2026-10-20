import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/common/widgets/view_safe_area.dart';
import 'package:PiliBro/services/watch_log_service.dart';
import 'package:collection/collection.dart' show lowerBound;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// One year of the local watch log as twelve month calendars, each day shaded
/// by how long was played. Computed only when opened.
class WatchCalendarPage extends StatefulWidget {
  const WatchCalendarPage({super.key, required this.year});

  final int year;

  @override
  State<WatchCalendarPage> createState() => _WatchCalendarPageState();
}

class _WatchCalendarPageState extends State<WatchCalendarPage> {
  // Shade 1..4 by rank among the days that have any playback, so a light
  // viewer's calendar is as readable as a heavy one's; 0 = nothing played.
  late final _data = WatchLogService.dailyPlayed(widget.year).then((days) {
    final played = [
      for (final d in days)
        if (d > 0) d,
    ]..sort();
    return (
      days: days,
      levels: [
        for (final d in days)
          d == 0
              ? 0
              : (4 * lowerBound(played, d + 1) + played.length - 1) ~/
                    played.length,
      ],
    );
  });

  static String _length(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 3600}:${(s ~/ 60 % 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  String _date(int day) {
    final d = DateTime.utc(widget.year).add(Duration(days: day));
    return '${d.month}月${d.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return SimpleScaffold(
      appBar: AppBar(title: Text('${widget.year} 年观看日历')),
      body: ViewSafeArea(
        child: FutureBuilder(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('读取失败：${snapshot.error}'));
            }
            final data = snapshot.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final (:days, :levels) = data;
            var watched = 0, total = 0, top = 0, streak = 0, run = 0;
            for (var i = 0; i < days.length; i++) {
              if (days[i] > 0) watched++;
              total += days[i];
              if (days[i] > days[top]) top = i;
              run = days[i] > 0 ? run + 1 : 0;
              if (run > streak) streak = run;
            }
            final colors = [
              colorScheme.surfaceContainerHighest,
              for (final a in const [0.3, 0.5, 0.75, 1.0])
                colorScheme.primary.withValues(alpha: a),
            ];
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth ~/ 220).clamp(2, 4);
                // Floored so float error never pushes a month onto its own row.
                final width =
                    ((constraints.maxWidth - 16 * (columns + 1)) / columns)
                        .floorToDouble();
                return ListView(
                  padding: .fromLTRB(
                    16,
                    12,
                    16,
                    MediaQuery.viewPaddingOf(context).bottom + 48,
                  ),
                  children: [
                    Text(
                      watched == 0
                          ? '这一年本机没有观看记录'
                          : '观看 $watched 天 · 共 ${_length(total)}\n'
                                '最多 ${_date(top)} ${_length(days[top])}'
                                ' · 最长连续 $streak 天',
                    ),
                    Text(
                      '按本机观看日志统计，凌晨 4 点换日；点日期看当天时长',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (var m = 1; m <= 12; m++)
                          _month(m, width, days, levels, colors, colorScheme),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _month(
    int month,
    double width,
    List<int> days,
    List<int> levels,
    List<Color> colors,
    ColorScheme colorScheme,
  ) {
    final first = DateTime.utc(widget.year, month);
    final start = first.difference(DateTime.utc(widget.year)).inDays;
    final length = DateTime.utc(widget.year, month + 1).difference(first).inDays;
    final offset = first.weekday - 1;
    final cell = width / 7;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text('$month 月', style: const TextStyle(fontWeight: .bold)),
          Row(
            children: [
              for (final w in '一二三四五六日'.split(''))
                Expanded(
                  child: Text(
                    w,
                    textAlign: .center,
                    style: TextStyle(
                      fontSize: cell * 0.3,
                      color: colorScheme.outline,
                    ),
                  ),
                ),
            ],
          ),
          GestureDetector(
            onTapUp: (e) {
              final d =
                  e.localPosition.dy ~/ cell * 7 +
                  e.localPosition.dx ~/ cell -
                  offset;
              if (d < 0 || d >= length) return;
              SmartDialog.showToast(
                '${_date(start + d)} · 观看 ${_length(days[start + d])}',
              );
            },
            child: CustomPaint(
              size: Size(width, (offset + length + 6) ~/ 7 * cell),
              painter: _MonthPainter(
                start: start,
                length: length,
                offset: offset,
                levels: levels,
                colors: colors,
                text: colorScheme.onSurfaceVariant,
                onDark: colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthPainter extends CustomPainter {
  const _MonthPainter({
    required this.start,
    required this.length,
    required this.offset,
    required this.levels,
    required this.colors,
    required this.text,
    required this.onDark,
  });

  final int start;
  final int length;
  final int offset;
  final List<int> levels;
  final List<Color> colors;
  final Color text;
  final Color onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 7;
    final paint = Paint();
    for (var d = 0; d < length; d++) {
      final i = offset + d;
      final rect = Rect.fromLTWH(
        i % 7 * cell,
        i ~/ 7 * cell,
        cell,
        cell,
      ).deflate(cell * 0.06);
      final level = levels[start + d];
      paint.color = colors[level];
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18)),
        paint,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${d + 1}',
          style: TextStyle(
            fontSize: cell * 0.34,
            color: level > 2 ? onDark : text,
          ),
        ),
        textDirection: .ltr,
      )..layout();
      label.paint(
        canvas,
        rect.center - Offset(label.width / 2, label.height / 2),
      );
      label.dispose();
    }
  }

  @override
  bool shouldRepaint(_MonthPainter old) =>
      old.levels != levels || old.colors[4] != colors[4];
}
