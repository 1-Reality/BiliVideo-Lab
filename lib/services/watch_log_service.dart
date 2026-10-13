import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
      '{"v":1,"from":$_from,"ac":$_ac}\n$json\n',
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
    if (await _open.exists()) await _open.delete();
  });

  static void checkpoint(Map<String, Object> rec, int viewer) =>
      _run(() async {
        final tmp = File('${_open.path}.tmp');
        await tmp.writeAsString(_encode(rec, viewer), flush: true);
        await tmp.rename(_open.path);
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

  static Future<void> restore(Iterable<File> sources) => _run(() async {
    for (final e in await dir.list().toList()) {
      if (e is File &&
          (e.path.endsWith('.jsonl') || e.path.endsWith('.jsonl.gz'))) {
        await e.delete();
      }
    }
    for (final f in sources) {
      await f.copy(path.join(dir.path, path.basename(f.path)));
    }
    _ready = false;
  });
}
