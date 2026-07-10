import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/entry_state.dart';
import 'package:timetrack/core/result.dart';
import 'package:timetrack/data/repository_interfaces.dart';
import 'package:timetrack/domain/time_entry.dart';

void main() {
  test('refresh keeps running and day entries inside EntryState', () async {
    final running = _entry(id: 'running', isRunning: true);
    final dayEntry = _entry(id: 'day');
    final harness = _Harness(runningEntry: running, dayEntries: [dayEntry]);
    var notifications = 0;
    harness.state.addListener(() => notifications += 1);

    await harness.state.refresh(DateTime(2026, 1, 2));

    expect(notifications, 1);
    expect(harness.state.runningEntry, running);
    expect(harness.state.dayEntries, [dayEntry]);
    expect(harness.entryQueries.runningCalls, 1);
    expect(harness.entryQueries.entriesForDayCalls, [DateTime(2026, 1, 2)]);
  });

  test('save and manual commands apply options and refresh once', () async {
    final now = DateTime(2026, 1, 2, 12);
    final entry = _entry(id: 'entry', updatedAt: DateTime(2026, 1, 2, 9));
    final harness = _Harness(now: now);

    await harness.state.saveEntry(entry);
    await harness.state.createManualEntry(
      activityId: 'activity',
      startAt: DateTime(2026, 1, 2, 8),
      endAt: DateTime(2026, 1, 2, 9),
      note: 'note',
    );

    final saveCall = harness.entryCommands.saveCalls.single;
    expect(saveCall.entry.updatedAt, now);
    expect(saveCall.logEdit, isTrue);
    expect(saveCall.cutOverlaps, isTrue);
    expect(harness.entryCommands.manualCalls.single.note, 'note');
    expect(harness.fullRefreshCount, 2);
  });

  test('extend skips invalid entries and clears the end for valid entries',
      () async {
    final now = DateTime(2026, 1, 2, 12);
    final harness = _Harness(now: now);

    await harness.state
        .extendEntryToNow(_entry(id: 'running', isRunning: true));
    await harness.state.extendEntryToNow(
      _entry(id: 'future', startAt: DateTime(2026, 1, 2, 13)),
    );
    await harness.state.extendEntryToNow(
      _entry(id: 'valid', startAt: DateTime(2026, 1, 2, 9)),
    );

    expect(harness.entryCommands.saveCalls, hasLength(1));
    final saved = harness.entryCommands.saveCalls.single.entry;
    expect(saved.id, 'valid');
    expect(saved.endAt, isNull);
    expect(saved.updatedAt, now);
    expect(harness.fullRefreshCount, 1);
  });

  test('query helpers unwrap repository results', () async {
    final rangeEntry = _entry(id: 'range');
    final overlapEntry = _entry(id: 'overlap');
    final candidate = EntryMergeCandidate(
      current: _entry(id: 'current'),
      neighbor: _entry(id: 'neighbor'),
      direction: EntryMergeDirection.next,
      neighborDuration: const Duration(minutes: 10),
      threshold: const Duration(minutes: 30),
    );
    final harness = _Harness(
      rangeEntries: [rangeEntry],
      overlappingEntries: [overlapEntry],
      mergeCandidate: candidate,
    );

    final range = await harness.state.entriesForRange(
      start: DateTime(2026, 1, 2),
      end: DateTime(2026, 1, 3),
    );
    final overlaps = await harness.state.overlaps(_entry(id: 'target'));
    final foundCandidate = await harness.state.mergeCandidate(
      'entry',
      EntryMergeDirection.next,
    );

    expect(range, [rangeEntry]);
    expect(overlaps, [overlapEntry]);
    expect(foundCandidate, candidate);
  });

  test('split delete and merge delegate to commands and refresh', () async {
    final harness = _Harness();
    final entry = _entry(id: 'delete');

    await harness.state.splitEntry(
      entryId: 'entry',
      splitAt: DateTime(2026, 1, 2, 10),
    );
    await harness.state.deleteEntry(entry);
    await harness.state.mergeEntryWithNeighbor(
      entryId: 'entry',
      direction: EntryMergeDirection.previous,
      confirmed: true,
    );

    expect(harness.entryCommands.splitCalls.single.entryId, 'entry');
    expect(harness.entryCommands.deletedEntries, [entry]);
    expect(harness.entryCommands.mergeCalls.single.direction,
        EntryMergeDirection.previous);
    expect(harness.fullRefreshCount, 3);
  });
}

