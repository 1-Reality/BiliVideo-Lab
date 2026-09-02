import 'dart:math' show pow;

import 'package:flutter/widgets.dart' show BuildContext, MediaQuery;

extension ImageExtension on num {
  int? cacheSize(BuildContext context) =>
      this == 0 ? null : (this * MediaQuery.devicePixelRatioOf(context)).round();
}

extension IntExt on int? {
  int? operator +(int other) => this == null ? null : this! + other;
  int? operator -(int other) => this == null ? null : this! - other;
}

extension DoubleExt on double {
  double toPrecision(int fractionDigits) {
    final mod = switch (fractionDigits) {
      0 => 1.0,
      1 => 10.0,
      2 => 100.0,
      3 => 1000.0,
      4 => 10000.0,
      5 => 100000.0,
      _ => pow(10, fractionDigits).toDouble(),
    };
    return (this * mod).roundToDouble() / mod;
  }

  bool equals(double other, [double epsilon = 1e-10]) =>
      (this - other).abs() < epsilon;

  double lerp(double a, double b) {
    assert(
      a.isFinite,
      'Cannot interpolate between finite and non-finite values',
    );
    assert(
      b.isFinite,
      'Cannot interpolate between finite and non-finite values',
    );
    assert(isFinite, 't must be finite when interpolating between values');
    return a * (1.0 - this) + b * this;
  }
}
