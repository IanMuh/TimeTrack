part of 'time_entry_repository.dart';

mixin TimeEntryRepositoryResultFacade {
  Future<TimeEntry?> _runningEntry();
  Future<TimeEntry> _switchToActivity(String activityId, {DateTime? at});
  Future<void> _stopRunning({DateTime? at});
  Future<List<TimeEntry>> _saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  });
  Future<List<TimeEntry>> _splitEntry({
    required String entryId,
    required DateTime splitAt,
  });
  Future<TimeEntry> _createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
    String? userId,
  });
  Future<void> _deleteEntry(TimeEntry entry);
  Future<List<TimeEntry>> _entriesForDay(DateTime day);
  Future<List<TimeEntry>> _entriesForRange(DateTime start, DateTime end);
  Future<List<TimeEntry>> _entriesSince(DateTime since);
  Future<List<TimeEntry>> _allEntries();
  Future<EntryMergeCandidate?> _mergeCandidateForEntry(
    String entryId,
    EntryMergeDirection direction,
  );
  Future<TimeEntry?> _mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  });
  Future<List<TimeEntry>> _overlappingEntries(TimeEntry entry);
  Future<void> _replaceEntryIfRemoteNewer(TimeEntry remote);

  Future<AppResult<TimeEntry?>> runningEntry() async {
    try {
      return AppSuccess(await _runningEntry());
    } catch (e) {
      return AppFailure('Failed to get running entry: $e');
    }
  }

  Future<AppResult<TimeEntry>> switchToActivity(
    String activityId, {
    DateTime? at,
  }) async {
    try {
      return AppSuccess(await _switchToActivity(activityId, at: at));
    } catch (e) {
      return AppFailure('Failed to switch activity: $e');
    }
  }

  Future<AppResult<void>> stopRunning({DateTime? at}) async {
    try {
      await _stopRunning(at: at);
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to stop running: $e');
    }
  }

  Future<AppResult<List<TimeEntry>>> saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  }) async {
    try {
      return AppSuccess(
        await _saveEntry(entry, logEdit: logEdit, cutOverlaps: cutOverlaps),
      );
    } catch (e) {
      return AppFailure('Failed to save entry: $e');
    }
  }

  Future<AppResult<List<TimeEntry>>> splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) async {
    try {
      return AppSuccess(await _splitEntry(entryId: entryId, splitAt: splitAt));
    } catch (e) {
      return AppFailure('Failed to split entry: $e');
    }
  }

  Future<AppResult<TimeEntry>> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
    String? userId,
  }) async {
    try {
      return AppSuccess(
        await _createManualEntry(
          activityId: activityId,
          startAt: startAt,
          endAt: endAt,
          note: note,
          userId: userId,
        ),
      );
    } catch (e) {
      return AppFailure('Failed to create manual entry: $e');
    }
  }

  Future<AppResult<void>> deleteEntry(TimeEntry entry) async {
    try {
      await _deleteEntry(entry);
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to delete entry: $e');
    }
  }

  Future<AppResult<List<TimeEntry>>> entriesForDay(DateTime day) async {
    try {
      return AppSuccess(await _entriesForDay(day));
    } catch (e) {
      return AppFailure('Failed to load entries for day: $e');
    }
  }

  Future<AppResult<List<TimeEntry>>> entriesForRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      return AppSuccess(await _entriesForRange(start, end));
    } catch (e) {
      return AppFailure('Failed to load entries for range: $e');
    }
  }

  Future<AppResult<List<TimeEntry>>> entriesSince(DateTime since) async {
    try {
      return AppSuccess(await _entriesSince(since));
    } catch (e) {
      return AppFailure('Failed to load entries since: $e');
    }
  }

  Future<AppResult<List<TimeEntry>>> allEntries() async {
    try {
      return AppSuccess(await _allEntries());
    } catch (e) {
      return AppFailure('Failed to load all entries: $e');
    }
  }

  Future<AppResult<EntryMergeCandidate?>> mergeCandidateForEntry(
    String entryId,
    EntryMergeDirection direction,
  ) async {
    try {
      return AppSuccess(
        await _mergeCandidateForEntry(entryId, direction),
      );
    } catch (e) {
      return AppFailure('Failed to find merge candidate: $e');
    }
  }

  Future<AppResult<TimeEntry?>> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) async {
    try {
      return AppSuccess(
        await _mergeEntryWithNeighbor(
          entryId: entryId,
          direction: direction,
          confirmed: confirmed,
        ),
      );
    } catch (e) {
      return AppFailure('Failed to merge entry: $e');
    }
  }

  Future<AppResult<List<TimeEntry>>> overlappingEntries(TimeEntry entry) async {
    try {
      return AppSuccess(await _overlappingEntries(entry));
    } catch (e) {
      return AppFailure('Failed to find overlapping entries: $e');
    }
  }

  Future<AppResult<void>> replaceEntryIfRemoteNewer(TimeEntry remote) async {
    try {
      await _replaceEntryIfRemoteNewer(remote);
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to replace entry: $e');
    }
  }
}
