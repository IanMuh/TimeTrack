import '../core/result.dart';
import '../domain/time_entry.dart';
import 'repository_interfaces.dart';
import 'repository_result.dart';
import 'time_entry_repository.dart';

class RepositoryEntryRepository {
  RepositoryEntryRepository({
    required TimeEntryRepository entryRepository,
  }) : _entryRepo = entryRepository;

  final TimeEntryRepository _entryRepo;

  Future<TimeEntry?> runningEntry() async {
    final result = await _entryRepo.runningEntry();
    return _unwrap(result);
  }

  Future<TimeEntry> switchToActivity(String activityId, {DateTime? at}) async {
    final result = await _entryRepo.switchToActivity(activityId, at: at);
    return _unwrap(result);
  }

  Future<void> stopRunning({DateTime? at}) async {
    final result = await _entryRepo.stopRunning(at: at);
    _unwrap(result);
  }

  Future<List<TimeEntry>> saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  }) async {
    final result = await _entryRepo.saveEntry(
      entry,
      logEdit: logEdit,
      cutOverlaps: cutOverlaps,
    );
    return _unwrap(result);
  }

  Future<List<TimeEntry>> splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) async {
    final result = await _entryRepo.splitEntry(
      entryId: entryId,
      splitAt: splitAt,
    );
    return _unwrap(result);
  }

  Future<TimeEntry> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
    String? userId,
  }) async {
    final result = await _entryRepo.createManualEntry(
      activityId: activityId,
      startAt: startAt,
      endAt: endAt,
      note: note,
      userId: userId,
    );
    return _unwrap(result);
  }

  Future<void> deleteEntry(TimeEntry entry) async {
    final result = await _entryRepo.deleteEntry(entry);
    _unwrap(result);
  }

  Future<List<TimeEntry>> entriesForDay(DateTime day) async {
    final result = await _entryRepo.entriesForDay(day);
    return _unwrap(result);
  }

  Future<List<TimeEntry>> entriesForRange(
    DateTime start,
    DateTime end,
  ) async {
    final result = await _entryRepo.entriesForRange(start, end);
    return _unwrap(result);
  }

  Future<List<TimeEntry>> entriesSince(DateTime since) async {
    final result = await _entryRepo.entriesSince(since);
    return _unwrap(result);
  }

  Future<List<TimeEntry>> allEntries() async {
    final result = await _entryRepo.allEntries();
    return _unwrap(result);
  }

  Future<EntryMergeCandidate?> mergeCandidateForEntry(
    String entryId,
    EntryMergeDirection direction,
  ) async {
    final result = await _entryRepo.mergeCandidateForEntry(entryId, direction);
    return _unwrap(result);
  }

  Future<TimeEntry?> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) async {
    final result = await _entryRepo.mergeEntryWithNeighbor(
      entryId: entryId,
      direction: direction,
      confirmed: confirmed,
    );
    return _unwrap(result);
  }

  Future<List<TimeEntry>> overlappingEntries(TimeEntry entry) async {
    final result = await _entryRepo.overlappingEntries(entry);
    return _unwrap(result);
  }

  Future<void> replaceEntryIfRemoteNewer(TimeEntry remote) async {
    final result = await _entryRepo.replaceEntryIfRemoteNewer(remote);
    _unwrap(result);
  }

  Future<void> rolloverRunningEntriesIfNeeded({DateTime? at}) async {
    await _entryRepo.rolloverRunningEntriesIfNeeded(at: at);
  }

  Future<void> normalizeRunningEntriesAfterMerge() async {
    await _entryRepo.normalizeRunningEntriesAfterMerge();
  }

  Future<void> normalizeStoredCrossDayEntries() async {
    await _entryRepo.normalizeStoredCrossDayEntries();
  }

  Future<void> backfillMissingEntrySnapshots() async {
    await _entryRepo.backfillMissingEntrySnapshots();
  }

  T _unwrap<T>(AppResult<T> result) {
    return unwrapRepositoryResult(result);
  }
}
