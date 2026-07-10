part of 'time_repository.dart';

mixin TimeRepositoryEntryFacade {
  RepositoryEntryRepository get _entryFacade;

  Future<TimeEntry?> runningEntry() async {
    return _entryFacade.runningEntry();
  }

  Future<TimeEntry> switchToActivity(String activityId, {DateTime? at}) async {
    return _entryFacade.switchToActivity(activityId, at: at);
  }

  Future<void> stopRunning({DateTime? at}) async {
    await _entryFacade.stopRunning(at: at);
  }

  Future<List<TimeEntry>> saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  }) async {
    return _entryFacade.saveEntry(
      entry,
      logEdit: logEdit,
      cutOverlaps: cutOverlaps,
    );
  }

  Future<List<TimeEntry>> splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) async {
    return _entryFacade.splitEntry(
      entryId: entryId,
      splitAt: splitAt,
    );
  }

  Future<TimeEntry> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
    String? userId,
  }) async {
    return _entryFacade.createManualEntry(
      activityId: activityId,
      startAt: startAt,
      endAt: endAt,
      note: note,
      userId: userId,
    );
  }

  Future<void> deleteEntry(TimeEntry entry) async {
    await _entryFacade.deleteEntry(entry);
  }

  Future<List<TimeEntry>> entriesForDay(DateTime day) async {
    return _entryFacade.entriesForDay(day);
  }

  Future<List<TimeEntry>> entriesForRange(
    DateTime start,
    DateTime end,
  ) async {
    return _entryFacade.entriesForRange(start, end);
  }

  Future<List<TimeEntry>> entriesSince(DateTime since) async {
    return _entryFacade.entriesSince(since);
  }

  Future<List<TimeEntry>> allEntries() async {
    return _entryFacade.allEntries();
  }

  Future<EntryMergeCandidate?> mergeCandidateForEntry(
    String entryId,
    EntryMergeDirection direction,
  ) async {
    return _entryFacade.mergeCandidateForEntry(entryId, direction);
  }

  Future<TimeEntry?> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) async {
    return _entryFacade.mergeEntryWithNeighbor(
      entryId: entryId,
      direction: direction,
      confirmed: confirmed,
    );
  }

  Future<List<TimeEntry>> overlappingEntries(TimeEntry entry) async {
    return _entryFacade.overlappingEntries(entry);
  }

  Future<void> replaceEntryIfRemoteNewer(TimeEntry remote) async {
    await _entryFacade.replaceEntryIfRemoteNewer(remote);
  }

  Future<void> rolloverRunningEntriesIfNeeded({DateTime? at}) async {
    await _entryFacade.rolloverRunningEntriesIfNeeded(at: at);
  }

  Future<void> normalizeRunningEntriesAfterMerge() async {
    await _entryFacade.normalizeRunningEntriesAfterMerge();
  }

  Future<void> normalizeStoredCrossDayEntries() async {
    await _entryFacade.normalizeStoredCrossDayEntries();
  }

  Future<void> backfillMissingEntrySnapshots() async {
    await _entryFacade.backfillMissingEntrySnapshots();
  }
}
