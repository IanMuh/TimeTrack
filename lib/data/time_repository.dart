import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/date_time_ext.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';
import 'local_database.dart';
import 'repository_undo.dart';
import 'sync_bundle.dart';

enum EntryMergeDirection { previous, next }

class EntryMergeCandidate {
  const EntryMergeCandidate({
    required this.current,
    required this.neighbor,
    required this.direction,
    required this.neighborDuration,
    required this.threshold,
  });

  final TimeEntry current;
  final TimeEntry neighbor;
  final EntryMergeDirection direction;
  final Duration neighborDuration;
  final Duration threshold;

  bool get requiresConfirmation => neighborDuration > threshold;
}

class _EntryInterval {
  const _EntryInterval(this.startAt, this.endAt);

  final DateTime startAt;
  final DateTime? endAt;
}

class TimeRepository {
  TimeRepository({
    required LocalDatabase database,
    String? deviceId,
    Uuid? uuid,
  })  : _database = database,
        _deviceIdOverride = deviceId,
        _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final String? _deviceIdOverride;
  final Uuid _uuid;
  String? _cachedDeviceId;

  Future<void> ensureSeedData() async {
    final db = await _database.db;
    final unassigned = await _ensureUnassignedActivity();
    await _mergeAdjacentUnassignedEntries(unassigned.id);
    await normalizeStoredCrossDayEntries();
    await rolloverRunningEntriesIfNeeded();
    await backfillMissingEntrySnapshots();
    final count = Sqflite.firstIntValue(
      await db
          .rawQuery('select count(*) from activities where is_unassigned = 0'),
    );
    if (count == 0) {
      final now = DateTime.now();
      final seed = [
        Activity(
          id: _uuid.v4(),
          userId: null,
          name: '工作',
          color: 0xff2563eb,
          isFavorite: true,
          updatedAt: now,
          isDeleted: false,
        ),
        Activity(
          id: _uuid.v4(),
          userId: null,
          name: '学习',
          color: 0xff059669,
          isFavorite: true,
          updatedAt: now,
          isDeleted: false,
        ),
        Activity(
          id: _uuid.v4(),
          userId: null,
          name: '通勤',
          color: 0xffd97706,
          isFavorite: true,
          updatedAt: now,
          isDeleted: false,
        ),
        Activity(
          id: _uuid.v4(),
          userId: null,
          name: '休息',
          color: 0xff7c3aed,
          isFavorite: true,
          updatedAt: now,
          isDeleted: false,
        ),
      ];
      for (final activity in seed) {
        await upsertActivity(activity);
      }
    }

    final settingsCount = Sqflite.firstIntValue(
      await db.rawQuery('select count(*) from profile_settings'),
    );
    if (settingsCount == 0) {
      await saveSettings(ProfileSettings.defaults());
    }
  }

  Future<List<Activity>> activities({bool includeDeleted = false}) async {
    final db = await _database.db;
    final rows = await db.query(
      'activities',
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'is_favorite desc, name asc',
    );
    return rows.map(Activity.fromMap).toList();
  }

  Future<List<Activity>> oneOffActivities({
    bool includeDeleted = true,
  }) async {
    final db = await _database.db;
    final rows = await db.query(
      'activities',
      where: includeDeleted
          ? 'is_one_off = 1'
          : 'is_one_off = 1 and is_deleted = 0',
      orderBy: 'updated_at desc, name asc',
    );
    return rows.map(Activity.fromMap).toList();
  }

  Future<Activity> unassignedActivity() async {
    return _ensureUnassignedActivity();
  }

  Future<SyncBundle> exportBundle() async {
    final deviceId = await currentDeviceId();
    return SyncBundle(
      schemaVersion: SyncBundle.currentSchemaVersion,
      exportedAt: DateTime.now(),
      sourceDeviceId: deviceId,
      activities: await activities(includeDeleted: true),
      timeEntries: await allEntries(),
      actionLogs: await allActionLogs(),
      profileSettings: await settings(),
    );
  }