class _Harness {
  _Harness({
    DateTime? now,
    TimeEntry? runningEntry,
    List<TimeEntry> dayEntries = const [],
    List<TimeEntry> rangeEntries = const [],
    List<TimeEntry> overlappingEntries = const [],
    EntryMergeCandidate? mergeCandidate,
  })  : entryQueries = _EntryQueries(
          runningValue: runningEntry,
          dayEntries: dayEntries,
          rangeEntries: rangeEntries,
          overlappingValues: overlappingEntries,
          mergeCandidate: mergeCandidate,
        ),
        entryCommands = _EntryCommands(),
        now = now ?? DateTime(2026, 1, 2, 12) {
    state = EntryState(
      entryQueries: entryQueries,
      entryCommands: entryCommands,
      now: () => this.now,
      onFullRefresh: () async => fullRefreshCount += 1,
    );
  }

  final _EntryQueries entryQueries;
  final _EntryCommands entryCommands;
  final DateTime now;
  late final EntryState state;

  int fullRefreshCount = 0;
}

class _EntryQueries implements ITimeEntryQueryRepository {
  _EntryQueries({
    this.runningValue,
    this.dayEntries = const [],
    this.rangeEntries = const [],
    this.overlappingValues = const [],
    this.mergeCandidate,
  });

  final TimeEntry? runningValue;
  final List<TimeEntry> dayEntries;
  final List<TimeEntry> rangeEntries;
  final List<TimeEntry> overlappingValues;
  final EntryMergeCandidate? mergeCandidate;
  final entriesForDayCalls = <DateTime>[];
  int runningCalls = 0;

  @override
  Future<AppResult<TimeEntry?>> runningEntry() async {
    runningCalls += 1;
    return AppSuccess(runningValue);
  }

  @override
  Future<AppResult<List<TimeEntry>>> entriesForDay(DateTime day) async {
    entriesForDayCalls.add(day);
    return AppSuccess(dayEntries);
  }

  @override
  Future<AppResult<List<TimeEntry>>> entriesForRange(
    DateTime start,
    DateTime end,
  ) async {
    return AppSuccess(rangeEntries);
  }

  @override
  Future<AppResult<List<TimeEntry>>> allEntries() async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<EntryMergeCandidate?>> mergeCandidateForEntry(
    String entryId,
    EntryMergeDirection direction,
  ) async {
    return AppSuccess(mergeCandidate);
  }

  @override
  Future<AppResult<List<TimeEntry>>> overlappingEntries(TimeEntry entry) async {
    return AppSuccess(overlappingValues);
  }
}

class _EntryCommands implements ITimeEntryCommandRepository {
  final saveCalls = <({TimeEntry entry, bool logEdit, bool cutOverlaps})>[];
  final manualCalls =
      <({String activityId, DateTime startAt, DateTime endAt, String note})>[];
  final splitCalls = <({String entryId, DateTime splitAt})>[];
  final deletedEntries = <TimeEntry>[];
  final mergeCalls =
      <({String entryId, EntryMergeDirection direction, bool confirmed})>[];

  @override
  Future<AppResult<List<TimeEntry>>> saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  }) async {
    saveCalls.add((
      entry: entry,
      logEdit: logEdit,
      cutOverlaps: cutOverlaps,
    ));
    return AppSuccess([entry]);
  }

  @override
  Future<AppResult<TimeEntry>> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
    String? userId,
  }) async {
    manualCalls.add((
      activityId: activityId,
      startAt: startAt,
      endAt: endAt,
      note: note,
    ));
    return AppSuccess(_entry(id: 'manual', activityId: activityId));
  }

  @override
  Future<AppResult<void>> deleteEntry(TimeEntry entry) async {
    deletedEntries.add(entry);
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<TimeEntry?>> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) async {
    mergeCalls.add((
      entryId: entryId,
      direction: direction,
      confirmed: confirmed,
    ));
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<List<TimeEntry>>> splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) async {
    splitCalls.add((entryId: entryId, splitAt: splitAt));
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<void>> stopRunning({DateTime? at}) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<TimeEntry>> switchToActivity(
    String activityId, {
    DateTime? at,
  }) async {
    return AppSuccess(_entry(id: 'running', activityId: activityId));
  }
}

TimeEntry _entry({
  required String id,
  String activityId = 'activity',
  DateTime? startAt,
  DateTime? endAt,
  DateTime? updatedAt,
  bool isRunning = false,
}) {
  final start = startAt ?? DateTime(2026, 1, 2, 9);
  return TimeEntry(
    id: id,
    userId: null,
    activityId: activityId,
    activityNameSnapshot: 'Activity',
    activityColorSnapshot: 0xff2563eb,
    startAt: start,
    endAt: isRunning ? null : endAt ?? DateTime(2026, 1, 2, 10),
    note: '',
    deviceId: 'test-device',
    updatedAt: updatedAt ?? start,
    isDeleted: false,
  );
}
