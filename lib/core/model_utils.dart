bool readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return false;
}

DateTime parseDateTime(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String) return DateTime.parse(value).toLocal();
  throw FormatException('parseDateTime: $key must be a non-null String');
}
