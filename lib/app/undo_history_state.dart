import '../data/repository_undo.dart';

class UndoHistoryState {
  final List<UndoHistoryEntry> _undoStack = [];
  final List<UndoHistoryEntry> _redoStack = [];
  var _batchDepth = 0;
  var _syncAfterBatch = false;
  var isBusy = false;

  bool get canUndo => !isBusy && _undoStack.isNotEmpty;

  bool get canRedo => !isBusy && _redoStack.isNotEmpty;

  String? get undoLabel => _undoStack.isEmpty ? null : _undoStack.last.label;

  String? get redoLabel => _redoStack.isEmpty ? null : _redoStack.last.label;

  RepositoryUndoChangeSet? get lastUndoChangeSet =>
      _undoStack.isEmpty ? null : _undoStack.last.changeSet;

  bool get isInBatch => _batchDepth > 0;

  bool beginBatch() {
    final isOuterBatch = _batchDepth == 0;
    _batchDepth += 1;
    return isOuterBatch;
  }

  void endBatch() {
    _batchDepth -= 1;
  }

  void pushUndo({
    required String label,
    required RepositoryUndoChangeSet changeSet,
  }) {
    _undoStack.add(UndoHistoryEntry(label: label, changeSet: changeSet));
    _redoStack.clear();
  }

  void markSyncAfterBatch() {
    _syncAfterBatch = true;
  }

  bool takeSyncAfterBatch() {
    final shouldSync = _syncAfterBatch;
    _syncAfterBatch = false;
    return shouldSync;
  }

  void clearSyncAfterBatch() {
    _syncAfterBatch = false;
  }

  UndoHistoryEntry? popUndo() {
    if (!canUndo) {
      return null;
    }
    return _undoStack.removeLast();
  }

  UndoHistoryEntry? popRedo() {
    if (!canRedo) {
      return null;
    }
    return _redoStack.removeLast();
  }

  void markUndoApplied(UndoHistoryEntry entry) {
    _redoStack.add(entry);
  }

  void markRedoApplied(UndoHistoryEntry entry) {
    _undoStack.add(entry);
  }

  void restore(UndoHistoryEntry entry, RepositoryUndoDirection direction) {
    if (direction == RepositoryUndoDirection.undo) {
      _undoStack.add(entry);
    } else {
      _redoStack.add(entry);
    }
  }
}

class UndoHistoryEntry {
  const UndoHistoryEntry({
    required this.label,
    required this.changeSet,
  });

  final String label;
  final RepositoryUndoChangeSet changeSet;
}
