import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/entry_mutation_state.dart';
import 'package:timetrack/data/repository_interfaces.dart';
import 'package:timetrack/data/repository_undo.dart';
import 'package:timetrack/domain/time_entry.dart';

void main() {
  test('AppState entry mutation facade stays separate', () {
    final mutationFacade = File('lib/app/app_state_entry_mutation_facade.dart');
    final entryFacade = File('lib/app/app_state_entry_facade.dart');

    expect(mutationFacade.existsSync(), isTrue);

    final mutationSource = mutationFacade.readAsStringSync();
    final entrySource = entryFacade.readAsStringSync();

    expect(mutationSource, contains('mixin AppStateEntryMutationFacade'));
    expect(mutationSource, contains('Future<void> saveEntry(TimeEntry entry)'));
    expect(mutationSource, contains('Future<void> splitEntry({'));
    expect(
      mutationSource,
      contains('Future<void> extendEntryToNow(TimeEntry entry)'),
    );
    expect(mutationSource, contains('Future<void> createManualEntry({'));
    expect(
        mutationSource, contains('Future<void> deleteEntry(TimeEntry entry)'));
    expect(
      mutationSource,
      contains('Future<void> correctSuspiciousRunning(DateTime endAt)'),
    );
    expect(
      mutationSource,
      contains('Future<List<TimeEntry>> overlaps(TimeEntry entry)'),
    );
    expect(
      mutationSource,
      contains('Future<EntryMergeCandidate?> mergeCandidate('),
    );
    expect(mutationSource, contains('Future<void> mergeEntryWithNeighbor({'));
    expect(entrySource, isNot(contains('Future<void> saveEntry(')));
    expect(entrySource, isNot(contains('Future<void> splitEntry({')));
    expect(entrySource, isNot(contains('Future<void> extendEntryToNow(')));
    expect(entrySource, isNot(contains('Future<void> createManualEntry({')));
    expect(entrySource, isNot(contains('Future<void> deleteEntry(')));
    expect(
      entrySource,
      isNot(contains('Future<void> correctSuspiciousRunning(')),
    );
    expect(entrySource, isNot(contains('Future<List<TimeEntry>> overlaps(')));
    expect(
      entrySource,
      isNot(contains('Future<EntryMergeCandidate?> mergeCandidate(')),
    );
    expect(
      entrySource,
      isNot(contains('Future<void> mergeEntryWithNeighbor({')),
    );
  });

  test('saveEntry records edit label with entry scope', () async {
    final entry = _entry();
    final harness = _Harness();

    await harness.state.saveEntry(entry);

    expect(harness.labels, ['编辑时间段']);
    expect(harness.scopes.single, same(harness.entryScope));
    expect(harness.savedEntries, [entry]);
    expect(harness.entryScopeCalls.single.entry, entry);
    expect(harness.entryScopeCalls.single.fallbackEnd, isNull);
  });

  test('extendEntryToNow skips invalid entries and scopes valid entry to now',
      () async {
    final now = DateTime(2026, 1, 2, 12);
    final harness = _Harness(now: now);

    await harness.state.extendEntryToNow(
      _entry(startAt: DateTime(2026, 1, 2, 9), isRunning: true),
    );
    await harness.state.extendEntryToNow(
      _entry(startAt: DateTime(2026, 1, 2, 13)),
    );
    final validEntry = _entry(startAt: DateTime(2026, 1, 2, 9));
    await harness.state.extendEntryToNow(validEntry);

    expect(harness.labels, ['延续时间段到现在']);
    expect(harness.extendedEntries, [validEntry]);
    expect(harness.entryScopeCalls.single.entry, validEntry);
    expect(harness.entryScopeCalls.single.fallbackEnd, now);
  });

  test('split manual and merge operations use interval or id scopes', () async {
    final harness = _Harness();
    final splitAt = DateTime(2026, 1, 2, 10);
    final startAt = DateTime(2026, 1, 2, 8);
    final endAt = DateTime(2026, 1, 2, 9);

    await harness.state.splitEntry(entryId: 'entry', splitAt: splitAt);
    await harness.state.createManualEntry(
      activityId: 'activity',
      startAt: startAt,
      endAt: endAt,
      note: 'note',
    );
    await harness.state.mergeEntryWithNeighbor(
      entryId: 'entry',
      direction: EntryMergeDirection.next,
      confirmed: true,
    );

    expect(harness.labels, ['切割时间段', '补记时间段', '合并时间段']);
    expect(harness.scopes, [
      harness.entryIdScope,
      harness.intervalScope,
      harness.entryIdScope,
    ]);
    expect(harness.entryIdScopeCalls.first.entryId, 'entry');
    expect(harness.entryIdScopeCalls.first.extraDays, [splitAt]);
    expect(harness.intervalScopeCalls.single, (startAt, endAt));
    expect(harness.mergedDirections, [EntryMergeDirection.next]);
  });

  test('correctSuspiciousRunning scopes the loaded running entry', () async {
    final running = _entry(isRunning: true);
    final endAt = DateTime(2026, 1, 2, 11);
    final harness = _Harness(runningEntry: running);

    await harness.state.correctSuspiciousRunning(endAt);

    expect(harness.labels, ['修正运行记录']);
    expect(harness.correctedEnds, [endAt]);
    expect(harness.entryScopeCalls.single.entry, running);
    expect(harness.entryScopeCalls.single.fallbackEnd, endAt);

    final emptyHarness = _Harness();
    await emptyHarness.state.correctSuspiciousRunning(endAt);

    expect(emptyHarness.labels, isEmpty);
    expect(emptyHarness.correctedEnds, isEmpty);
  });
}

