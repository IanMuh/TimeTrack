import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/date_time_ext.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';
import 'local_database.dart';

class TimeRepository {
  TimeRepository({
    required LocalDatabase database,
    String? deviceId,
    Uuid? uuid,
  })  : _database = database,
        _deviceId = deviceId ?? 'local-device',
        _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final String _deviceId;
  final Uuid _uuid;

  Future<void> ensureSeedData() async {
    final db = await _database.db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('select count(*) from activities'),
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
  }) async {
    final activity = Activity(
      id: _uuid.v4(),
      userId: userId,
      name: name.trim(),
      color: color,
      isFavorite: true,
      updatedAt: DateTime.now(),
      isDeleted: false,
    );
    await upsertActivity(activity);
    return activity;
  }

  Future<Activity> updateActivity({
    required Activity activity,
    required String name,
    required int color,
  }) async {
    final updated = activity.copyWith(
      name: name.trim(),
      color: color,
      updatedAt: DateTime.now(),
    );
    await upsertActivity(updated);
    return updated;
  }

  Future<void> deleteActivity(Activity activity) async {
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
    final db = await _database.db;
    late TimeEntry next;
    String? previousActivityId;
    await db.transaction((txn) async {
      final runningRows = await txn.query(
        'time_entries',
        where: 'end_at is null and is_deleted = 0',
        orderBy: 'start_at desc',
      );

      for (final row in runningRows) {
        final running = TimeEntry.fromMap(row);
        previousActivityId ??= running.activityId;
        if (running.startAt.isBefore(now)) {
          await txn.insert(
            'time_entries',
            running.copyWith(endAt: now, updatedAt: now).toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          await txn.insert(
            'time_entries',
            running.copyWith(isDeleted: true, updatedAt: now).toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      next = TimeEntry(
        id: _uuid.v4(),
        userId: null,
        activityId: activityId,
        startAt: now,
        endAt: null,
        note: '',
        deviceId: _deviceId,
        updatedAt: now,
        isDeleted: false,
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
    return next;
  }

  Future<void> stopRunning({DateTime? at}) async {
    final now = at ?? DateTime.now();
    final running = await runningEntry();
    if (running == null) {
      return;
    }
    if (running.startAt.isAfter(now)) {
      await saveEntry(running.copyWith(isDeleted: true, updatedAt: now));
      return;
    }
    await saveEntry(running.copyWith(endAt: now, updatedAt: now));
    await addActionLog(
      actionType: 'stop',
      activityId: running.activityId,
      entryId: running.id,
      occurredAt: now,
      message: '停止事项',
    );
  }

  Future<void> saveEntry(TimeEntry entry, {bool logEdit = false}) async {
    final db = await _database.db;
    await db.insert(
      'time_entries',
      entry.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (logEdit) {
      await addActionLog(
        actionType: 'edit',
        activityId: entry.activityId,
        entryId: entry.id,
        occurredAt: DateTime.now(),
        message: '编辑时间段',
      );
    }
  }

  Future<TimeEntry> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
    String? userId,
  }) async {
    final now = DateTime.now();
    final entry = TimeEntry(
      id: _uuid.v4(),
      userId: userId,
      activityId: activityId,
      startAt: startAt,
      endAt: endAt,
      note: note,
      deviceId: _deviceId,
      updatedAt: now,
      isDeleted: false,
    );
    await saveEntry(entry);
    await addActionLog(
      actionType: 'manual',
      activityId: activityId,
      entryId: entry.id,
      occurredAt: now,
      message: '补记时间段',
    );
    return entry;
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
    final end = day.endOfDay.toUtc().toIso8601String();
    final rows = await db.query(
      'time_entries',
      where: 'is_deleted = 0 and start_at <= ? and coalesce(end_at, ?) >= ?',
      whereArgs: [end, end, start],
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

  Future<void> addActionLog({
    required String actionType,
    required String? activityId,
    required String? entryId,
    required DateTime occurredAt,
    required String message,
  }) async {
    final db = await _database.db;
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
      deviceId: _deviceId,
      updatedAt: DateTime.now(),
      isDeleted: false,
    );
  }
}