  Future<void> mergeBundle(SyncBundle bundle) async {
    if (bundle.schemaVersion != SyncBundle.currentSchemaVersion) {
      throw FormatException(
        'Unsupported TimeTrack sync schema version: ${bundle.schemaVersion}.',
      );
    }

    final db = await _database.db;
    await db.transaction((txn) async {
      for (final activity in bundle.activities) {
        final localRows = await txn.query(
          'activities',
          where: 'id = ?',
          whereArgs: [activity.id],
          limit: 1,
        );
        if (_shouldReplace(localRows, Activity.fromMap, activity.updatedAt)) {
          await txn.insert(
            'activities',
            activity.toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      for (final entry in bundle.timeEntries) {
        final localRows = await txn.query(
          'time_entries',
          where: 'id = ?',
          whereArgs: [entry.id],
          limit: 1,
        );
        if (_shouldReplace(localRows, TimeEntry.fromMap, entry.updatedAt)) {
          await txn.insert(
            'time_entries',
            entry.toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      for (final log in bundle.actionLogs) {
        final localRows = await txn.query(
          'action_logs',
          where: 'id = ?',
          whereArgs: [log.id],
          limit: 1,
        );
        if (_shouldReplace(localRows, ActionLog.fromMap, log.updatedAt)) {
          await txn.insert(
            'action_logs',
            log.toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      final settingsRows = await txn.query('profile_settings', limit: 1);
      if (_shouldReplace(
        settingsRows,
        ProfileSettings.fromMap,
        bundle.profileSettings.updatedAt,
      )) {
        await txn.insert(
          'profile_settings',
          bundle.profileSettings.toLocalMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    await normalizeRunningEntriesAfterMerge();
    await normalizeStoredCrossDayEntries();
    await backfillMissingEntrySnapshots();
    final unassigned = await _ensureUnassignedActivity();
    await _mergeAdjacentUnassignedEntries(unassigned.id);
  }

  Future<void> upsertActivity(Activity activity) async {
    final db = await _database.db;
    await db.insert(
      'activities',
      activity.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Activity> createActivity({
    required String name,
    required int color,
    String? userId,
    bool isOneOff = false,
  }) async {
    final activity = Activity(
      id: _uuid.v4(),
      userId: userId,
      name: name.trim(),
      color: color,
      isFavorite: !isOneOff,
      updatedAt: DateTime.now(),
      isDeleted: false,
      isOneOff: isOneOff,
    );
    await upsertActivity(activity);
    return activity;
  }

  Future<Activity> updateActivity({
    required Activity activity,
    required String name,
    required int color,
  }) async {
    if (activity.isUnassigned || await _activityIdIsUnassigned(activity.id)) {
      return _ensureUnassignedActivity();
    }
    final updated = activity.copyWith(
      name: name.trim(),
      color: color,
      updatedAt: DateTime.now(),
    );
    await upsertActivity(updated);
    return updated;
  }

  Future<Activity> restoreOneOffActivity(Activity activity) async {
    final restored = activity.copyWith(
      isDeleted: false,
      isFavorite: false,
      isOneOff: true,
      updatedAt: DateTime.now(),
    );
    await upsertActivity(restored);
    return restored;
  }

  Future<void> deleteActivity(Activity activity) async {
    if (activity.isUnassigned) {
      return;
    }
    final now = DateTime.now();
    final running = await runningEntry();
    if (running?.activityId == activity.id) {
      await stopRunning(at: now);
    }
    await upsertActivity(
      activity.copyWith(
        isDeleted: true,
        updatedAt: now,
      ),
    );
    await addActionLog(
      actionType: 'activity_delete',
      activityId: activity.id,
      entryId: null,
      occurredAt: now,
      message: '删除事项',
    );
  }

  Future<TimeEntry?> runningEntry() async {
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

  Future<TimeEntry> switchToActivity(String activityId, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    await rolloverRunningEntriesIfNeeded(at: now);
    final deviceId = await currentDeviceId();
    final targetIsUnassigned = await _activityIdIsUnassigned(activityId);
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
            await _entryWithActivitySnapshot(
              running.copyWith(endAt: now, updatedAt: now),
              txn,
            ),
          );
          await _softDeleteOneOffActivityIfNeeded(
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
          await _softDeleteOneOffActivityIfNeeded(
            running.activityId,
            now,
            txn,
          );
        }
      }

      next = await _entryWithActivitySnapshot(
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
          actionType: 'switch',
          activityId: activityId,
          entryId: next.id,
          occurredAt: now,
          message: previousActivityId == null ? '开始事项' : '切换事项',
        ).toLocalMap(),
      );
    });
    if (targetIsUnassigned) {
      await _mergeAdjacentUnassignedEntries(activityId);
      return await runningEntry() ?? next;
    }
    return next;
  }

  Future<void> stopRunning({DateTime? at}) async {
    final now = at ?? DateTime.now();
    await rolloverRunningEntriesIfNeeded(at: now);
    final unassigned = await _ensureUnassignedActivity();
    final running = await runningEntry();
    if (running == null) {
      await _startUnassigned(at: now);
      return;
    }
    if (running.activityId == unassigned.id) {
      await _mergeAdjacentUnassignedEntries(unassigned.id);
      return;
    }
    if (running.startAt.isAfter(now)) {
      await saveEntry(running.copyWith(isDeleted: true, updatedAt: now));
      await _softDeleteOneOffActivityIfNeeded(running.activityId, now);
      await _startUnassigned(at: now);
      return;
    }
    await saveEntry(running.copyWith(endAt: now, updatedAt: now));
    await _softDeleteOneOffActivityIfNeeded(running.activityId, now);
    await addActionLog(
      actionType: 'stop',
      activityId: running.activityId,
      entryId: running.id,
      occurredAt: now,
      message: '停止事项',
    );
    await _startUnassigned(at: now);
  }

  Future<List<TimeEntry>> saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  }) async {
    final db = await _database.db;
    final saved = <TimeEntry>[];
    await db.transaction((txn) async {
      final normalized = await _entryWithActivitySnapshot(entry, txn);
      final entries = _entryRowsForStorage(normalized);
      if (cutOverlaps) {
        await _cutOverlappingEntries(txn, entries, normalized.updatedAt);
      }
      await _insertEntryRows(txn, entries);
      saved.addAll(entries);
    });
    if (logEdit) {
      await addActionLog(
        actionType: 'edit',
        activityId: entry.activityId,
        entryId: entry.id,
        occurredAt: DateTime.now(),
        message: '编辑时间段',
      );
    }
    return saved;
  }

  Future<List<TimeEntry>> splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) async {
    final current = await _entryById(entryId);
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
      final first = await _entryWithActivitySnapshot(
        current.copyWith(endAt: splitAt, updatedAt: now),
        txn,
      );
      final second = await _entryWithActivitySnapshot(
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
    await addActionLog(
      actionType: 'split',
      activityId: current.activityId,
      entryId: current.id,
      occurredAt: now,
      message: '切割时间段',
    );
    return saved;
  }

  Future<TimeEntry> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
    String? userId,
  }) async {
    final now = DateTime.now();
    final deviceId = await currentDeviceId();
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
    final saved = await saveEntry(entry, cutOverlaps: true);
    await addActionLog(
      actionType: 'manual',
      activityId: activityId,
      entryId: entry.id,
      occurredAt: now,
      message: '补记时间段',
    );
    return saved.first;
  }

  Future<void> deleteEntry(TimeEntry entry) async {
    await saveEntry(entry.copyWith(isDeleted: true, updatedAt: DateTime.now()));
    await addActionLog(
      actionType: 'delete',
      activityId: entry.activityId,
      entryId: entry.id,
      occurredAt: DateTime.now(),
      message: '删除时间段',
    );
  }

  Future<List<TimeEntry>> entriesForDay(DateTime day) async {
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

  /// Returns entries that overlap with [start, end).
  /// [end] is exclusive: an entry starting exactly at [end] is excluded.
  Future<List<TimeEntry>> entriesForRange(
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

  Future<List<TimeEntry>> entriesSince(DateTime since) async {
    final db = await _database.db;
    final rows = await db.query(
      'time_entries',
      where: 'updated_at >= ?',
      whereArgs: [since.toUtc().toIso8601String()],
      orderBy: 'updated_at asc',
    );
    return rows.map(TimeEntry.fromMap).toList();
  }

  Future<List<TimeEntry>> allEntries() async {
    final db = await _database.db;
    final rows = await db.query(
      'time_entries',
      orderBy: 'updated_at asc',
    );
    return rows.map(TimeEntry.fromMap).toList();
  }

  Future<List<ActionLog>> actionLogsForDay(DateTime day) async {
    final db = await _database.db;
    final start = day.startOfDay.toUtc().toIso8601String();
    final end = day.endOfDay.toUtc().toIso8601String();
    final rows = await db.query(
      'action_logs',
      where: 'is_deleted = 0 and occurred_at >= ? and occurred_at <= ?',
      whereArgs: [start, end],
      orderBy: 'occurred_at asc',
    );
    return rows.map(ActionLog.fromMap).toList();
  }

  Future<List<ActionLog>> actionLogsForRange(
    DateTime start,
    DateTime end,
  ) async {
    if (!start.isBefore(end)) {
      return const [];
    }
    final db = await _database.db;
    final startValue = start.toUtc().toIso8601String();
    final endValue = end.toUtc().toIso8601String();
    final rows = await db.query(
      'action_logs',
      where: 'is_deleted = 0 and occurred_at >= ? and occurred_at < ?',
      whereArgs: [startValue, endValue],
      orderBy: 'occurred_at asc',
    );
    return rows.map(ActionLog.fromMap).toList();
  }

  Future<List<ActionLog>> actionLogsSince(DateTime since) async {
    final db = await _database.db;
    final rows = await db.query(
      'action_logs',
      where: 'updated_at >= ?',
      whereArgs: [since.toUtc().toIso8601String()],
      orderBy: 'updated_at asc',
    );
    return rows.map(ActionLog.fromMap).toList();
  }

  Future<List<ActionLog>> allActionLogs() async {
    final db = await _database.db;
    final rows = await db.query(
      'action_logs',
      orderBy: 'updated_at asc',
    );
    return rows.map(ActionLog.fromMap).toList();
  }

  Future<RepositoryUndoSnapshot> undoSnapshot() async {
    final activityRows = await activities(includeDeleted: true);
    final entryRows = await allEntries();
    final logRows = await allActionLogs();
    return RepositoryUndoSnapshot(
      activities: {
        for (final activity in activityRows) activity.id: activity,
      },
      timeEntries: {
        for (final entry in entryRows) entry.id: entry,
      },
      actionLogs: {
        for (final log in logRows) log.id: log,
      },
    );
  }

  Future<void> applyUndoChangeSet(
    RepositoryUndoChangeSet changeSet, {
    required RepositoryUndoDirection direction,
  }) async {
    if (changeSet.isEmpty) {
      return;
    }
    final db = await _database.db;
    final updatedAt = DateTime.now();
    await db.transaction((txn) async {
      await _validateUndoChangeSet(txn, changeSet, direction);
      for (final change in changeSet.activities) {
        await _applyActivityUndoChange(txn, change, direction, updatedAt);
      }
      for (final change in changeSet.timeEntries) {
        await _applyEntryUndoChange(txn, change, direction, updatedAt);
      }
      for (final change in changeSet.actionLogs) {
        await _applyActionLogUndoChange(txn, change, direction, updatedAt);
      }
    });
    final actionLabel = direction == RepositoryUndoDirection.undo ? '撤销' : '重做';
    await addActionLog(
      actionType: direction == RepositoryUndoDirection.undo ? 'undo' : 'redo',
      activityId: null,
      entryId: null,
      occurredAt: updatedAt,
      message: '$actionLabel：${changeSet.label}',
    );
  }

  Future<void> addActionLog({
    required String actionType,
    required String? activityId,
    required String? entryId,
    required DateTime occurredAt,
    required String message,
  }) async {
    final db = await _database.db;
    await currentDeviceId();
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

  Future<void> replaceActionLogIfRemoteNewer(ActionLog remote) async {
    final db = await _database.db;
    final localRows = await db.query(
      'action_logs',
      where: 'id = ?',
      whereArgs: [remote.id],
      limit: 1,
    );
    if (localRows.isEmpty ||
        ActionLog.fromMap(localRows.first)
            .updatedAt
            .isBefore(remote.updatedAt)) {
      await db.insert(
        'action_logs',
        remote.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Activity>> activitiesSince(DateTime since) async {
    final db = await _database.db;
    final rows = await db.query(
      'activities',
      where: 'updated_at >= ?',
      whereArgs: [since.toUtc().toIso8601String()],
      orderBy: 'updated_at asc',
    );
    return rows.map(Activity.fromMap).toList();
  }

  Future<EntryMergeCandidate?> mergeCandidateForEntry(
    String entryId,
    EntryMergeDirection direction,
  ) async {
    final current = await _entryById(entryId);
    if (current == null || current.isDeleted || current.isRunning) {
      return null;
    }
    final settings = await this.settings();
    final threshold = Duration(
      minutes: settings.mergeNeighborThresholdMinutes,
    );
    final entries = (await entriesForDay(current.startAt))
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

  Future<TimeEntry?> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) async {
    final candidate = await mergeCandidateForEntry(entryId, direction);
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
      await _saveEntryRows(txn, await _entryWithActivitySnapshot(merged, txn));
      await txn.insert(
        'time_entries',
        neighbor.copyWith(isDeleted: true, updatedAt: now).toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await addActionLog(
      actionType: 'merge',
      activityId: merged.activityId,
      entryId: merged.id,
      occurredAt: now,
      message: direction == EntryMergeDirection.previous ? '合并左侧' : '合并右侧',
    );
    return merged;
  }

  Future<List<TimeEntry>> overlappingEntries(TimeEntry entry) async {
    final dayEntries = await entriesForDay(entry.startAt);
    return dayEntries
        .where((candidate) =>
            candidate.id != entry.id &&
            !candidate.isDeleted &&
            candidate.overlaps(entry))
        .toList();
  }

  Future<ProfileSettings> settings() async {
    final db = await _database.db;
    final rows = await db.query('profile_settings', limit: 1);
    if (rows.isEmpty) {
      final defaults = ProfileSettings.defaults();
      await saveSettings(defaults);
      return defaults;
    }
    return ProfileSettings.fromMap(rows.first);
  }

  Future<void> saveSettings(ProfileSettings settings) async {
    final db = await _database.db;
    await db.insert(
      'profile_settings',
      settings.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceSettingsIfRemoteNewer(ProfileSettings remote) async {
    final local = await settings();
    if (local.updatedAt.isBefore(remote.updatedAt)) {
      await saveSettings(remote);
    }
  }

  Future<void> replaceActivityIfRemoteNewer(Activity remote) async {
    final db = await _database.db;
    final localRows = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: [remote.id],
      limit: 1,
    );
    if (localRows.isEmpty ||
        Activity.fromMap(localRows.first)
            .updatedAt
            .isBefore(remote.updatedAt)) {
      await upsertActivity(remote);
    }
  }

  Future<void> replaceEntryIfRemoteNewer(TimeEntry remote) async {
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
      await saveEntry(remote);
    }
  }

  Future<String> currentDeviceId() async {
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
      await saveEntry(entry);
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
      final withSnapshot = await _entryWithActivitySnapshot(entry, db);
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
        final running = await _entryWithActivitySnapshot(
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

  Future<TimeEntry?> _entryById(String entryId) async {
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

  Future<void> _validateUndoChangeSet(
    DatabaseExecutor executor,
    RepositoryUndoChangeSet changeSet,
    RepositoryUndoDirection direction,
  ) async {
    for (final change in changeSet.activities) {
      final current = await _activityById(change.id, executor);
      if (!_rowMatchesExpected<Activity>(
        current: current,
        expected: change.expectedFor(direction),
        toMap: (value) => value.toLocalMap(),
        isDeleted: (value) => value.isDeleted,
      )) {
        throw _undoConflict(direction);
      }
    }
    for (final change in changeSet.timeEntries) {
      final current = await _entryByIdWithExecutor(change.id, executor);
      if (!_rowMatchesExpected<TimeEntry>(
        current: current,
        expected: change.expectedFor(direction),
        toMap: (value) => value.toLocalMap(),
        isDeleted: (value) => value.isDeleted,
      )) {
        throw _undoConflict(direction);
      }
    }
    for (final change in changeSet.actionLogs) {
      final current = await _actionLogById(change.id, executor);
      if (!_rowMatchesExpected<ActionLog>(
        current: current,
        expected: change.expectedFor(direction),
        toMap: (value) => value.toLocalMap(),
        isDeleted: (value) => value.isDeleted,
      )) {
        throw _undoConflict(direction);
      }
    }
  }

  RepositoryUndoConflictException _undoConflict(
    RepositoryUndoDirection direction,
  ) {
    final actionLabel = direction == RepositoryUndoDirection.undo ? '撤销' : '重做';
    return RepositoryUndoConflictException('数据已变化，无法$actionLabel。');
  }

  Future<void> _applyActivityUndoChange(
    DatabaseExecutor executor,
    RepositoryUndoRowChange<Activity> change,
    RepositoryUndoDirection direction,
    DateTime updatedAt,
  ) async {
    final target = change.targetFor(direction);
    final fallback = change.fallbackFor(direction);
    final value = target?.copyWith(updatedAt: updatedAt) ??
        fallback?.copyWith(isDeleted: true, updatedAt: updatedAt);
    if (value == null) {
      return;
    }
    await executor.insert(
      'activities',
      value.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _applyEntryUndoChange(
    DatabaseExecutor executor,
    RepositoryUndoRowChange<TimeEntry> change,
    RepositoryUndoDirection direction,
    DateTime updatedAt,
  ) async {
    final target = change.targetFor(direction);
    final fallback = change.fallbackFor(direction);
    final value = target?.copyWith(updatedAt: updatedAt) ??
        fallback?.copyWith(isDeleted: true, updatedAt: updatedAt);
    if (value == null) {
      return;
    }
    await executor.insert(
      'time_entries',
      value.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _applyActionLogUndoChange(
    DatabaseExecutor executor,
    RepositoryUndoRowChange<ActionLog> change,
    RepositoryUndoDirection direction,
    DateTime updatedAt,
  ) async {
    final target = change.targetFor(direction);
    final fallback = change.fallbackFor(direction);
    final value = target?.copyWith(updatedAt: updatedAt) ??
        fallback?.copyWith(isDeleted: true, updatedAt: updatedAt);
    if (value == null) {
      return;
    }
    await executor.insert(
      'action_logs',
      value.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<TimeEntry?> _entryByIdWithExecutor(
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

  Future<ActionLog?> _actionLogById(
    String logId,
    DatabaseExecutor executor,
  ) async {
    final rows = await executor.query(
      'action_logs',
      where: 'id = ?',
      whereArgs: [logId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ActionLog.fromMap(rows.first);
  }

  bool _rowMatchesExpected<T>({
    required T? current,
    required T? expected,
    required Map<String, Object?> Function(T value) toMap,
    required bool Function(T value) isDeleted,
  }) {
    if (expected == null) {
      return current == null || isDeleted(current);
    }
    if (current == null) {
      return isDeleted(expected);
    }
    return _comparableMapsEqual(toMap(current), toMap(expected));
  }

  bool _comparableMapsEqual(
    Map<String, Object?> current,
    Map<String, Object?> expected,
  ) {
    final currentComparable = _comparableUndoMap(current);
    final expectedComparable = _comparableUndoMap(expected);
    if (currentComparable.length != expectedComparable.length) {
      return false;
    }
    for (final entry in currentComparable.entries) {
      if (expectedComparable[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  Map<String, Object?> _comparableUndoMap(Map<String, Object?> value) {
    return {...value}
      ..remove('updated_at')
      ..remove('user_id');
  }

  Future<Activity?> _activityById(
    String activityId,
    DatabaseExecutor executor,
  ) async {
    final rows = await executor.query(
      'activities',
      where: 'id = ?',
      whereArgs: [activityId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Activity.fromMap(rows.first);
  }

  Future<TimeEntry> _entryWithActivitySnapshot(
    TimeEntry entry,
    DatabaseExecutor executor,
  ) async {
    final activity = await _activityById(entry.activityId, executor);
    if (activity == null) {
      return entry;
    }
    return entry.copyWith(
      activityNameSnapshot: activity.name,
      activityColorSnapshot: activity.color,
    );
  }

  Future<List<TimeEntry>> _saveEntryRows(
    DatabaseExecutor executor,
    TimeEntry entry,
  ) async {
    final entries = _entryRowsForStorage(entry);
    await _insertEntryRows(executor, entries);
    return entries;
  }

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
    final openEndedSentinel = DateTime(9999).toUtc().toIso8601String();
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

  Future<void> _softDeleteOneOffActivityIfNeeded(
    String activityId,
    DateTime updatedAt, [
    DatabaseExecutor? executor,
  ]) async {
    final target = executor ?? await _database.db;
    final activity = await _activityById(activityId, target);
    if (activity == null || !activity.isOneOff || activity.isDeleted) {
      return;
    }
    await target.insert(
      'activities',
      activity.copyWith(isDeleted: true, updatedAt: updatedAt).toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Activity> _ensureUnassignedActivity() async {
    final db = await _database.db;
    final rows = await db.query(
      'activities',
      where: 'is_unassigned = 1',
      orderBy: 'is_deleted asc, updated_at desc',
    );
    if (rows.isNotEmpty) {
      var keep = Activity.fromMap(rows.first);
      if (keep.isDeleted) {
        keep = keep.copyWith(isDeleted: false, updatedAt: DateTime.now());
        await upsertActivity(keep);
      }
      for (final row in rows.skip(1)) {
        final duplicate = Activity.fromMap(row);
        await upsertActivity(
          duplicate.copyWith(isDeleted: true, updatedAt: DateTime.now()),
        );
      }
      return keep;
    }

    final legacyRows = await db.query(
      'activities',
      where: 'name = ? and is_deleted = 0',
      whereArgs: ['未安排'],
      orderBy: 'updated_at desc',
      limit: 1,
    );
    if (legacyRows.isNotEmpty) {
      final legacy = Activity.fromMap(legacyRows.first).copyWith(
        isFavorite: false,
        isUnassigned: true,
        updatedAt: DateTime.now(),
      );
      await upsertActivity(legacy);
      return legacy;
    }

    final now = DateTime.now();
    final activity = Activity(
      id: _uuid.v4(),
      userId: null,
      name: '未安排',
      color: 0xff64748b,
      isFavorite: false,
      updatedAt: now,
      isDeleted: false,
      isUnassigned: true,
    );
    await upsertActivity(activity);
    return activity;
  }

  Future<void> _startUnassigned({required DateTime at}) async {
    final activity = await _ensureUnassignedActivity();
    final running = await runningEntry();
    if (running?.activityId == activity.id) {
      await _mergeAdjacentUnassignedEntries(activity.id);
      return;
    }
    await switchToActivity(activity.id, at: at);
  }

  Future<bool> _activityIdIsUnassigned(String activityId) async {
    final db = await _database.db;
    final rows = await db.query(
      'activities',
      columns: ['is_unassigned'],
      where: 'id = ?',
      whereArgs: [activityId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return false;
    }
    return _readBool(rows.first['is_unassigned']);
  }

  Future<void> _mergeAdjacentUnassignedEntries(String activityId) async {
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

  bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    return false;
  }

  bool _shouldReplace<T>(
    List<Map<String, Object?>> localRows,
    T Function(Map<String, Object?> map) fromMap,
    DateTime remoteUpdatedAt,
  ) {
    if (localRows.isEmpty) {
      return true;
    }
    final local = fromMap(localRows.first);
    final localUpdatedAt = switch (local) {
      Activity value => value.updatedAt,
      TimeEntry value => value.updatedAt,
      ActionLog value => value.updatedAt,
      ProfileSettings value => value.updatedAt,
      _ => throw StateError('Unsupported sync model type: $T'),
    };
    return localUpdatedAt.isBefore(remoteUpdatedAt);
  }

  ActionLog _buildActionLog({
    required String actionType,
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
}
