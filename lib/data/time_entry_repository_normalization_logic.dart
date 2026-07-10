// ignore_for_file: unused_element_parameter

part of 'time_entry_repository.dart';

mixin TimeEntryRepositoryNormalizationLogic
    on TimeEntryRepositoryQueryLogic, TimeEntryRepositoryStorageLogic {
  ActivityRepository get _activityRepo;

  DateTime _now();

  Future<TimeEntry> _switchToActivity(String activityId, {DateTime? at});

  Future<List<TimeEntry>> _saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  });

  Future<void> rolloverRunningEntriesIfNeeded({DateTime? at}) async {
    final now = at ?? _now();
    final todayStart = now.startOfDay;
    final db = await _database.db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'time_entries',
        where: 'end_at is null and is_deleted = 0',
        orderBy: 'start_at asc',
      );
      for (final row in rows) {
        final running = await _activityRepo.entryWithActivitySnapshot(
          TimeEntry.fromMap(row),
          txn,
        );
        if (!running.startAt.isBefore(todayStart)) {
          continue;
        }
        var cursor = running.startAt;
        var firstSegment = true;
        while (cursor.startOfDay.isBefore(todayStart)) {
          final segmentEnd = cursor.startOfDay.add(const Duration(days: 1));
          if (cursor.isBefore(segmentEnd)) {
            final segment = running.copyWith(
              id: firstSegment ? running.id : _uuid.v4(),
              startAt: cursor,
              endAt: segmentEnd,
              updatedAt: now,
            );
            await txn.insert(
              'time_entries',
              segment.toLocalMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          cursor = segmentEnd;
          firstSegment = false;
        }
        final nextRunning = running.copyWith(
          id: firstSegment ? running.id : _uuid.v4(),
          startAt: cursor,
          clearEndAt: true,
          updatedAt: now,
        );
        await txn.insert(
          'time_entries',
          nextRunning.toLocalMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> normalizeRunningEntriesAfterMerge() async {
    final db = await _database.db;
    final runningRows = await db.query(
      'time_entries',
      where: 'end_at is null and is_deleted = 0',
      orderBy: 'start_at desc',
    );
    if (runningRows.length <= 1) {
      return;
    }

    final keep = TimeEntry.fromMap(runningRows.first);
    final now = _now();
    for (final row in runningRows.skip(1)) {
      final entry = TimeEntry.fromMap(row);
      final normalized = entry.startAt.isBefore(keep.startAt)
          ? entry.copyWith(endAt: keep.startAt, updatedAt: now)
          : entry.copyWith(isDeleted: true, updatedAt: now);
      await db.insert(
        'time_entries',
        normalized.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> normalizeStoredCrossDayEntries() async {
    final db = await _database.db;
    final rows = await db.query(
      'time_entries',
      where: 'is_deleted = 0 and end_at is not null',
      orderBy: 'start_at asc',
    );
    for (final row in rows) {
      final entry = TimeEntry.fromMap(row);
      if (_splitClosedEntryByLocalDay(entry, entry.updatedAt).length <= 1) {
        continue;
      }
      await _saveEntry(entry);
    }
  }

  Future<void> backfillMissingEntrySnapshots() async {
    final db = await _database.db;
    final rows = await db.query(
      'time_entries',
      where: "(activity_name = '' or activity_color is null)",
      orderBy: 'updated_at asc',
    );
    for (final row in rows) {
      final entry = TimeEntry.fromMap(row);
      final withSnapshot =
          await _activityRepo.entryWithActivitySnapshot(entry, db);
      if (withSnapshot.activityNameSnapshot == entry.activityNameSnapshot &&
          withSnapshot.activityColorSnapshot == entry.activityColorSnapshot) {
        continue;
      }
      await db.insert(
        'time_entries',
        withSnapshot.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> mergeAdjacentUnassignedEntries(String activityId) async {
    final db = await _database.db;
    final rows = await db.query(
      'time_entries',
      where: 'activity_id = ? and is_deleted = 0',
      whereArgs: [activityId],
      orderBy: 'start_at asc, end_at asc',
    );
    if (rows.length <= 1) {
      return;
    }

    final now = _now();
    final entries = rows.map(TimeEntry.fromMap).toList();
    var survivor = entries.first;
    var survivorChanged = false;
    final survivorUpdates = <TimeEntry>[];
    final deletedEntries = <TimeEntry>[];

    for (final entry in entries.skip(1)) {
      if (_unassignedEntriesAreContinuous(survivor, entry)) {
        survivor = _mergedUnassignedEntry(survivor, entry, now);
        survivorChanged = true;
        deletedEntries.add(entry.copyWith(isDeleted: true, updatedAt: now));
        continue;
      }
      if (survivorChanged) {
        survivorUpdates.add(survivor);
      }
      survivor = entry;
      survivorChanged = false;
    }
    if (survivorChanged) {
      survivorUpdates.add(survivor);
    }

    for (final entry in survivorUpdates) {
      await db.insert(
        'time_entries',
        entry.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final entry in deletedEntries) {
      await db.insert(
        'time_entries',
        entry.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _startUnassigned({required DateTime at}) async {
    final activity = await _activityRepo.ensureUnassignedActivity();
    final running = await _runningEntry();
    if (running?.activityId == activity.id) {
      await mergeAdjacentUnassignedEntries(activity.id);
      return;
    }
    await _switchToActivity(activity.id, at: at);
  }

  bool _unassignedEntriesAreContinuous(TimeEntry first, TimeEntry second) {
    final firstEnd = first.endAt;
    return firstEnd == null || !second.startAt.isAfter(firstEnd);
  }

  TimeEntry _mergedUnassignedEntry(
    TimeEntry first,
    TimeEntry second,
    DateTime updatedAt,
  ) {
    final endAt = _latestEnd(first.endAt, second.endAt);
    return first.copyWith(
      endAt: endAt,
      clearEndAt: endAt == null,
      note: _mergedNotes(first.note, second.note),
      updatedAt: updatedAt,
    );
  }

  DateTime? _latestEnd(DateTime? first, DateTime? second) {
    if (first == null || second == null) {
      return null;
    }
    return first.isAfter(second) ? first : second;
  }

  String _mergedNotes(String first, String second) {
    final notes = <String>{};
    for (final note in [first.trim(), second.trim()]) {
      if (note.isNotEmpty) {
        notes.add(note);
      }
    }
    return notes.join('\n');
  }
}
