part of 'app_state.dart';

mixin AppStateUndoFacade on ChangeNotifier {
  UndoCoordinatorState get _undoCoordinatorState;

  bool get canUndo => _undoCoordinatorState.canUndo;

  bool get canRedo => _undoCoordinatorState.canRedo;

  String? get undoLabel => _undoCoordinatorState.undoLabel;

  String? get redoLabel => _undoCoordinatorState.redoLabel;

  Future<T> runUndoBatch<T>(
    Future<T> Function() action, {
    String? label,
  }) {
    return _undoCoordinatorState.runBatch(action, label: label);
  }

  Future<void> undo() => _undoCoordinatorState.undo();

  Future<void> redo() => _undoCoordinatorState.redo();

  @visibleForTesting
  RepositoryUndoChangeSet? get lastUndoChangeSetForTest {
    return _undoCoordinatorState.lastUndoChangeSet;
  }
}
