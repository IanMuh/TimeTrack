// ignore_for_file: unused_element

part of 'time_entry_repository.dart';

mixin TimeEntryRepositoryQueryLogic {
  LocalDatabase get _database;

  Future<TimeEntry?> _runningEntry() async {
    final db = await _database.db;
    final rows = await db.query(
      'time_entries',
      where: 'end_at is null and is_deleted = 0',
      orderBy: 'start_at desc',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return TimeEntry.fromMap(rows.first);
  }

  Future<List<TimeEntry>> _entriesForDay(DateTime day) async {
    final db = await _database.db;
    final start = day.startOfDay.toUtc().toIso8601String();
    final end =
        day.startOfDay.add(const Duration(days: 1)).toUtc().toIso8601String();
    final rows = await db.query(
      'time_entries',
      where: 'is_deleted = 0 and start_at < ? and '
          '(end_at is null or end_at > ?)',
      whereArgs: [end, start],
      orderBy: 'is_deleted asc, start_at asc',
    );
    return rows.map(TimeEntry.fromMap).toList();
  }

  Future<List<TimeEntry>> _entriesForRange(
    DateTime start,
    DateTime end,
  ) async {
    if (!start.isBefore(end)) {
      return const [];
    }
    final db = await _database.db;
    final endStr = end.toUtc().toIso8601String();
    final startStr = start.toUtc().toIso8601String();
    final rows = await db.query(
      'time_entries',
      where: 'is_deleted = 0 and start_at < ? and '
          '(end_at is null or end_at > ?)',
      whereArgs: [endStr, startStr],
      orderBy: 'is_deleted asc, start_at asc',
    );
    return rows.map(TimeEntry.fromMap).toList();
  }

  Future<List<TimeEntry>> _entriesSince(DateTime since) async {
    final db = await _database.db;
    final rows = await db.query(
      'time_entries',
      where: 'updated_at >= ?',
      whereArgs: [since.toUtc().toIso8601String()],
      orderBy: 'updated_at asc',
    );
    return rows.map(TimeEntry.fromMap).toList();
  }

  Future<List<TimeEntry>> _allEntries() async {
    final db = await _database.db;
    final rows = await db.query(
      'time_entries',
      orderBy: 'updated_at asc',
    );
    return rows.map(TimeEntry.fromMap).toList();
  }

  Future<EntryMergeCandidate?> _mergeCandidateForEntry(
    String entryId,
    EntryMergeDirection direction,
  ) async {
    final current = await entryById(entryId);
    if (current == null || current.isDeleted || current.isRunning) {
      return null;
    }
    final db = await _database.db;
    final settingsRows = await db.query('profile_settings', limit: 1);
    final settings = settingsRows.isEmpty
        ? ProfileSettings.defaults()
        : ProfileSettings.fromMap(settingsRows.first);
    final threshold = Duration(
      minutes: settings.mergeNeighborThresholdMinutes,
    );
    final entries = (await _entriesForDay(current.startAt))
        .where((entry) => !entry.isDeleted && !entry.isRunning)
        .toList()
      ..sort((first, second) => first.startAt.compareTo(second.startAt));
    final index = entries.indexWhere((entry) => entry.id == current.id);
    if (index == -1) {
      return null;
    }
    final neighborIndex =
        direction == EntryMergeDirection.previous ? index - 1 : index + 1;
    if (neighborIndex < 0 || neighborIndex >= entries.length) {
      return null;
    }
    final neighbor = entries[neighborIndex];
    final neighborEnd = neighbor.endAt;
    if (neighborEnd == null || !neighborEnd.isAfter(neighbor.startAt)) {
      return null;
    }
    return EntryMergeCandidate(
      current: current,
      neighbor: neighbor,
      direction: direction,
      neighborDuration: neighborEnd.difference(neighbor.startAt),
      threshold: threshold,
    );
  }

  Future<List<TimeEntry>> _overlappingEntries(TimeEntry entry) async {
    final dayEntries = await _entriesForDay(entry.startAt);
    return dayEntries
        .where((candidate) =>
            candidate.id != entry.id &&
            !candidate.isDeleted &&
            candidate.overlaps(entry))
        .toList();
  }

  Future<TimeEntry?> entryById(String entryId) async {
    final db = await _database.db;
    final rows = await db.query(
      'time_entries',
      where: 'id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return TimeEntry.fromMap(rows.first);
  }

  Future<TimeEntry?> entryByIdWithExecutor(
    String entryId,
    DatabaseExecutor executor,
  ) async {
    final rows = await executor.query(
      'time_entries',
      where: 'id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return TimeEntry.fromMap(rows.first);
  }
}
