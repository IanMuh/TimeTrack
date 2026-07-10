import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/undo_state.dart';
import 'package:timetrack/data/repository_undo.dart';
import 'package:timetrack/domain/activity.dart';

void main() {
  test('record captures scoped changes and schedules sync', () async {
    var activity = _activity('Focus');
    final scopes = <RepositoryUndoScope?>[];
    var syncCount = 0;
    var notifyCount = 0;
    final state = _buildState(
      loadSnapshot: ({scope}) async {
        scopes.add(scope);
        return _snapshot(activity);
      },
      sync: () async {
        syncCount += 1;
      },
      notifyListeners: () {
        notifyCount += 1;
      },
    );
    final scope = RepositoryUndoScope(
      entryWindows: [
        RepositoryUndoWindow.forLocalDay(DateTime(2026, 1, 2)),
      ],
    );

    final result = await state.record(
      '编辑事项',
      () async {
        activity = _activity('Deep focus');
        return 42;
      },
      undoScope: scope,
    );

    expect(result, 42);
    expect(state.canUndo, isTrue);
    expect(state.undoLabel, '编辑事项');
    expect(state.lastUndoChangeSet?.activities.single.before?.name, 'Focus');
    expect(
        state.lastUndoChangeSet?.activities.single.after?.name, 'Deep focus');
    expect(scopes, [scope, scope]);
    expect(syncCount, 1);
    expect(notifyCount, 1);
  });

  test('runBatch merges nested records into one undo entry', () async {
    var activity = _activity('Focus');
    var syncCount = 0;
    final state = _buildState(
      loadSnapshot: ({scope}) async => _snapshot(activity),
      sync: () async {
        syncCount += 1;
      },
    );

    await state.runBatch(
      () async {
        await state.record('内部编辑', () async {
          activity = _activity('Deep focus');
        });
      },
      label: '批量编辑',
    );

    expect(state.canUndo, isTrue);
    expect(state.undoLabel, '批量编辑');
    expect(state.lastUndoChangeSet?.activities.single.before?.name, 'Focus');
    expect(
        state.lastUndoChangeSet?.activities.single.after?.name, 'Deep focus');
    expect(syncCount, 1);
  });

  test('undo applies change set and moves entry to redo stack', () async {
    var activity = _activity('Focus');
    RepositoryUndoDirection? appliedDirection;
    var refreshCount = 0;
    var syncCount = 0;
    final state = _buildState(
      loadSnapshot: ({scope}) async => _snapshot(activity),
      applyChangeSet: (changeSet, {required direction}) async {
        appliedDirection = direction;
      },
      refresh: () async {
        refreshCount += 1;
      },
      sync: () async {
        syncCount += 1;
      },
    );
    await state.record('编辑事项', () async {
      activity = _activity('Deep focus');
    });

    await state.undo();

    expect(appliedDirection, RepositoryUndoDirection.undo);
    expect(state.canUndo, isFalse);
    expect(state.canRedo, isTrue);
    expect(refreshCount, 1);
    expect(syncCount, 2);
  });

  test('undo conflict restores entry and exposes error', () async {
    var activity = _activity('Focus');
    String? errorMessage;
    var refreshCount = 0;
    final state = _buildState(
      loadSnapshot: ({scope}) async => _snapshot(activity),
      applyChangeSet: (changeSet, {required direction}) async {
        throw const RepositoryUndoConflictException('conflict');
      },
      refresh: () async {
        refreshCount += 1;
      },
      setErrorMessage: (message) {
        errorMessage = message;
      },
    );
    await state.record(
      '编辑事项',
      () async {
        activity = _activity('Deep focus');
      },
      syncAfter: false,
    );

    await state.undo();

    expect(errorMessage, 'conflict');
    expect(state.canUndo, isTrue);
    expect(state.canRedo, isFalse);
    expect(refreshCount, 1);
  });
}

UndoState _buildState({
  required UndoSnapshotLoader loadSnapshot,
  UndoChangeSetApplier? applyChangeSet,
  UndoAsyncCallback? refresh,
  UndoAsyncCallback? sync,
  UndoErrorWriter? setErrorMessage,
  UndoStateChanged? notifyListeners,
}) {
  return UndoState(
    loadSnapshot: loadSnapshot,
    applyChangeSet:
        applyChangeSet ?? (changeSet, {required direction}) async {},
    refresh: refresh ?? () async {},
    sync: sync ?? () async {},
    setErrorMessage: setErrorMessage ?? (_) {},
    notifyListeners: notifyListeners ?? () {},
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
