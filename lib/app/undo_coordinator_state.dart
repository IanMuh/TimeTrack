import '../data/repository_undo.dart';
import '../data/time_repository.dart';
import '../domain/time_entry.dart';
import 'undo_scope_factory.dart';
import 'undo_state.dart';

class UndoCoordinatorState {
  UndoCoordinatorState({
    required TimeRepository repository,
    required UndoDateTimeReader selectedDay,
    required UndoDateTimeReader now,
    required UndoDateTimeReader systemNow,
    required UndoDateTimeReader operationNow,
    required UndoEntriesReader dayEntries,
    required UndoRunningEntryReader runningEntry,
    required UndoAsyncCallback refresh,
    required UndoAsyncCallback sync,
    required UndoErrorWriter setErrorMessage,
    required UndoStateChanged notifyListeners,
  }) : this.withHandlers(
          undoState: UndoState(
            loadSnapshot: repository.undoSnapshot,
            applyChangeSet: repository.applyUndoChangeSet,
            refresh: refresh,
            sync: sync,
            setErrorMessage: setErrorMessage,
            notifyListeners: notifyListeners,
          ),
          scopeFactory: UndoScopeFactory(
            selectedDay: selectedDay,
            now: now,
            systemNow: systemNow,
            operationNow: operationNow,
            dayEntries: dayEntries,
            runningEntry: runningEntry,
          ),
        );

  const UndoCoordinatorState.withHandlers({
    required UndoState undoState,
    required UndoScopeFactory scopeFactory,
  })  : _undoState = undoState,
        _scopeFactory = scopeFactory;

  final UndoState _undoState;
  final UndoScopeFactory _scopeFactory;

  bool get canUndo => _undoState.canUndo;

  bool get canRedo => _undoState.canRedo;

  String? get undoLabel => _undoState.undoLabel;

  String? get redoLabel => _undoState.redoLabel;

  RepositoryUndoChangeSet? get lastUndoChangeSet =>
      _undoState.lastUndoChangeSet;

  Future<T> runBatch<T>(
    Future<T> Function() action, {
    String? label,
  }) {
    return _undoState.runBatch(action, label: label);
  }

  Future<void> undo() => _undoState.undo();

  Future<void> redo() => _undoState.redo();

  Future<T> record<T>(
    String label,
    Future<T> Function() action, {
    bool syncAfter = true,
    RepositoryUndoScope? undoScope,
  }) {
    return _undoState.record(
      label,
      action,
      syncAfter: syncAfter,
      undoScope: undoScope,
    );
  }

  RepositoryUndoScope activeEntryScope() => _scopeFactory.activeEntryScope();

  RepositoryUndoScope entryScope(
    TimeEntry entry, {
    DateTime? fallbackEnd,
  }) {
    return _scopeFactory.entryScope(entry, fallbackEnd: fallbackEnd);
  }

  RepositoryUndoScope entryIdScope(
    String entryId, {
    List<DateTime> extraDays = const [],
  }) {
    return _scopeFactory.entryIdScope(entryId, extraDays: extraDays);
  }

  RepositoryUndoScope entryIntervalScope(
    DateTime start,
    DateTime end,
  ) {
    return _scopeFactory.entryIntervalScope(start, end);
  }
}
