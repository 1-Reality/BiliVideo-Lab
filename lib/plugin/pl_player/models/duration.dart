extension DurationExtension on Duration {
  /// Returns clamp of [Duration] between [min] and [max].
  Duration clamp(Duration min, Duration max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }

  /// Returns a [String] representation of [Duration].
  String label({Duration? reference}) {
    reference ??= this;
    final totalSeconds = inSeconds;
    final days = totalSeconds ~/ 86400;
    final daySeconds = totalSeconds - days * 86400;
    final hours = daySeconds ~/ 3600;
    final hourSeconds = daySeconds - hours * 3600;
    final minutes = hourSeconds ~/ 60;
    final seconds = hourSeconds - minutes * 60;
    if (reference > const Duration(days: 1)) {
      return '${days.toString().padLeft(3, '0')}:'
          '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else if (reference > const Duration(hours: 1)) {
      return '${(days * 24 + hours).toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${(days * 1440 + hours * 60 + minutes).toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }
}
