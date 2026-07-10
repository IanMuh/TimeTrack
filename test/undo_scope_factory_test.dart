import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/undo_scope_factory.dart';
import 'package:timetrack/domain/time_entry.dart';

void main() {
  test('activeEntryScope includes running entry and anchor days', () {
    final selectedDay = DateTime(2026, 1, 2, 10);
    final appNow = DateTime(2026, 1, 3, 9);
    final systemNow = DateTime(2026, 1, 4, 8);
    final operationNow = DateTime(2026, 1, 3, 10);
    final running = _entry(
      id: 'running',
      startAt: DateTime(2026, 1, 1, 23, 30),
      endAt: null,
    );
    final factory = UndoScopeFactory(
      selectedDay: () => selectedDay,
      now: () => appNow,
      systemNow: () => systemNow,
      operationNow: () => operationNow,
      dayEntries: () => const [],
      runningEntry: () => running,
    );

    final scope = factory.activeEntryScope();

    expect(
      scope.entryWindows.map((window) => window.start),
      [
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 3),
        DateTime(2026, 1, 4),
      ],
    );
    expect(
      scope.entryWindows.map((window) => window.end),
      [
        DateTime(2026, 1, 4),
        DateTime(2026, 1, 3),
        DateTime(2026, 1, 4),
        DateTime(2026, 1, 5),
      ],
    );
    expect(scope.actionLogWindows, scope.entryWindows);
  });

  test('entryIdScope uses loaded entry and extra days', () {
    final loaded = _entry(
      id: 'entry-1',
      startAt: DateTime(2026, 1, 2, 9),
      endAt: DateTime(2026, 1, 2, 10),
    );
    final factory = _factory(
      dayEntries: [loaded],
      operationNow: DateTime(2026, 1, 5),
    );

    final scope = factory.entryIdScope(
      'entry-1',
      extraDays: [DateTime(2026, 1, 7, 12)],
    );

    expect(
      scope.entryWindows.map((window) => window.start),
      [
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 7),
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 3),
        DateTime(2026, 1, 4),
      ],
    );
  });

  test('entryIntervalScope covers the full local-day span', () {
    final factory = _factory();

    final scope = factory.entryIntervalScope(
      DateTime(2026, 1, 2, 23, 30),
      DateTime(2026, 1, 4, 0, 15),
    );

    expect(scope.entryWindows.first.start, DateTime(2026, 1, 2));
    expect(scope.entryWindows.first.end, DateTime(2026, 1, 5));
  });

  test('entryIdScope falls back to the running entry when day entries miss',
      () {
    final running = _entry(
      id: 'running',
      startAt: DateTime(2026, 1, 2, 9),
      endAt: null,
    );
    final factory = _factory(
      runningEntry: running,
      operationNow: DateTime(2026, 1, 2, 11),
    );

    final scope = factory.entryIdScope('running');

    expect(scope.entryWindows.first.start, DateTime(2026, 1, 2));
    expect(scope.entryWindows.first.end, DateTime(2026, 1, 3));
  });
}

UndoScopeFactory _factory({
  List<TimeEntry> dayEntries = const [],
  TimeEntry? runningEntry,
  DateTime? operationNow,
}) {
  return UndoScopeFactory(
    selectedDay: () => DateTime(2026, 1, 2),
    now: () => DateTime(2026, 1, 3),
    systemNow: () => DateTime(2026, 1, 4),
    operationNow: () => operationNow ?? DateTime(2026, 1, 5),
    dayEntries: () => dayEntries,
    runningEntry: () => runningEntry,
  );
}

TimeEntry _entry({
  required String id,
  required DateTime startAt,
  required DateTime? endAt,
}) {
  return TimeEntry(
    id: id,
    userId: null,
    activityId: 'activity-1',
    activityNameSnapshot: 'Activity',
    activityColorSnapshot: 0xff2563eb,
    startAt: startAt,
    endAt: endAt,
    note: '',
    deviceId: 'test-device',
    updatedAt: startAt,
    isDeleted: false,
  );
}
