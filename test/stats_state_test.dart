import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/stats_state.dart';
import 'package:timetrack/domain/action_log.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/stats_period.dart';
import 'package:timetrack/domain/time_entry.dart';

void main() {
  test('AppState stats facade stays separate from entry facade', () {
    final statsFacade = File('lib/app/app_state_stats_facade.dart');
    final entryFacade = File('lib/app/app_state_entry_facade.dart');

    expect(statsFacade.existsSync(), isTrue);

    final statsSource = statsFacade.readAsStringSync();
    final entrySource = entryFacade.readAsStringSync();

    expect(statsSource, contains('mixin AppStateStatsFacade'));
    expect(statsSource, contains('Future<List<TimeEntry>> entriesForRange({'));
    expect(
      statsSource,
      contains('Future<List<ActionLog>> actionLogsForRange({'),
    );
    expect(statsSource, contains('Future<TimeRangeStats> statsForRange({'));
    expect(statsSource, isNot(contains('TimeRepository get _repository')));
    expect(statsSource, contains('Map<String, Duration> todayTotals()'));
    expect(
      statsSource,
      contains('Future<Map<String, Duration>> weekTotals()'),
    );
    expect(
      statsSource,
      contains('Future<Map<String, Duration>> totalsForPeriod('),
    );
    expect(statsSource, contains('Duration longestBlock()'));
    expect(
      statsSource,
      contains('Future<Duration> longestBlockForPeriod('),
    );
    expect(statsSource, contains('List<TimeEntry> visibleDayEntries()'));
    expect(
      entrySource,
      isNot(contains('Future<TimeRangeStats> statsForRange({')),
    );
    expect(
      entrySource,
      isNot(contains('Map<String, Duration> todayTotals()')),
    );
    expect(
      entrySource,
      isNot(contains('List<TimeEntry> visibleDayEntries()')),
    );
  });

  test('todayTotals includes unassigned gaps for the selected day', () {
    final work = _activity(id: 'work', name: 'Work');
    final unassigned = _activity(
      id: 'unassigned',
      name: 'Unassigned',
      isUnassigned: true,
    );
    final state = _buildState(
      selectedDay: DateTime(2026, 1, 2),
      now: DateTime(2026, 1, 2, 12),
      activities: [work, unassigned],
      unassignedActivity: unassigned,
      dayEntries: [
        _entry(
          id: 'work-entry',
          activityId: work.id,
          startAt: DateTime(2026, 1, 2, 9),
          endAt: DateTime(2026, 1, 2, 10),
        ),
      ],
    );

    final totals = state.todayTotals();

    expect(totals[work.id], const Duration(hours: 1));
    expect(totals[unassigned.id], const Duration(hours: 11));
  });

  test('totalsForPeriod all excludes deleted and stored unassigned rows',
      () async {
    final unassigned = _activity(
      id: 'unassigned',
      name: 'Unassigned',
      isUnassigned: true,
    );
    final state = _buildState(
      unassignedActivity: unassigned,
      allEntries: [
        _entry(id: 'work', activityId: 'work'),
        _entry(id: 'deleted', activityId: 'work', isDeleted: true),
        _entry(id: 'gap', activityId: unassigned.id),
      ],
    );

    final totals = await state.totalsForPeriod(StatsPeriod.all);

    expect(totals.keys, ['work']);
    expect(totals['work'], const Duration(hours: 1));
  });

  test('statsForRange uses real stored entries without unassigned gaps',
      () async {
    final unassigned = _activity(
      id: 'unassigned',
      name: 'Unassigned',
      isUnassigned: true,
    );
    final state = _buildState(
      now: DateTime(2026, 1, 2, 12),
      activities: [
        _activity(id: 'work', name: 'Work'),
        unassigned,
      ],
      unassignedActivity: unassigned,
      rangeEntries: [
        _entry(
          id: 'work',
          activityId: 'work',
          startAt: DateTime(2026, 1, 2, 9),
          endAt: DateTime(2026, 1, 2, 10),
        ),
      ],
    );

    final stats = await state.statsForRange(
      start: DateTime(2026, 1, 2),
      end: DateTime(2026, 1, 3),
    );

    expect(stats.totalDuration, const Duration(hours: 1));
    expect(stats.totalsByActivity.keys, ['work']);
    expect(stats.longestBlock, const Duration(hours: 1));
  });

  test('actionLogsForRange delegates through StatsState', () async {
    final log = _actionLog(id: 'log');
    final state = _buildState(actionLogs: [log]);

    final logs = await state.actionLogsForRange(
      start: DateTime(2026, 1, 2),
      end: DateTime(2026, 1, 3),
    );

    expect(logs, [log]);
  });

  test('longestBlockForPeriod all uses raw entry duration until now', () async {
    final state = _buildState(
      now: DateTime(2026, 1, 2, 12),
      allEntries: [
        _entry(
          id: 'running',
          activityId: 'work',
          startAt: DateTime(2026, 1, 2, 9),
          isRunning: true,
        ),
      ],
    );

    final longest = await state.longestBlockForPeriod(StatsPeriod.all);

    expect(longest, const Duration(hours: 3));
  });
}

StatsState _buildState({
  DateTime? selectedDay,
  DateTime? now,
  List<Activity> activities = const [],
  Activity? unassignedActivity,
  List<TimeEntry> dayEntries = const [],
  List<TimeEntry> rangeEntries = const [],
  List<ActionLog> actionLogs = const [],
  List<TimeEntry> allEntries = const [],
}) {
  return StatsState(
    selectedDay: () => selectedDay ?? DateTime(2026, 1, 2),
    now: () => now ?? DateTime(2026, 1, 2, 12),
    activities: () => activities,
    categories: () => const [],
    categoryLinks: () => const [],
    unassignedActivity: () => unassignedActivity,
    dayEntries: () => dayEntries,
    entriesForRange: ({required start, required end}) async => rangeEntries,
    actionLogsForRange: ({required start, required end}) async => actionLogs,
    allEntries: () async => allEntries,
  );
}

Activity _activity({
  required String id,
  required String name,
  bool isUnassigned = false,
}) {
  return Activity(
    id: id,
    userId: null,
    name: name,
    color: 0xff2563eb,
    isFavorite: true,
    updatedAt: DateTime(2026, 1, 1),
    isDeleted: false,
    isUnassigned: isUnassigned,
  );
}

ActionLog _actionLog({required String id}) {
  return ActionLog(
    id: id,
    userId: null,
    actionType: ActionType.switch_,
    activityId: 'work',
    entryId: 'entry',
    message: 'switch',
    occurredAt: DateTime(2026, 1, 2, 9),
    deviceId: 'test-device',
    updatedAt: DateTime(2026, 1, 2, 9),
    isDeleted: false,
  );
}

TimeEntry _entry({
  required String id,
  required String activityId,
  DateTime? startAt,
  DateTime? endAt,
  bool isDeleted = false,
  bool isRunning = false,
}) {
  final start = startAt ?? DateTime(2026, 1, 2, 9);
  return TimeEntry(
    id: id,
    userId: null,
    activityId: activityId,
    activityNameSnapshot: 'Activity',
    activityColorSnapshot: 0xff2563eb,
    startAt: start,
    endAt: isRunning ? null : endAt ?? DateTime(2026, 1, 2, 10),
    note: '',
    deviceId: 'test-device',
    updatedAt: start,
    isDeleted: isDeleted,
  );
}
