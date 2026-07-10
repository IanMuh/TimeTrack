part of 'time_repository.dart';

mixin TimeRepositoryUndoFacade {
  RepositoryUndoRepository get _undoRepo;

  Future<RepositoryUndoSnapshot> undoSnapshot({
    RepositoryUndoScope? scope,
  }) async {
    return _undoRepo.undoSnapshot(scope: scope);
  }

  Future<void> applyUndoChangeSet(
    RepositoryUndoChangeSet changeSet, {
    required RepositoryUndoDirection direction,
  }) async {
    await _undoRepo.applyUndoChangeSet(changeSet, direction: direction);
  }
}