class _Harness {
  _Harness({
    DateTime? now,
    this.runningEntry,
  }) : now = now ?? DateTime(2026, 1, 2, 12) {
    state = EntryMutationState.withHandlers(
      now: () => this.now,
      runningEntry: () => runningEntry,
      recordUndoable: recordUndoable,
      entryUndoScope: entryUndoScope,
      entryIdUndoScope: entryIdUndoScope,
      entryIntervalUndoScope: entryIntervalUndoScope,
      saveEntry: (entry) async {
        savedEntries.add(entry);
      },
      splitEntry: ({required entryId, required splitAt}) async {
        splitCalls.add((entryId, splitAt));
      },
      extendEntryToNow: (entry) async {
        extendedEntries.add(entry);
      },
      createManualEntry: ({
        required activityId,
        required startAt,
        required endAt,
        required note,
      }) async {
        manualEntryCalls.add((activityId, startAt, endAt, note));
      },
      deleteEntry: (entry) async {
        deletedEntries.add(entry);
      },
      correctSuspiciousRunning: (endAt) async {
        correctedEnds.add(endAt);
      },
      overlaps: (entry) async => overlapsResult,
      mergeCandidate: (entryId, direction) async => null,
      mergeEntryWithNeighbor: ({
        required entryId,
        required direction,
        required confirmed,
      }) async {
        mergedDirections.add(direction);
      },
    );
  }

  final DateTime now;
  final TimeEntry? runningEntry;
  late final EntryMutationState state;

  final entryScope = _scopeFor(DateTime(2026, 1, 1));
  final entryIdScope = _scopeFor(DateTime(2026, 1, 2));
  final intervalScope = _scopeFor(DateTime(2026, 1, 3));
  final labels = <String>[];
  final scopes = <RepositoryUndoScope?>[];
  final savedEntries = <TimeEntry>[];
  final extendedEntries = <TimeEntry>[];
  final deletedEntries = <TimeEntry>[];
  final correctedEnds = <DateTime>[];
  final splitCalls = <(String, DateTime)>[];
  final manualEntryCalls = <(String, DateTime, DateTime, String)>[];
  final mergedDirections = <EntryMergeDirection>[];
  final overlapsResult = <TimeEntry>[];
  final entryScopeCalls = <({TimeEntry entry, DateTime? fallbackEnd})>[];
  final entryIdScopeCalls = <({String entryId, List<DateTime> extraDays})>[];
  final intervalScopeCalls = <(DateTime, DateTime)>[];

  Future<T> recordUndoable<T>(
    String label,
    Future<T> Function() action, {
    bool syncAfter = true,
    RepositoryUndoScope? undoScope,
  }) async {
    labels.add(label);
    scopes.add(undoScope);
    return action();
  }

  RepositoryUndoScope entryUndoScope(
    TimeEntry entry, {
    DateTime? fallbackEnd,
  }) {
    entryScopeCalls.add((entry: entry, fallbackEnd: fallbackEnd));
    return entryScope;
  }

  RepositoryUndoScope entryIdUndoScope(
    String entryId, {
    required List<DateTime> extraDays,
  }) {
    entryIdScopeCalls.add((entryId: entryId, extraDays: extraDays));
    return entryIdScope;
  }

  RepositoryUndoScope entryIntervalUndoScope(DateTime start, DateTime end) {
    intervalScopeCalls.add((start, end));
    return intervalScope;
  }
}

TimeEntry _entry({
  DateTime? startAt,
  DateTime? endAt,
  bool isRunning = false,
}) {
  final start = startAt ?? DateTime(2026, 1, 2, 9);
  return TimeEntry(
    id: 'entry',
    userId: null,
    activityId: 'activity',
    activityNameSnapshot: 'Activity',
    activityColorSnapshot: 0xff2563eb,
    startAt: start,
    endAt: isRunning ? null : endAt ?? DateTime(2026, 1, 2, 10),
    note: '',
    deviceId: 'test-device',
    updatedAt: start,
    isDeleted: false,
  );
}

RepositoryUndoScope _scopeFor(DateTime day) {
  return RepositoryUndoScope(
    entryWindows: [RepositoryUndoWindow.forLocalDay(day)],
  );
}
