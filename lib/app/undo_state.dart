import 'dart:async';

import '../data/repository_undo.dart';
import 'undo_history_state.dart';

typedef UndoSnapshotLoader = Future<RepositoryUndoSnapshot> Function({
  RepositoryUndoScope? scope,
});
typedef UndoChangeSetApplier = Future<void> Function(
  RepositoryUndoChangeSet changeSet, {
  required RepositoryUndoDirection direction,
});
typedef UndoAsyncCallback = Future<void> Function();
typedef UndoStateChanged = void Function();
typedef UndoErrorWriter = void Function(String? message);
typedef UndoableRecorder = Future<T> Function<T>(
  String label,
  Future<T> Function() action, {
  bool syncAfter,
  RepositoryUndoScope? undoScope,
});

class UndoState {
  UndoState({
    required UndoSnapshotLoader loadSnapshot,
    required UndoChangeSetApplier applyChangeSet,
    required UndoAsyncCallback refresh,
    required UndoAsyncCallback sync,
    required UndoErrorWriter setErrorMessage,
    required UndoStateChanged notifyListeners,
    UndoHistoryState? history,
  })  : _loadSnapshot = loadSnapshot,
        _applyChangeSet = applyChangeSet,
        _refresh = refresh,
        _sync = sync,
        _setErrorMessage = setErrorMessage,
        _notifyListeners = notifyListeners,
        _history = history ?? UndoHistoryState();

  final UndoSnapshotLoader _loadSnapshot;
  final UndoChangeSetApplier _applyChangeSet;
  final UndoAsyncCallback _refresh;
  final UndoAsyncCallback _sync;
  final UndoErrorWriter _setErrorMessage;
  final UndoStateChanged _notifyListeners;
  final UndoHistoryState _history;

  bool get canUndo => _history.canUndo;

  bool get canRedo => _history.canRedo;

  String? get undoLabel => _history.undoLabel;

  String? get redoLabel => _history.redoLabel;

  RepositoryUndoChangeSet? get lastUndoChangeSet => _history.lastUndoChangeSet;

  Future<T> runBatch<T>(
    Future<T> Function() action, {
    String? label,
  }) async {
    final isOuterBatch = _history.beginBatch();
    final before = isOuterBatch ? await _loadSnapshot() : null;
    var succeeded = false;
    try {
      final result = await action();
      succeeded = true;
      return result;
    } finally {
      _history.endBatch();
      if (isOuterBatch && succeeded) {
        final after = await _loadSnapshot();
        final mergedLabel = label ?? '编辑时间段';
        final changeSet = before!.diff(label: mergedLabel, after: after);
        if (!changeSet.isEmpty) {
          _history.pushUndo(label: mergedLabel, changeSet: changeSet);
          _notifyListeners();
        }
        if (_history.takeSyncAfterBatch()) {
          unawaited(_sync());
        }
      } else if (isOuterBatch) {
        _history.clearSyncAfterBatch();
      }
    }
  }

  Future<T> record<T>(
    String label,
    Future<T> Function() action, {
    bool syncAfter = true,
    RepositoryUndoScope? undoScope,
  }) async {
    if (_history.isInBatch) {
      final result = await action();
      if (syncAfter) {
        _history.markSyncAfterBatch();
      }
      return result;
    }

    final before = await _loadSnapshot(scope: undoScope);
    final result = await action();
    final after = await _loadSnapshot(scope: undoScope);
    final changeSet = before.diff(label: label, after: after);
    if (!changeSet.isEmpty) {
      _history.pushUndo(label: label, changeSet: changeSet);
      _notifyListeners();
    }
    if (syncAfter) {
      unawaited(_sync());
    }
    return result;
  }

  Future<void> undo() async {
    final entry = _history.popUndo();
    if (entry == null) {
      return;
    }
    if (await _applyHistoryEntry(entry, RepositoryUndoDirection.undo)) {
      _history.markUndoApplied(entry);
      _notifyListeners();
    }
  }

  Future<void> redo() async {
    final entry = _history.popRedo();
    if (entry == null) {
      return;
    }
    if (await _applyHistoryEntry(entry, RepositoryUndoDirection.redo)) {
      _history.markRedoApplied(entry);
      _notifyListeners();
    }
  }

  Future<bool> _applyHistoryEntry(
    UndoHistoryEntry entry,
    RepositoryUndoDirection direction,
  ) async {
    _history.isBusy = true;
    _notifyListeners();
    try {
      await _applyChangeSet(entry.changeSet, direction: direction);
      await _refresh();
      await _sync();
      _setErrorMessage(null);
      return true;
    } on RepositoryUndoConflictException catch (error) {
      _setErrorMessage(error.message);
      _history.restore(entry, direction);
      await _refresh();
      return false;
    } catch (error) {
      _setErrorMessage('操作失败：$error');
      _history.restore(entry, direction);
      await _refresh();
      return false;
    } finally {
      _history.isBusy = false;
      _notifyListeners();
    }
  }
}
