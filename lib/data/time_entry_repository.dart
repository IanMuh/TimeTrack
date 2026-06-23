import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/app_constants.dart';
import '../core/date_time_ext.dart';
import '../core/result.dart';
import '../domain/action_log.dart';
import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';
import 'activity_repository.dart';
import 'local_database.dart';
import 'repository_interfaces.dart';

class _EntryInterval {
  const _EntryInterval(this.startAt, this.endAt);

  final DateTime startAt;
  final DateTime? endAt;
}

class TimeEntryRepository implements ITimeEntryRepository {
  TimeEntryRepository({
    required LocalDatabase database,
    required ActivityRepository activityRepository,
    String? deviceId,
    Uuid? uuid,
  })  : _database = database,
        _activityRepo = activityRepository,
        _deviceIdOverride = deviceId,
        _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final ActivityRepository _activityRepo;
  final String? _deviceIdOverride;
  final Uuid _uuid;
  String? _cachedDeviceId;

  // -------------------------------------------------------------------------
  // ITimeEntryRepository — AppResult-wrapped public API
  // -------------------------------------------------------------------------

  @override
  Future<AppResult<TimeEntry?>> runningEntry() async {
    try {
      return AppSuccess(await _runningEntry());
    } catch (e) {
      return AppFailure('Failed to get running entry: $e');
    }
  }

  @override
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

  @override
  Future<AppResult<void>> stopRunning({DateTime? at}) async {
    try {
      await _stopRunning(at: at);
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to stop running: $e');
    }
  }

  @override
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

  @override
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

  @override
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

  @override
  Future<AppResult<void>> deleteEntry(TimeEntry entry) async {
    try {
      await _deleteEntry(entry);
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to delete entry: $e');
    }
  }

  @override
  Future<AppResult<List<TimeEntry>>> entriesForDay(DateTime day) async {
    try {
      return AppSuccess(await _entriesForDay(day));
    } catch (e) {
      return AppFailure('Failed to load entries for day: $e');
    }
  }

  @override
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

  @override
  Future<AppResult<List<TimeEntry>>> entriesSince(DateTime since) async {
    try {
      return AppSuccess(await _entriesSince(since));
    } catch (e) {
      return AppFailure('Failed to load entries since: $e');
    }
  }

  @override
  Future<AppResult<List<TimeEntry>>> allEntries() async {
    try {
      return AppSuccess(await _allEntries());
    } catch (e) {
      return AppFailure('Failed to load all entries: $e');
    }
  }

  @override
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

  @override
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

  @override
  Future<AppResult<List<TimeEntry>>> overlappingEntries(TimeEntry entry) async {
    try {
      return AppSuccess(await _overlappingEntries(entry));
    } catch (e) {
      return AppFailure('Failed to find overlapping entries: $e');
    }
  }

