abstract final class DurationUtils {
  static String formatDuration(num? seconds) {
    if (seconds == null || seconds == 0) {
      return '00:00';
    }
    final h = seconds ~/ 3600;
    seconds -= h * 3600;
    final m = seconds ~/ 60;
    seconds -= m * 60;
    final sms = seconds is double
        ? seconds.toStringAsFixed(3).padLeft(6, '0')
        : seconds.toString().padLeft(2, '0');
    return h == 0
        ? "${m.toString().padLeft(2, '0')}:$sms"
        : "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:$sms";
  }

  static final _splitRegex = RegExp(r'[:：]');
  static int parseDuration(String? data) {
    if (data == null || data.isEmpty) {
      return 0;
    }
    int duration = 0;
    int unit = 1;
    for (final part in data.split(_splitRegex).reversed) {
      duration += int.parse(part) * unit;
      unit *= 60;
    }
    return duration;
  }

  static String formatDurationBetween(int startMillis, int endMillis) =>
      formatTimeDuration(Duration(milliseconds: endMillis - startMillis));

  static String formatTimeDuration(Duration duration) {
    final inDays = duration.inDays;
    final years = inDays ~/ 365;
    final daysLeft = inDays - years * 365;
    final months = daysLeft ~/ 30;
    final days = daysLeft - months * 30;
    final inHours = duration.inHours;
    final hours = inHours - inDays * 24;
    final minutes = duration.inMinutes - inHours * 60;

    final format = StringBuffer();

    if (years > 0) format.write('$years年');
    if (months > 0) format.write('$months月');
    if (days > 0) format.write('$days天');
    if (hours > 0) format.write('$hours小时');
    if (minutes > 0) format.write('$minutes分钟');

    return format.toString();
  }
}
