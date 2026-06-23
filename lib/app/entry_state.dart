import 'package:flutter/foundation.dart';

import '../data/repository_interfaces.dart';
import '../domain/action_log.dart';
import '../domain/time_entry.dart';

class EntryState extends ChangeNotifier {
  EntryState({
    required ITimeEntryRepository entryRepository,
    required DateTime Function() now,
    required Future<void> Function() onFullRefresh,
  })  : _entryRepo = entryRepository,
        _now = now,
        _onFullRefresh = onFullRefresh;

  final ITimeEntryRepository _entryRepo;
  final DateTime Function() _now;
  final Future<void> Function() _onFullRefresh;

  List<TimeEntry> dayEntries = const [];
  List<ActionLog> dayActionLogs = const [];
  TimeEntry? runningEntry;
  String? errorMessage;

  Future<void> refresh(DateTime day) async {
    final runningResult = await _entryRepo.runningEntry();
    runningEntry = runningResult.fold(
      onSuccess: (entry) => entry,
      onFailure: (msg) {
        errorMessage = msg;
        return runningEntry;
      },
    );
    final entriesResult = await _entryRepo.entriesForDay(day);
    dayEntries = entriesResult.fold(
      onSuccess: (list) => list,
      onFailure: (msg) {
        errorMessage = msg;
        return dayEntries;
      },
    );
    notifyListeners();
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
    final result = await _entryRepo.saveEntry(
      entry.copyWith(updatedAt: _now()),
      logEdit: true,
      cutOverlaps: true,
    );
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
    await _onFullRefresh();
  }

  Future<void> splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) async {
    final result = await _entryRepo.splitEntry(
      entryId: entryId,
      splitAt: splitAt,
    );
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
    await _onFullRefresh();
  }

  Future<void> extendEntryToNow(TimeEntry entry) async {
    if (entry.isRunning || !entry.startAt.isBefore(_now())) {
      return;
    }
    final result = await _entryRepo.saveEntry(
      entry.copyWith(clearEndAt: true, updatedAt: _now()),
      logEdit: true,
      cutOverlaps: true,
    );
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
    await _onFullRefresh();
  }

  Future<void> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
  }) async {
    final result = await _entryRepo.createManualEntry(
      activityId: activityId,
      startAt: startAt,
      endAt: endAt,
      note: note,
    );
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
    await _onFullRefresh();
  }

  Future<void> deleteEntry(TimeEntry entry) async {
    final result = await _entryRepo.deleteEntry(entry);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
    await _onFullRefresh();
  }

  Future<void> correctSuspiciousRunning(DateTime endAt) async {
    final entry = runningEntry;
    if (entry == null) {
      return;
    }
    final result = await _entryRepo.saveEntry(
      entry.copyWith(endAt: endAt, updatedAt: _now()),
      logEdit: true,
    );
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
    await _onFullRefresh();
  }

  Future<List<TimeEntry>> entriesForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final result = await _entryRepo.entriesForRange(start, end);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<TimeEntry>> overlaps(TimeEntry entry) async {
    final result = await _entryRepo.overlappingEntries(entry);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<EntryMergeCandidate?> mergeCandidate(
    String entryId,
    EntryMergeDirection direction,
  ) async {
    final result = await _entryRepo.mergeCandidateForEntry(entryId, direction);
    return result.fold(
      onSuccess: (candidate) => candidate,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) async {
    final result = await _entryRepo.mergeEntryWithNeighbor(
      entryId: entryId,
      direction: direction,
      confirmed: confirmed,
    );
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
    await _onFullRefresh();
  }
}