  @override
  Future<AppResult<void>> replaceEntryIfRemoteNewer(TimeEntry remote) async {
    try {
      await _replaceEntryIfRemoteNewer(remote);
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to replace entry: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Internal implementations (raw return types, no AppResult wrapping)
  // -------------------------------------------------------------------------

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

  Future<TimeEntry> _switchToActivity(
    String activityId, {
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    await rolloverRunningEntriesIfNeeded(at: now);
    final deviceId = await _currentDeviceId();
    final targetIsUnassigned =
        await _activityRepo.activityIdIsUnassigned(activityId);
    final db = await _database.db;
    late TimeEntry next;
    String? previousActivityId;
    await db.transaction((txn) async {
      final runningRows = await txn.query(
        'time_entries',
        where: 'end_at is null and is_deleted = 0',
        orderBy: 'start_at desc',
      );

      if (targetIsUnassigned && runningRows.isNotEmpty) {
        final running = TimeEntry.fromMap(runningRows.first);
        if (running.activityId == activityId) {
          next = running;
          return;
        }
      }

      for (final row in runningRows) {
        final running = TimeEntry.fromMap(row);
        previousActivityId ??= running.activityId;
        if (running.startAt.isBefore(now)) {
          await _saveEntryRows(
            txn,
            await _activityRepo.entryWithActivitySnapshot(
              running.copyWith(endAt: now, updatedAt: now),
              txn,
            ),
          );
          await _activityRepo.softDeleteOneOffActivityIfNeeded(
            running.activityId,
            now,
            txn,
          );
        } else {
          await txn.insert(
            'time_entries',
            running.copyWith(isDeleted: true, updatedAt: now).toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await _activityRepo.softDeleteOneOffActivityIfNeeded(
            running.activityId,
            now,
            txn,
          );
        }
      }

      next = await _activityRepo.entryWithActivitySnapshot(
        TimeEntry(
          id: _uuid.v4(),
          userId: null,
          activityId: activityId,
          startAt: now,
          endAt: null,
          note: '',
          deviceId: deviceId,
          updatedAt: now,
          isDeleted: false,
        ),
        txn,
      );
      await txn.insert('time_entries', next.toLocalMap());
      await txn.insert(
        'action_logs',
        _buildActionLog(
          actionType: ActionType.switch_,
          activityId: activityId,
          entryId: next.id,
          occurredAt: now,
          message:
              previousActivityId == null ? '开始事项' : '切换事项',
        ).toLocalMap(),
      );
    });
    if (targetIsUnassigned) {
      await mergeAdjacentUnassignedEntries(activityId);
      return await _runningEntry() ?? next;
    }
    return next;
  }

  Future<void> _stopRunning({DateTime? at}) async {
    final now = at ?? DateTime.now();
    await rolloverRunningEntriesIfNeeded(at: now);
    final unassigned = await _activityRepo.ensureUnassignedActivity();
    final running = await _runningEntry();
    if (running == null) {
      await _startUnassigned(at: now);
      return;
    }
    if (running.activityId == unassigned.id) {
      await mergeAdjacentUnassignedEntries(unassigned.id);
      return;
    }
    if (running.startAt.isAfter(now)) {
      await _saveEntry(
        running.copyWith(isDeleted: true, updatedAt: now),
      );
      await _activityRepo.softDeleteOneOffActivityIfNeeded(
        running.activityId,
        now,
      );
      await _startUnassigned(at: now);
      return;
    }
    await _saveEntry(running.copyWith(endAt: now, updatedAt: now));
    await _activityRepo.softDeleteOneOffActivityIfNeeded(
      running.activityId,
      now,
    );
    await _insertActionLog(
      actionType: ActionType.stop,
      activityId: running.activityId,
      entryId: running.id,
      occurredAt: now,
      message: '停止事项',
    );
    await _startUnassigned(at: now);
  }

  Future<List<TimeEntry>> _saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  }) async {
    final db = await _database.db;
    final saved = <TimeEntry>[];
    await db.transaction((txn) async {
      final normalized =
          await _activityRepo.entryWithActivitySnapshot(entry, txn);
      final entries = _entryRowsForStorage(normalized);
      if (cutOverlaps) {
        await _cutOverlappingEntries(txn, entries, normalized.updatedAt);
      }
      await _insertEntryRows(txn, entries);
      saved.addAll(entries);
    });
    if (logEdit) {
      await _insertActionLog(
        actionType: ActionType.edit,
        activityId: entry.activityId,
        entryId: entry.id,
        occurredAt: DateTime.now(),
        message: '编辑时间段',
      );
    }
    return saved;
  }

  Future<List<TimeEntry>> _splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) async {
    final current = await entryById(entryId);
    if (current == null || current.isDeleted || current.isRunning) {
      throw StateError('entry_not_splitable');
    }
    final endAt = current.endAt;
    if (endAt == null ||
        !current.startAt.isBefore(splitAt) ||
        !splitAt.isBefore(endAt)) {
      throw StateError('split_out_of_range');
    }

    final now = DateTime.now();
    final saved = <TimeEntry>[];
    final db = await _database.db;
    await db.transaction((txn) async {
      final first = await _activityRepo.entryWithActivitySnapshot(
        current.copyWith(endAt: splitAt, updatedAt: now),
        txn,
      );
      final second = await _activityRepo.entryWithActivitySnapshot(
        current.copyWith(
          id: _uuid.v4(),
          startAt: splitAt,
          endAt: endAt,
          updatedAt: now,
        ),
        txn,
      );
      saved
        ..addAll(await _saveEntryRows(txn, first))
        ..addAll(await _saveEntryRows(txn, second));
    });
    await _insertActionLog(
      actionType: ActionType.split,
      activityId: current.activityId,
      entryId: current.id,
      occurredAt: now,
      message: '切割时间段',
    );
    return saved;
  }

  Future<TimeEntry> _createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
    String? userId,
  }) async {
    final now = DateTime.now();
    final deviceId = await _currentDeviceId();
    final entry = TimeEntry(
      id: _uuid.v4(),
      userId: userId,
      activityId: activityId,
      startAt: startAt,
      endAt: endAt,
      note: note,
      deviceId: deviceId,
      updatedAt: now,
      isDeleted: false,
    );
    final saved = await _saveEntry(entry, cutOverlaps: true);
    await _insertActionLog(
      actionType: ActionType.manual,
      activityId: activityId,
      entryId: entry.id,
      occurredAt: now,
      message: '补记时间段',
    );
    return saved.first;
  }

  Future<void> _deleteEntry(TimeEntry entry) async {
    await _saveEntry(entry.copyWith(isDeleted: true, updatedAt: DateTime.now()));
    await _insertActionLog(
      actionType: ActionType.delete,
      activityId: entry.activityId,
      entryId: entry.id,
      occurredAt: DateTime.now(),
      message: '删除时间段',
    );
  }

  Future<List<TimeEntry>> _entriesForDay(DateTime day) async {
    final db = await _database.db;
    final start = day.startOfDay.toUtc().toIso8601String();
    final end =
        day.startOfDay.add(const Duration(days: 1)).toUtc().toIso8601String();
    final rows = await db.query(
      'time_entries',
      where: 'is_deleted = 0 and start_at < ? and coalesce(end_at, ?) > ?',
      whereArgs: [end, end, start],
      orderBy: 'start_at asc',
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
      where: 'is_deleted = 0 and start_at < ? and coalesce(end_at, ?) > ?',
      whereArgs: [endStr, endStr, startStr],
      orderBy: 'start_at asc',
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

  Future<TimeEntry?> _mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) async {
    final candidate = await _mergeCandidateForEntry(entryId, direction);
    if (candidate == null) {
      return null;
    }
    if (candidate.requiresConfirmation && !confirmed) {
      throw StateError('merge_confirmation_required');
    }

    final now = DateTime.now();
    final current = candidate.current;
    final neighbor = candidate.neighbor;
    final startAt = current.startAt.isBefore(neighbor.startAt)
        ? current.startAt
        : neighbor.startAt;
    final currentEnd = current.endAt!;
    final neighborEnd = neighbor.endAt!;
    final endAt = currentEnd.isAfter(neighborEnd) ? currentEnd : neighborEnd;
    final merged = current.copyWith(
      startAt: startAt,
      endAt: endAt,
      note: _mergedNotes(current.note, neighbor.note),
      updatedAt: now,
    );

    final db = await _database.db;
    await db.transaction((txn) async {
      await _saveEntryRows(
        txn,
        await _activityRepo.entryWithActivitySnapshot(merged, txn),
      );
      await txn.insert(
        'time_entries',
        neighbor.copyWith(isDeleted: true, updatedAt: now).toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await _insertActionLog(
      actionType: ActionType.merge,
      activityId: merged.activityId,
      entryId: merged.id,
      occurredAt: now,
      message:
          direction == EntryMergeDirection.previous ? '合并左侧' : '合并右侧',
    );
    return merged;
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

  Future<void> _replaceEntryIfRemoteNewer(TimeEntry remote) async {
    final db = await _database.db;
    final localRows = await db.query(
      'time_entries',
      where: 'id = ?',
      whereArgs: [remote.id],
      limit: 1,
    );
    if (localRows.isEmpty ||
        TimeEntry.fromMap(localRows.first)
            .updatedAt
            .isBefore(remote.updatedAt)) {
      await _saveEntry(remote);
    }
  }

  // -------------------------------------------------------------------------
  // Public helpers (not in interface) — used by TimeRepository
  // -------------------------------------------------------------------------

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

  Future<List<TimeEntry>> saveEntryRows(
    DatabaseExecutor executor,
    TimeEntry entry,
  ) async {
    final entries = _entryRowsForStorage(entry);
    await _insertEntryRows(executor, entries);
    return entries;
  }

  Future<void> rolloverRunningEntriesIfNeeded({DateTime? at}) async {
    final now = at ?? DateTime.now();
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
    final now = DateTime.now();
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
      if (withSnapshot.activityNameSnapshot ==
              entry.activityNameSnapshot &&
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

    final now = DateTime.now();
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

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  List<TimeEntry> _entryRowsForStorage(TimeEntry entry) {
    return entry.isDeleted || entry.isRunning
        ? [entry]
        : _splitClosedEntryByLocalDay(entry, entry.updatedAt);
  }

  Future<void> _insertEntryRows(
    DatabaseExecutor executor,
    List<TimeEntry> entries,
  ) async {
    for (final item in entries) {
      await executor.insert(
        'time_entries',
        item.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<TimeEntry>> _saveEntryRows(
    DatabaseExecutor executor,
    TimeEntry entry,
  ) async {
    final entries = _entryRowsForStorage(entry);
    await _insertEntryRows(executor, entries);
    return entries;
  }

  Future<void> _cutOverlappingEntries(
    DatabaseExecutor executor,
    List<TimeEntry> replacements,
    DateTime updatedAt,
  ) async {
    final replacementEntries = replacements
        .where(
          (entry) =>
              !entry.isDeleted &&
              (entry.endAt == null || entry.startAt.isBefore(entry.endAt!)),
        )
        .toList()
      ..sort((first, second) => first.startAt.compareTo(second.startAt));
    if (replacementEntries.isEmpty) {
      return;
    }

    final protectedIds = replacementEntries.map((entry) => entry.id).toSet();
    final firstStart = replacementEntries.first.startAt;
    final hasRunningReplacement = replacementEntries.any(
      (entry) => entry.endAt == null,
    );
    final finiteReplacementEnds = [
      for (final entry in replacementEntries)
        if (entry.endAt != null) entry.endAt!,
    ];
    final lastEnd = finiteReplacementEnds.isEmpty
        ? null
        : finiteReplacementEnds.reduce(
            (first, second) => first.isAfter(second) ? first : second,
          );
    final openEndedSentinel =
        AppConstants.farFutureDate.toUtc().toIso8601String();
    final rows = await executor.query(
      'time_entries',
      where: hasRunningReplacement
          ? 'is_deleted = 0 and coalesce(end_at, ?) > ?'
          : 'is_deleted = 0 and start_at < ? and coalesce(end_at, ?) > ?',
      whereArgs: hasRunningReplacement
          ? [
              openEndedSentinel,
              firstStart.toUtc().toIso8601String(),
            ]
          : [
              lastEnd!.toUtc().toIso8601String(),
              lastEnd.toUtc().toIso8601String(),
              firstStart.toUtc().toIso8601String(),
            ],
      orderBy: 'start_at asc, end_at asc',
    );

    for (final row in rows) {
      final candidate = TimeEntry.fromMap(row);
      if (protectedIds.contains(candidate.id)) {
        continue;
      }
      final pieces = _cutEntryByReplacements(
        candidate,
        replacementEntries,
        updatedAt,
      );
      if (pieces.length == 1 &&
          pieces.single.startAt == candidate.startAt &&
          pieces.single.endAt == candidate.endAt) {
        continue;
      }
      if (pieces.isEmpty) {
        await _insertEntryRows(
          executor,
          [candidate.copyWith(isDeleted: true, updatedAt: updatedAt)],
        );
        continue;
      }
      await _saveEntryRows(executor, pieces.first);
      for (final piece in pieces.skip(1)) {
        await _saveEntryRows(executor, piece);
      }
    }
  }

  List<TimeEntry> _cutEntryByReplacements(
    TimeEntry entry,
    List<TimeEntry> replacements,
    DateTime updatedAt,
  ) {
    var remaining = [_EntryInterval(entry.startAt, entry.endAt)];
    for (final replacement in replacements) {
      final replacementEnd = replacement.endAt;
      final next = <_EntryInterval>[];
      for (final interval in remaining) {
        final intervalEnd = interval.endAt;
        final overlaps = replacementEnd == null
            ? intervalEnd == null || replacement.startAt.isBefore(intervalEnd)
            : interval.startAt.isBefore(replacementEnd) &&
                (intervalEnd == null ||
                    replacement.startAt.isBefore(intervalEnd));
        if (!overlaps) {
          next.add(interval);
          continue;
        }
        if (interval.startAt.isBefore(replacement.startAt)) {
          next.add(_EntryInterval(interval.startAt, replacement.startAt));
        }
        if (replacementEnd != null &&
            (intervalEnd == null || replacementEnd.isBefore(intervalEnd))) {
          next.add(_EntryInterval(replacementEnd, intervalEnd));
        }
      }
      remaining = next;
      if (remaining.isEmpty) {
        break;
      }
    }

    final pieces = <TimeEntry>[];
    var first = true;
    for (final interval in remaining) {
      pieces.add(
        entry.copyWith(
          id: first ? entry.id : _uuid.v4(),
          startAt: interval.startAt,
          endAt: interval.endAt,
          clearEndAt: interval.endAt == null,
          updatedAt: updatedAt,
        ),
      );
      first = false;
    }
    return pieces;
  }

  List<TimeEntry> _splitClosedEntryByLocalDay(
    TimeEntry entry,
    DateTime updatedAt,
  ) {
    final endAt = entry.endAt;
    if (endAt == null || !entry.startAt.isBefore(endAt)) {
      return [entry];
    }
    final entries = <TimeEntry>[];
    var cursor = entry.startAt;
    var first = true;
    while (cursor.isBefore(endAt)) {
      final dayEnd = cursor.startOfDay.add(const Duration(days: 1));
      final segmentEnd = endAt.isBefore(dayEnd) ? endAt : dayEnd;
      if (cursor.isBefore(segmentEnd)) {
        entries.add(
          entry.copyWith(
            id: first ? entry.id : _uuid.v4(),
            startAt: cursor,
            endAt: segmentEnd,
            updatedAt: updatedAt,
          ),
        );
      }
      cursor = segmentEnd;
      first = false;
    }
    return entries.isEmpty ? [entry] : entries;
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

  ActionLog _buildActionLog({
    required ActionType actionType,
    required String? activityId,
    required String? entryId,
    required DateTime occurredAt,
    required String message,
  }) {
    return ActionLog(
      id: _uuid.v4(),
      userId: null,
      actionType: actionType,
      activityId: activityId,
      entryId: entryId,
      message: message,
      occurredAt: occurredAt,
      deviceId: _deviceIdOverride ?? _cachedDeviceId ?? 'local-device',
      updatedAt: DateTime.now(),
      isDeleted: false,
    );
  }

  Future<void> _insertActionLog({
    required ActionType actionType,
    required String? activityId,
    required String? entryId,
    required DateTime occurredAt,
    required String message,
  }) async {
    final db = await _database.db;
    await _currentDeviceId();
    await db.insert(
      'action_logs',
      _buildActionLog(
        actionType: actionType,
        activityId: activityId,
        entryId: entryId,
        occurredAt: occurredAt,
        message: message,
      ).toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> _currentDeviceId() async {
    final override = _deviceIdOverride;
    if (override != null) {
      return override;
    }

    final cached = _cachedDeviceId;
    if (cached != null) {
      return cached;
    }

    final db = await _database.db;
    final rows = await db.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['device_id'],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final value = rows.first['value'] as String;
      _cachedDeviceId = value;
      return value;
    }

    final value = _uuid.v4();
    await db.insert(
      'app_metadata',
      {'key': 'device_id', 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cachedDeviceId = value;
    return value;
  }
}
