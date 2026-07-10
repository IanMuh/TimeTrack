import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/undo_history_state.dart';
import 'package:timetrack/data/repository_undo.dart';

void main() {
  test('pushUndo exposes labels and clears redo stack', () {
    final state = UndoHistoryState();
    final first = _changeSet('补记时间段');
    final second = _changeSet('删除时间段');

    state.pushUndo(label: first.label, changeSet: first);
    final undoEntry = state.popUndo()!;
    state.markUndoApplied(undoEntry);

    expect(state.canRedo, isTrue);
    expect(state.redoLabel, first.label);

    state.pushUndo(label: second.label, changeSet: second);

    expect(state.canUndo, isTrue);
    expect(state.canRedo, isFalse);
    expect(state.undoLabel, second.label);
    expect(state.lastUndoChangeSet, same(second));
  });

  test('pop undo and redo are disabled while busy', () {
    final state = UndoHistoryState()
      ..pushUndo(label: '编辑时间段', changeSet: _changeSet('编辑时间段'))
      ..isBusy = true;

    expect(state.canUndo, isFalse);
    expect(state.popUndo(), isNull);

    state.isBusy = false;

    final entry = state.popUndo();
    expect(entry?.label, '编辑时间段');
    state.markUndoApplied(entry!);

    state.isBusy = true;

    expect(state.canRedo, isFalse);
    expect(state.popRedo(), isNull);
  });

  test('restore puts failed entries back on the source stack', () {
    final state = UndoHistoryState();
    final entry = UndoHistoryEntry(
      label: '编辑事项',
      changeSet: _changeSet('编辑事项'),
    );

    state.restore(entry, RepositoryUndoDirection.undo);

    expect(state.canUndo, isTrue);
    expect(state.undoLabel, '编辑事项');

    final popped = state.popUndo()!;
    state.markUndoApplied(popped);
    state.restore(popped, RepositoryUndoDirection.redo);

    expect(state.canRedo, isTrue);
    expect(state.redoLabel, '编辑事项');
  });

  test('batch depth and pending sync flag are tracked together', () {
    final state = UndoHistoryState();

    expect(state.beginBatch(), isTrue);
    expect(state.isInBatch, isTrue);
    expect(state.beginBatch(), isFalse);

    state.markSyncAfterBatch();
    state.endBatch();

    expect(state.isInBatch, isTrue);
    expect(state.takeSyncAfterBatch(), isTrue);
    expect(state.takeSyncAfterBatch(), isFalse);

    state.markSyncAfterBatch();
    state.clearSyncAfterBatch();
    state.endBatch();

    expect(state.isInBatch, isFalse);
    expect(state.takeSyncAfterBatch(), isFalse);
  });
}

RepositoryUndoChangeSet _changeSet(String label) {
  return RepositoryUndoChangeSet(
    label: label,
    activities: const [],
    categories: const [],
    categoryLinks: const [],
    timeEntries: const [],
    actionLogs: const [],
  );
}
