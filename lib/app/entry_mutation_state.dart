import '../data/repository_undo.dart';
import '../data/repository_interfaces.dart';
import '../domain/time_entry.dart';
import 'entry_state.dart';
import 'undo_state.dart';

typedef EntryUndoScopeBuilder = RepositoryUndoScope Function(
  TimeEntry entry, {
  DateTime? fallbackEnd,
});
typedef EntryIdUndoScopeBuilder = RepositoryUndoScope Function(
  String entryId, {
  required List<DateTime> extraDays,
});
typedef EntryIntervalUndoScopeBuilder = RepositoryUndoScope Function(
  DateTime start,
  DateTime end,
);
typedef EntryDateReader = DateTime Function();
typedef RunningEntryReader = TimeEntry? Function();
typedef EntryAction = Future<void> Function();
typedef EntrySaver = Future<void> Function(TimeEntry entry);
typedef EntrySplitter = Future<void> Function({
  required String entryId,
  required DateTime splitAt,
});
typedef EntryExtender = Future<void> Function(TimeEntry entry);
typedef ManualEntryCreator = Future<void> Function({
  required String activityId,
  required DateTime startAt,
  required DateTime endAt,
  required String note,
});
typedef EntryDeleter = Future<void> Function(TimeEntry entry);
typedef SuspiciousEntryCorrector = Future<void> Function(DateTime endAt);
typedef EntryOverlapLoader = Future<List<TimeEntry>> Function(TimeEntry entry);
typedef EntryMergeCandidateLoader = Future<EntryMergeCandidate?> Function(
  String entryId,
  EntryMergeDirection direction,
);
typedef EntryNeighborMerger = Future<void> Function({
  required String entryId,
  required EntryMergeDirection direction,
  required bool confirmed,
});

class EntryMutationState {
  EntryMutationState({
    required EntryState entryState,
    required EntryDateReader now,
    required RunningEntryReader runningEntry,
    required UndoableRecorder recordUndoable,
    required EntryUndoScopeBuilder entryUndoScope,
    required EntryIdUndoScopeBuilder entryIdUndoScope,
    required EntryIntervalUndoScopeBuilder entryIntervalUndoScope,
  }) : this.withHandlers(
          now: now,
          runningEntry: runningEntry,
          recordUndoable: recordUndoable,
          entryUndoScope: entryUndoScope,
          entryIdUndoScope: entryIdUndoScope,
          entryIntervalUndoScope: entryIntervalUndoScope,
          saveEntry: entryState.saveEntry,
          splitEntry: entryState.splitEntry,
          extendEntryToNow: entryState.extendEntryToNow,
          createManualEntry: entryState.createManualEntry,
          deleteEntry: entryState.deleteEntry,
          correctSuspiciousRunning: entryState.correctSuspiciousRunning,
          overlaps: entryState.overlaps,
          mergeCandidate: entryState.mergeCandidate,
          mergeEntryWithNeighbor: entryState.mergeEntryWithNeighbor,
        );

  EntryMutationState.withHandlers({
    required EntryDateReader now,
    required RunningEntryReader runningEntry,
    required UndoableRecorder recordUndoable,
    required EntryUndoScopeBuilder entryUndoScope,
    required EntryIdUndoScopeBuilder entryIdUndoScope,
    required EntryIntervalUndoScopeBuilder entryIntervalUndoScope,
    required EntrySaver saveEntry,
    required EntrySplitter splitEntry,
    required EntryExtender extendEntryToNow,
    required ManualEntryCreator createManualEntry,
    required EntryDeleter deleteEntry,
    required SuspiciousEntryCorrector correctSuspiciousRunning,
    required EntryOverlapLoader overlaps,
    required EntryMergeCandidateLoader mergeCandidate,
    required EntryNeighborMerger mergeEntryWithNeighbor,
  })  : _now = now,
        _runningEntry = runningEntry,
        _recordUndoable = recordUndoable,
        _entryUndoScope = entryUndoScope,
        _entryIdUndoScope = entryIdUndoScope,
        _entryIntervalUndoScope = entryIntervalUndoScope,
        _saveEntry = saveEntry,
        _splitEntry = splitEntry,
        _extendEntryToNow = extendEntryToNow,
        _createManualEntry = createManualEntry,
        _deleteEntry = deleteEntry,
        _correctSuspiciousRunning = correctSuspiciousRunning,
        _overlaps = overlaps,
        _mergeCandidate = mergeCandidate,
        _mergeEntryWithNeighbor = mergeEntryWithNeighbor;

  final EntryDateReader _now;
  final RunningEntryReader _runningEntry;
  final UndoableRecorder _recordUndoable;
  final EntryUndoScopeBuilder _entryUndoScope;
  final EntryIdUndoScopeBuilder _entryIdUndoScope;
  final EntryIntervalUndoScopeBuilder _entryIntervalUndoScope;
  final EntrySaver _saveEntry;
  final EntrySplitter _splitEntry;
  final EntryExtender _extendEntryToNow;
  final ManualEntryCreator _createManualEntry;
  final EntryDeleter _deleteEntry;
  final SuspiciousEntryCorrector _correctSuspiciousRunning;
  final EntryOverlapLoader _overlaps;
  final EntryMergeCandidateLoader _mergeCandidate;
  final EntryNeighborMerger _mergeEntryWithNeighbor;

  Future<void> saveEntry(TimeEntry entry) async {
    await _recordUndoable('编辑时间段', () async {
      await _saveEntry(entry);
    }, undoScope: _entryUndoScope(entry));
  }

  Future<void> splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) async {
    await _recordUndoable('切割时间段', () async {
      await _splitEntry(entryId: entryId, splitAt: splitAt);
    }, undoScope: _entryIdUndoScope(entryId, extraDays: [splitAt]));
  }

  Future<void> extendEntryToNow(TimeEntry entry) async {
    final currentNow = _now();
    if (entry.isRunning || !entry.startAt.isBefore(currentNow)) {
      return;
    }
    await _recordUndoable('延续时间段到现在', () async {
      await _extendEntryToNow(entry);
    }, undoScope: _entryUndoScope(entry, fallbackEnd: currentNow));
  }

  Future<void> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
  }) async {
    await _recordUndoable('补记时间段', () async {
      await _createManualEntry(
        activityId: activityId,
        startAt: startAt,
        endAt: endAt,
        note: note,
      );
    }, undoScope: _entryIntervalUndoScope(startAt, endAt));
  }

  Future<void> deleteEntry(TimeEntry entry) async {
    await _recordUndoable('删除时间段', () async {
      await _deleteEntry(entry);
    }, undoScope: _entryUndoScope(entry));
  }

  Future<void> correctSuspiciousRunning(DateTime endAt) async {
    final entry = _runningEntry();
    if (entry == null) {
      return;
    }
    await _recordUndoable('修正运行记录', () async {
      await _correctSuspiciousRunning(endAt);
    }, undoScope: _entryUndoScope(entry, fallbackEnd: endAt));
  }

  Future<List<TimeEntry>> overlaps(TimeEntry entry) {
    return _overlaps(entry);
  }

  Future<EntryMergeCandidate?> mergeCandidate(
    String entryId,
    EntryMergeDirection direction,
  ) {
    return _mergeCandidate(entryId, direction);
  }

  Future<void> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) async {
    await _recordUndoable('合并时间段', () async {
      await _mergeEntryWithNeighbor(
        entryId: entryId,
        direction: direction,
        confirmed: confirmed,
      );
    }, undoScope: _entryIdUndoScope(entryId, extraDays: const []));
  }
}
