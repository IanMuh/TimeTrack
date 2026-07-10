part of 'app_state.dart';

mixin AppStateStatsFacade on ChangeNotifier {
  StatsState get _statsState;

  Future<List<TimeEntry>> entriesForRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _statsState.entriesForRange(start: start, end: end);
  }

  Future<List<ActionLog>> actionLogsForRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _statsState.actionLogsForRange(start: start, end: end);
  }

  Future<TimeRangeStats> statsForRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _statsState.statsForRange(start: start, end: end);
  }

  Map<String, Duration> todayTotals() => _statsState.todayTotals();

  Future<Map<String, Duration>> weekTotals() {
    return _statsState.weekTotals();
  }

  Future<Map<String, Duration>> totalsForPeriod(StatsPeriod period) {
    return _statsState.totalsForPeriod(period);
  }

  Duration longestBlock() => _statsState.longestBlock();

  Future<Duration> longestBlockForPeriod(StatsPeriod period) {
    return _statsState.longestBlockForPeriod(period);
  }

  List<TimeEntry> visibleDayEntries() => _statsState.visibleDayEntries();
}
