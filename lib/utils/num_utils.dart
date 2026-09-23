import 'package:PiliBro/utils/extension/num_ext.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

abstract final class NumUtils {
  static final _numRegExp = RegExp(r'([\d\.]+)([千万亿])?');

  static int _getUnit(String? unit) {
    switch (unit) {
      case '千':
        return 1000;
      case '万':
        return 10000;
      case '亿':
        return 100000000;
      default:
        return 1;
    }
  }

  static int parseNum(String numberStr) {
    if (numberStr == '-') return 0;
    try {
      final match = _numRegExp.firstMatch(numberStr)!;
      var number = double.parse(match.group(1)!);
      number *= _getUnit(match.group(2));
      return number.toInt();
    } catch (e) {
      if (kDebugMode) debugPrint('parse failed: "$numberStr" : $e');
      return 0;
    }
  }

  static String numFormat(dynamic number) {
    if (number == null) {
      return '0';
    }
    if (number is String) {
      number = int.tryParse(number) ?? number;
      if (number is String) {
        return number;
      }
    }

    if (number >= 100000000) {
      return _formatUnit(number as num, 0.00000001, '亿');
    }
    if (number >= 10000) {
      return _formatUnit(number as num, 0.0001, '万');
    }
    return number.toString();
  }

  static String _formatUnit(num number, double scale, String suffix) {
    final result = (number.toDouble() * scale).toPrecision(1);
    final integer = result.toInt();
    return result == integer ? '$integer$suffix' : '$result$suffix';
  }

  static String formatPositiveDecimal(int number) {
    if (number < 1000) return number.toString();

    final numStr = number.toString();
    final length = numStr.length;
    final sb = StringBuffer();

    int firstLength = length % 3;
    if (firstLength == 0) firstLength = 3;

    sb.write(numStr.substring(0, firstLength));
    for (int i = firstLength; i < length; i += 3) {
      sb
        ..write(',')
        ..write(numStr.substring(i, i + 3));
    }

    return sb.toString();
  }
}
