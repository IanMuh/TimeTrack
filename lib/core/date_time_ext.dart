extension DateTimeDayBounds on DateTime {
  DateTime get startOfDay => DateTime(year, month, day);

  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  bool isSameDate(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}

String formatDurationCompact(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) {
    return '$minutes 分钟';
  }
  return '$hours 小时 $minutes 分钟';
}
