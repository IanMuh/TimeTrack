import 'package:uuid/uuid.dart';

import '../core/app_constants.dart';
import '../core/date_time_ext.dart';
import '../domain/activity.dart';
import '../domain/activity_category.dart';
import '../domain/time_entry.dart';

part 'time_stats_calculator.dart';
part 'time_range_stats.dart';
part 'time_stats_models.dart';

DateTime _later(DateTime first, DateTime second) {
  return first.isAfter(second) ? first : second;
}

DateTime _earlier(DateTime first, DateTime second) {
  return first.isBefore(second) ? first : second;
}
