import 'package:flutter/foundation.dart';

import '../data/repository_interfaces.dart';
import '../domain/action_log.dart';
import '../domain/time_entry.dart';
import 'app_state_result.dart';

class EntryState extends ChangeNotifier {
  EntryState({
    required ITimeEntryQueryRepository entryQueries,
    required ITimeEntryCommandRepository entryCommands,
    required DateTime Function() now,
    required Future<void> Function() onFullRefresh,
  })  : _entryQueries = entryQueries,
        _entryCommands = entryCommands,
        _now = now,
        _onFullRefresh = onFullRefresh;

  final ITimeEntryQueryRepository _entryQueries;
  final ITimeEntryCommandRepository _entryCommands;
  final DateTime Function() _now;
  final Future<void> Function() _onFullRefresh;

  List<TimeEntry> dayEntries = const [];
  List<ActionLog> dayActionLogs = const [];
  TimeEntry? runningEntry;
  String? errorMessage;

  Future<void> refresh(DateTime day, {bool notify = true}) async {
    final runningResult = await _entryQueries.runningEntry();
    runningEntry = runningResult.fold(
      onSuccess: (entry) => entry,
      onFailure: (msg) {
        errorMessage = msg;
        return runningEntry;
      },
    );
    final entriesResult = await _entryQueries.entriesForDay(day);
    dayEntries = entriesResult.fold(
      onSuccess: (list) => list,
      onFailure: (msg) {
        errorMessage = msg;
        return dayEntries;
      },
    );
    if (notify) {
      notifyListeners();
    }
  }

  void setActionLogs(List<ActionLog> logs) {
    dayActionLogs = logs;
  }

  void setRunningEntry(TimeEntry? entry) {
    runningEntry = entry;
  }

  void setDayEntries(List<TimeEntry> entries) {
    dayEntries = entries;
  }

  Future<void> saveEntry(TimeEntry entry) async {
    final result = await _entryCommands.saveEntry(
      entry.copyWith(updatedAt: _now()),
      logEdit: true,
      cutOverlaps: true,
    );
    unwrapAppStateResult(result);
    await _onFullRefresh();
  }

  Future<void> splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) async {
    final result = await _entryCommands.splitEntry(
      entryId: entryId,
      splitAt: splitAt,
    );
    unwrapAppStateResult(result);
    await _onFullRefresh();
  }

  Future<void> extendEntryToNow(TimeEntry entry) async {
    if (entry.isRunning || !entry.startAt.isBefore(_now())) {
      return;
    }
    final result = await _entryCommands.saveEntry(
      entry.copyWith(clearEndAt: true, updatedAt: _now()),
      logEdit: true,
      cutOverlaps: true,
    );
    unwrapAppStateResult(result);
    await _onFullRefresh();
  }

  Future<void> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
  }) async {
    final result = await _entryCommands.createManualEntry(
      activityId: activityId,
      startAt: startAt,
      endAt: endAt,
      note: note,
    );
    unwrapAppStateResult(result);
    await _onFullRefresh();
  }

  Future<void> deleteEntry(TimeEntry entry) async {
    final result = await _entryCommands.deleteEntry(entry);
    unwrapAppStateResult(result);
    await _onFullRefresh();
  }

  Future<void> correctSuspiciousRunning(DateTime endAt) async {
    final entry = runningEntry;
    if (entry == null) {
      return;
    }
    final result = await _entryCommands.saveEntry(
      entry.copyWith(endAt: endAt, updatedAt: _now()),
      logEdit: true,
    );
    unwrapAppStateResult(result);
    await _onFullRefresh();
  }

  Future<List<TimeEntry>> entriesForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final result = await _entryQueries.entriesForRange(start, end);
    return unwrapAppStateResult(result);
  }

  Future<List<TimeEntry>> overlaps(TimeEntry entry) async {
    final result = await _entryQueries.overlappingEntries(entry);
    return unwrapAppStateResult(result);
  }

  Future<EntryMergeCandidate?> mergeCandidate(
    String entryId,
    EntryMergeDirection direction,
  ) async {
    final result =
        await _entryQueries.mergeCandidateForEntry(entryId, direction);
    return unwrapAppStateResult(result);
  }

  Future<void> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) async {
    final result = await _entryCommands.mergeEntryWithNeighbor(
      entryId: entryId,
      direction: direction,
      confirmed: confirmed,
    );
    unwrapAppStateResult(result);
    await _onFullRefresh();
  }
}
