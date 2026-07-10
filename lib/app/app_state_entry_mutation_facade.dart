part of 'app_state.dart';

mixin AppStateEntryMutationFacade on ChangeNotifier {
  EntryMutationState get _entryMutationState;

  Future<void> saveEntry(TimeEntry entry) {
    return _entryMutationState.saveEntry(entry);
  }

  Future<void> splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) {
    return _entryMutationState.splitEntry(entryId: entryId, splitAt: splitAt);
  }

  Future<void> extendEntryToNow(TimeEntry entry) {
    return _entryMutationState.extendEntryToNow(entry);
  }

  Future<void> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
  }) {
    return _entryMutationState.createManualEntry(
      activityId: activityId,
      startAt: startAt,
      endAt: endAt,
      note: note,
    );
  }

  Future<void> deleteEntry(TimeEntry entry) {
    return _entryMutationState.deleteEntry(entry);
  }

  Future<void> correctSuspiciousRunning(DateTime endAt) {
    return _entryMutationState.correctSuspiciousRunning(endAt);
  }

  Future<List<TimeEntry>> overlaps(TimeEntry entry) {
    return _entryMutationState.overlaps(entry);
  }

  Future<EntryMergeCandidate?> mergeCandidate(
    String entryId,
    EntryMergeDirection direction,
  ) {
    return _entryMutationState.mergeCandidate(entryId, direction);
  }

  Future<void> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) {
    return _entryMutationState.mergeEntryWithNeighbor(
      entryId: entryId,
      direction: direction,
      confirmed: confirmed,
    );
  }
}
