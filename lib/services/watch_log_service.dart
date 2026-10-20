import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate' show Isolate;

import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/path_utils.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:path/path.dart' as path;

abstract final class WatchLogService {
  static final dir = Directory(path.join(appSupportDirPath, 'watchlog'));
  static final _hot = File(path.join(dir.path, 'watchlog.jsonl'));
  static final _open = File(path.join(dir.path, 'watchlog.open'));
  static Future<void> _chain = Future.value();
  static bool _ready = false;
  static int? _ac;
  static int _from = 0;

  static Future<void> _run(Future<void> Function() op) =>
      _chain = _chain.then((_) async {
        try {
          if (!_ready) {
            _ready = true;
            await _init();
          }
          await op();
        } catch (e) {
          if (kDebugMode) debugPrint('watch log: $e');
        }
      });

  static Future<void> _init() async {
    await dir.create(recursive: true);
    _ac = null;
    if (await _hot.exists()) {
      try {
        final head =
            jsonDecode(
                  await _hot
                      .openRead(0, 1024)
                      .transform(utf8.decoder)
                      .transform(const LineSplitter())
                      .first,
                )
                as Map;
        _ac = head['ac'] as int?;
        _from = head['from'] as int? ?? 0;
      } catch (_) {}
    }
    if (await _open.exists()) {
      try {
        final rec = jsonDecode(await _open.readAsString()) as Map;
        rec['x'] = 1;
        await _line(jsonEncode(rec));
      } catch (_) {}
      await _open.delete();
    }
  }

  static Future<void> _line(String json) {
    if (_ac != null) {
      return _hot.writeAsString('$json\n', mode: FileMode.append, flush: true);
    }
    _ac = Accounts.main.mid;
    _from = DateTime.now().millisecondsSinceEpoch;
    return _hot.writeAsString(
      '{"from":$_from,"ac":$_ac}\n$json\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  static String _encode(Map<String, Object> rec, int viewer) {
    if (viewer != (_ac ?? Accounts.main.mid)) rec['ac'] = viewer;
    return jsonEncode(rec);
  }

  static void append(Map<String, Object> rec, int viewer) => _run(() async {
    await _line(_encode(rec, viewer));
    _lastCheckpoint = null;
    if (await _open.exists()) await _open.delete();
  });

  // Last checkpoint body without 't1' (the only field that changes every tick).
  static String? _lastCheckpoint;

  // Writes only when the session content changed since the last checkpoint, so
  // a paused or idle session costs one in-memory encode per tick, no disk I/O.
  static void checkpoint(Map<String, Object> rec, int viewer) =>
      _run(() async {
        final t1 = rec.remove('t1');
        final body = _encode(rec, viewer);
        if (body != _lastCheckpoint) {
          final tmp = File('${_open.path}.tmp');
          rec['t1'] = t1!;
          await tmp.writeAsString(jsonEncode(rec), flush: true);
          await tmp.rename(_open.path);
          _lastCheckpoint = body;
        } else {
          rec['t1'] = t1!;
        }
      });

  static String _ymd(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  static Future<void> rotate(int cutoffMs) => _run(() async {
    if (await _hot.exists() && _from < cutoffMs) {
      final now = DateTime.now().millisecondsSinceEpoch;
      var segment = File(
        path.join(dir.path, 'watchlog-${_ymd(_from)}-${_ymd(now)}.jsonl'),
      );
      if (await segment.exists() || await File('${segment.path}.gz').exists()) {
        segment = File(
          path.join(dir.path, 'watchlog-${_ymd(_from)}-${_ymd(now)}-$now.jsonl'),
        );
      }
      await _hot.rename(segment.path);
      _ac = null;
      _lastCheckpoint = null;
    }
    for (final e in await dir.list().toList()) {
      if (e is File &&
          e.path.endsWith('.jsonl') &&
          path.basename(e.path).startsWith('watchlog-')) {
        await e.openRead().transform(gzip.encoder).pipe(
          File('${e.path}.gz').openWrite(),
        );
        await e.delete();
      }
    }
  });

  static Future<List<File>> files() async {
    await _chain;
    if (!await dir.exists()) return const [];
    return [
      for (final e in await dir.list().toList())
        if (e is File &&
            (e.path.endsWith('.jsonl') || e.path.endsWith('.jsonl.gz')))
          e,
    ]..sort((a, b) => a.path.compareTo(b.path));
  }

  /// Every finished session, newest first. Read and decoded off the UI
  /// isolate; a line still being appended is skipped.
  static Future<List<Map<String, dynamic>>> records() async {
    final paths = [for (final f in await files()) f.path];
    return Isolate.run(() {
      final out = <Map<String, dynamic>>[];
      for (final p in paths) {
        final bytes = File(p).readAsBytesSync();
        final text = utf8.decode(
          p.endsWith('.gz') ? gzip.decode(bytes) : bytes,
          allowMalformed: true,
        );
        int? ac;
        for (final line in const LineSplitter().convert(text)) {
          if (line.isEmpty) continue;
          final Object? value;
          try {
            value = jsonDecode(line);
          } catch (_) {
            continue;
          }
          if (value is! Map<String, dynamic>) continue;
          if (value['k'] == null) {
            ac = value['ac'] as int?;
            continue;
          }
          value['ac'] ??= ac;
          out.add(value);
        }
      }
      return out.reversed.toList();
    });
  }

  /// Milliseconds played on each day of [year], index 0 = 1 January. A day
  /// runs 04:00 to 04:00 in the time zone the session was watched in, the
  /// same day the launch counter uses. Only segments whose file name overlaps
  /// the year are read, and only the per-day sums leave the isolate.
  static Future<List<int>> dailyPlayed(int year) async {
    final paths = [
      for (final f in await files())
        if (path.basename(f.path) case final name
            when name == 'watchlog.jsonl' ||
                int.parse(name.substring(9, 13)) <= year &&
                    year <= int.parse(name.substring(18, 22)))
          f.path,
    ];
    return Isolate.run(() {
      final start = DateTime.utc(year).millisecondsSinceEpoch;
      final days = List.filled(
        DateTime.utc(year + 1).difference(DateTime.utc(year)).inDays,
        0,
      );
      for (final p in paths) {
        final bytes = File(p).readAsBytesSync();
        final text = utf8.decode(
          p.endsWith('.gz') ? gzip.decode(bytes) : bytes,
          allowMalformed: true,
        );
        for (final line in const LineSplitter().convert(text)) {
          final Object? r;
          try {
            r = jsonDecode(line);
          } catch (_) {
            continue;
          }
          if (r is! Map || r['k'] == null) continue;
          final ms =
              (r['t0'] as int) + ((r['z'] as int) - 240) * 60000 - start;
          if (ms >= 0 && ms < days.length * Duration.millisecondsPerDay) {
            days[ms ~/ Duration.millisecondsPerDay] += r['a'] as int;
          }
        }
      }
      return days;
    });
  }

  static Future<void> restore(Iterable<File> sources) => _run(() async {
    // _init already folded any crash leftover into the log being replaced; a
    // live .open here is the session still playing, and must not be folded in
    // again as a crashed record on top of its own final append.
    for (final e in await dir.list().toList()) {
      if (e is File &&
          (e.path.endsWith('.jsonl') ||
              e.path.endsWith('.jsonl.gz') ||
              e.path.startsWith(_open.path))) {
        await e.delete();
      }
    }
    for (final f in sources) {
      await f.copy(path.join(dir.path, path.basename(f.path)));
    }
    _ready = false;
    _lastCheckpoint = null;
  });
}
