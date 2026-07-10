import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/undo_coordinator_state.dart';
import 'package:timetrack/app/undo_scope_factory.dart';
import 'package:timetrack/app/undo_state.dart';
import 'package:timetrack/data/repository_undo.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/time_entry.dart';

void main() {
  test('AppState undo facade stays separate from runtime facade', () {
    final undoFacade = File('lib/app/app_state_undo_facade.dart');
    final runtimeFacade = File('lib/app/app_state_runtime_facade.dart');
    final entryFacade = File('lib/app/app_state_entry_facade.dart');

    expect(undoFacade.existsSync(), isTrue);

    final undoSource = undoFacade.readAsStringSync();
    final runtimeSource = runtimeFacade.readAsStringSync();
    final entrySource = entryFacade.readAsStringSync();

    expect(undoSource, contains('mixin AppStateUndoFacade'));
    expect(undoSource, contains('bool get canUndo'));
    expect(undoSource, contains('bool get canRedo'));
    expect(undoSource, contains('String? get undoLabel'));
    expect(undoSource, contains('String? get redoLabel'));
    expect(undoSource, contains('Future<T> runUndoBatch<T>('));
    expect(undoSource, contains('Future<void> undo()'));
    expect(undoSource, contains('Future<void> redo()'));
    expect(
      undoSource,
      contains('RepositoryUndoChangeSet? get lastUndoChangeSetForTest'),
    );
    expect(runtimeSource, isNot(contains('bool get canUndo')));
    expect(runtimeSource, isNot(contains('bool get canRedo')));
    expect(runtimeSource, isNot(contains('String? get undoLabel')));
    expect(runtimeSource, isNot(contains('String? get redoLabel')));
    expect(
      runtimeSource,
      isNot(contains('RepositoryUndoChangeSet? get lastUndoChangeSetForTest')),
    );
    expect(entrySource, isNot(contains('Future<T> runUndoBatch<T>(')));
    expect(entrySource, isNot(contains('Future<void> undo()')));
    expect(entrySource, isNot(contains('Future<void> redo()')));
  });

  test('record delegates through undo state and exposes history', () async {
    var activity = _activity('Focus');
    final scopes = <RepositoryUndoScope?>[];
    var syncCount = 0;
    final coordinator = _buildCoordinator(
      loadSnapshot: ({scope}) async {
        scopes.add(scope);
        return _snapshot(activity);
      },
      sync: () async {
        syncCount += 1;
      },
    );
    final scope = coordinator.entryScope(_entry());

    final result = await coordinator.record(
      '编辑事项',
      () async {
        activity = _activity('Deep focus');
        return 42;
      },
      undoScope: scope,
    );

    expect(result, 42);
    expect(coordinator.canUndo, isTrue);
    expect(coordinator.undoLabel, '编辑事项');
    expect(
        coordinator.lastUndoChangeSet?.activities.single.before?.name, 'Focus');
    expect(coordinator.lastUndoChangeSet?.activities.single.after?.name,
        'Deep focus');
    expect(scopes, [scope, scope]);
    expect(syncCount, 1);
  });

  test('entry id scope delegates to scope factory', () {
    final loaded = _entry(id: 'entry-1');
    final coordinator = _buildCoordinator(dayEntries: [loaded]);

    final scope = coordinator.entryIdScope(
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
}

UndoCoordinatorState _buildCoordinator({
  UndoSnapshotLoader? loadSnapshot,
  List<TimeEntry> dayEntries = const [],
  TimeEntry? runningEntry,
  UndoAsyncCallback? sync,
}) {
  return UndoCoordinatorState.withHandlers(
    undoState: UndoState(
      loadSnapshot: loadSnapshot ?? ({scope}) async => _snapshot(_activity('')),
      applyChangeSet: (changeSet, {required direction}) async {},
      refresh: () async {},
      sync: sync ?? () async {},
      setErrorMessage: (_) {},
      notifyListeners: () {},
    ),
    scopeFactory: UndoScopeFactory(
      selectedDay: () => DateTime(2026, 1, 2),
      now: () => DateTime(2026, 1, 3),
      systemNow: () => DateTime(2026, 1, 4),
      operationNow: () => DateTime(2026, 1, 5),
      dayEntries: () => dayEntries,
      runningEntry: () => runningEntry,
    ),
  );
}

RepositoryUndoSnapshot _snapshot(Activity activity) {
  return RepositoryUndoSnapshot(
    activities: {activity.id: activity},
    categories: const {},
    categoryLinks: const {},
    timeEntries: const {},
    actionLogs: const {},
  );
}

Activity _activity(String name) {
  return Activity(
    id: 'activity',
    userId: null,
    name: name,
    color: 0xff2563eb,
    isFavorite: true,
    updatedAt: DateTime(2026, 1, 2),
    isDeleted: false,
  );
}

TimeEntry _entry({String id = 'entry'}) {
  return TimeEntry(
    id: id,
    userId: null,
    activityId: 'activity',
    activityNameSnapshot: 'Activity',
    activityColorSnapshot: 0xff2563eb,
    startAt: DateTime(2026, 1, 2, 9),
    endAt: DateTime(2026, 1, 2, 10),
    note: '',
    deviceId: 'test-device',
    updatedAt: DateTime(2026, 1, 2, 9),
    isDeleted: false,
  );
}
