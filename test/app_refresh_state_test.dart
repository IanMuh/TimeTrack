import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/app_refresh_state.dart';
import 'package:timetrack/domain/action_log.dart';
import 'package:timetrack/domain/time_entry.dart';

void main() {
  test('refresh coordinates full state reload and increments revision',
      () async {
    final harness = _RefreshHarness(
      initialSelectedDay: DateTime(2026, 1, 2),
      initialNow: DateTime(2026, 1, 2, 12),
      loadedActionLogs: [_log('log-1')],
      loadedRunningEntry: _entry('running', DateTime(2026, 1, 2, 10)),
    );

    await harness.state.refresh();

    expect(harness.state.dataRevision, 1);
    expect(harness.order, [
      'rollover:2026-01-02 12:00:00.000',
      'activities:false',
      'categories',
      'settings',
      'lanPeer',
      'syncStatus',
      'entries:2026-01-02 00:00:00.000:false',
      'logs:2026-01-02 00:00:00.000',
      'setLogs:1',
      'running',
      'setRunning:running',
      'notify',
    ]);
  });

  test('selectDay updates the selected day and refreshes daily data only',
      () async {
    final harness = _RefreshHarness(
      initialSelectedDay: DateTime(2026, 1, 1),
      initialNow: DateTime(2026, 1, 2, 12),
    );

    await harness.state.selectDay(DateTime(2026, 1, 3));

    expect(harness.state.selectedDay, DateTime(2026, 1, 3));
    expect(harness.state.dataRevision, 1);
    expect(harness.order, [
      'rollover:2026-01-02 12:00:00.000',
      'entries:2026-01-03 00:00:00.000:false',
      'logs:2026-01-03 00:00:00.000',
      'setLogs:0',
      'running',
      'setRunning:null',
      'notify',
    ]);
  });

  test('rolloverRunningEntryIfNeeded refreshes stale running entries',
      () async {
    final harness = _RefreshHarness(
      initialSelectedDay: DateTime(2026, 1, 2),
      initialNow: DateTime(2026, 1, 2, 12),
      currentRunningEntry: _entry('stale', DateTime(2026, 1, 1, 23)),
    );

    await harness.state.rolloverRunningEntryIfNeeded();

    expect(harness.state.dataRevision, 1);
    expect(harness.order.first, 'rollover:2026-01-02 12:00:00.000');
    expect(harness.order, contains('activities:false'));
    expect(harness.order.last, 'notify');
  });

  test('rolloverRunningEntryIfNeeded ignores same-day running entries',
      () async {
    final harness = _RefreshHarness(
      initialSelectedDay: DateTime(2026, 1, 2),
      initialNow: DateTime(2026, 1, 2, 12),
      currentRunningEntry: _entry('current', DateTime(2026, 1, 2, 8)),
    );

    await harness.state.rolloverRunningEntryIfNeeded();

    expect(harness.state.dataRevision, 0);
    expect(harness.order, isEmpty);
  });
}

class _RefreshHarness {
  _RefreshHarness({
    required DateTime initialSelectedDay,
    required DateTime initialNow,
    List<ActionLog> loadedActionLogs = const [],
    TimeEntry? loadedRunningEntry,
    TimeEntry? currentRunningEntry,
  })  : _loadedActionLogs = loadedActionLogs,
        _loadedRunningEntry = loadedRunningEntry,
        _currentRunningEntry = currentRunningEntry {
    state = AppRefreshState.withHandlers(
      initialSelectedDay: initialSelectedDay,
      initialNow: initialNow,
      rolloverRunningEntriesIfNeeded: ({DateTime? at}) async {
        order.add('rollover:$at');
      },
      refreshActivities: ({bool notify = true}) async {
        order.add('activities:$notify');
      },
      refreshCategories: () async {
        order.add('categories');
      },
      refreshSettings: () async {
        order.add('settings');
      },
      loadLanPeer: () async {
        order.add('lanPeer');
      },
      loadSyncStatus: () async {
        order.add('syncStatus');
      },
      refreshEntries: (day, {bool notify = true}) async {
        order.add('entries:$day:$notify');
      },
      loadActionLogsForDay: (day) async {
        order.add('logs:$day');
        return _loadedActionLogs;
      },
      setActionLogs: (logs) {
        order.add('setLogs:${logs.length}');
      },
      loadRunningEntry: () async {
        order.add('running');
        return _loadedRunningEntry;
      },
      setRunningEntry: (entry) {
        order.add('setRunning:${entry?.id ?? 'null'}');
      },
      runningEntry: () => _currentRunningEntry,
      notifyListeners: () {
        order.add('notify');
      },
    );
  }

  final List<String> order = [];
  final List<ActionLog> _loadedActionLogs;
  final TimeEntry? _loadedRunningEntry;
  final TimeEntry? _currentRunningEntry;
  late final AppRefreshState state;
}

ActionLog _log(String id) {
  final now = DateTime(2026, 1, 2, 12);
  return ActionLog(
    id: id,
    userId: null,
    actionType: ActionType.switch_,
    activityId: 'activity',
    entryId: null,
    message: 'switch',
    occurredAt: now,
    deviceId: 'device',
    updatedAt: now,
    isDeleted: false,
  );
}

TimeEntry _entry(String id, DateTime startAt) {
  return TimeEntry(
    id: id,
    userId: null,
    activityId: 'activity',
    startAt: startAt,
    endAt: null,
    note: '',
    deviceId: 'device',
    updatedAt: startAt,
    isDeleted: false,
  );
}
