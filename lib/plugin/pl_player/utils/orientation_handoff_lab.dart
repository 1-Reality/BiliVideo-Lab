import 'package:flutter/foundation.dart' show debugPrint;

abstract final class OrientationHandoffLab {
  static bool enabled = false;
  static final Stopwatch _clock = Stopwatch()..start();
  static final List<String> _lines = <String>[];
  static int _sequence = 0;

  static void log(String message) {
    if (!enabled) return;
    final line =
        '${(++_sequence).toString().padLeft(3, '0')} +${_clock.elapsedMilliseconds}ms ${message}';
    _lines.add(line);
    if (_lines.length > 300) {
      _lines.removeRange(0, _lines.length - 300);
    }
    debugPrint('[OrientationLab] $line');
  }

  static String get text => _lines.join('\n');
  static int get lineCount => _lines.length;

  static void clear() {
    _lines.clear();
    _sequence = 0;
    _clock.reset();
  }
}
