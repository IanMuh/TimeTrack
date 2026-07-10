import '../core/date_time_ext.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/activity_category.dart';
import '../domain/stats_period.dart';
import '../domain/time_entry.dart';
import 'time_stats.dart';

typedef StatsDateReader = DateTime Function();
typedef StatsActivityReader = List<Activity> Function();
typedef StatsCategoryReader = List<ActivityCategory> Function();
typedef StatsCategoryLinkReader = List<ActivityCategoryLink> Function();
typedef StatsUnassignedActivityReader = Activity? Function();
typedef StatsEntryReader = List<TimeEntry> Function();
typedef StatsRangeEntryLoader = Future<List<TimeEntry>> Function({
  required DateTime start,
  required DateTime end,
});
typedef StatsRangeActionLogLoader = Future<List<ActionLog>> Function({
  required DateTime start,
  required DateTime end,
});
typedef StatsAllEntryLoader = Future<List<TimeEntry>> Function();

class StatsState {
  const StatsState({
    required StatsDateReader selectedDay,
    required StatsDateReader now,
    required StatsActivityReader activities,
    required StatsCategoryReader categories,
    required StatsCategoryLinkReader categoryLinks,
    required StatsUnassignedActivityReader unassignedActivity,
    required StatsEntryReader dayEntries,
    required StatsRangeEntryLoader entriesForRange,
    required StatsRangeActionLogLoader actionLogsForRange,
    required StatsAllEntryLoader allEntries,
  })  : _selectedDay = selectedDay,
        _now = now,
        _activities = activities,
        _categories = categories,
        _categoryLinks = categoryLinks,
        _unassignedActivity = unassignedActivity,
        _dayEntries = dayEntries,
        _entriesForRange = entriesForRange,
        _actionLogsForRange = actionLogsForRange,
        _allEntries = allEntries;

  final StatsDateReader _selectedDay;
  final StatsDateReader _now;
  final StatsActivityReader _activities;
  final StatsCategoryReader _categories;
  final StatsCategoryLinkReader _categoryLinks;
  final StatsUnassignedActivityReader _unassignedActivity;
  final StatsEntryReader _dayEntries;
  final StatsRangeEntryLoader _entriesForRange;
  final StatsRangeActionLogLoader _actionLogsForRange;
  final StatsAllEntryLoader _allEntries;

  Future<List<TimeEntry>> entriesForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final entries = await _entriesForRange(start: start, end: end);
    return entriesWithUnassignedGaps(entries, start, end);
  }

  Future<List<ActionLog>> actionLogsForRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _actionLogsForRange(start: start, end: end);
  }

  Future<TimeRangeStats> statsForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final storedEntries = await _entriesForRange(start: start, end: end);
    final entries = TimeStatsCalculator.visibleStoredEntries(
      entries: storedEntries,
      unassignedActivity: _unassignedActivity(),
    );
    return TimeRangeStats.fromEntries(
      entries: entries,
      start: start,
      end: end,
      effectiveNow: _now(),
      activities: _activities(),
      categories: _categories(),
      categoryLinks: _categoryLinks(),
    );
  }

  Map<String, Duration> todayTotals() {
    final start = _selectedDay().startOfDay;
    final end = start.add(const Duration(days: 1));
    return _totalsForEntries(
      entries: entriesWithUnassignedGaps(_dayEntries(), start, end),
      start: start,
      end: end,
    );
  }

  Future<Map<String, Duration>> weekTotals() {
    return totalsForPeriod(StatsPeriod.week);
  }

  Future<Map<String, Duration>> totalsForPeriod(StatsPeriod period) async {
    final (start, end) = period.windowFor(_selectedDay());
    if (period == StatsPeriod.day) {
      return _totalsForEntries(
        entries: entriesWithUnassignedGaps(_dayEntries(), start, end),
        start: start,
        end: end,
      );
    }

    final entries = await _entriesForPeriod(period, start, end);
    return _totalsForEntries(entries: entries, start: start, end: end);
  }

  Duration longestBlock() {
    final start = _selectedDay().startOfDay;
    final end = start.add(const Duration(days: 1));
    return _longestForEntries(
      entries: entriesWithUnassignedGaps(_dayEntries(), start, end),
      start: start,
      end: end,
    );
  }

  Future<Duration> longestBlockForPeriod(StatsPeriod period) async {
    final (start, end) = period.windowFor(_selectedDay());
    if (period == StatsPeriod.day) {
      return _longestForEntries(
        entries: entriesWithUnassignedGaps(_dayEntries(), start, end),
        start: start,
        end: end,
      );
    }
    if (period == StatsPeriod.all) {
      var longest = Duration.zero;
      for (final entry in TimeStatsCalculator.visibleStoredEntries(
        entries: await _allEntries(),
        unassignedActivity: _unassignedActivity(),
      )) {
        final duration = entry.durationUntil(_now());
        if (duration > longest) {
          longest = duration;
        }
      }
      return longest;
    }
    final entries = await entriesForRange(start: start, end: end);
    return _longestForEntries(entries: entries, start: start, end: end);
  }

  List<TimeEntry> visibleDayEntries() {
    final start = _selectedDay().startOfDay;
    final end = start.add(const Duration(days: 1));
    final visible = _dayEntries().where((entry) {
      final entryEnd = entry.endAt ?? _now();
      return entry.startAt.isBefore(end) && entryEnd.isAfter(start);
    }).toList();
    return entriesWithUnassignedGaps(visible, start, end);
  }

  List<TimeEntry> entriesWithUnassignedGaps(
    List<TimeEntry> entries,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    return TimeStatsCalculator.entriesWithUnassignedGaps(
      entries: entries,
      unassignedActivity: _unassignedActivity(),
      windowStart: windowStart,
      windowEnd: windowEnd,
      effectiveNow: _now(),
    );
  }

  Future<List<TimeEntry>> _entriesForPeriod(
    StatsPeriod period,
    DateTime start,
    DateTime end,
  ) async {
    if (period == StatsPeriod.all) {
      return TimeStatsCalculator.visibleStoredEntries(
        entries: await _allEntries(),
        unassignedActivity: _unassignedActivity(),
      );
    }
    return entriesForRange(start: start, end: end);
  }

  Map<String, Duration> _totalsForEntries({
    required List<TimeEntry> entries,
    required DateTime start,
    required DateTime end,
  }) {
    return TimeStatsCalculator.totalsInWindow(
      entries: entries,
      windowStart: start,
      windowEnd: end,
      effectiveNow: _now(),
    );
  }

  Duration _longestForEntries({
    required List<TimeEntry> entries,
    required DateTime start,
    required DateTime end,
  }) {
    return TimeStatsCalculator.longestInWindow(
      entries: entries,
      windowStart: start,
      windowEnd: end,
      effectiveNow: _now(),
    );
  }
}
