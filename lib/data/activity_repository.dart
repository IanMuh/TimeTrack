import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/app_constants.dart';
import '../core/model_utils.dart';
import '../core/result.dart';
import '../domain/activity.dart';
import '../domain/time_entry.dart';
import 'local_database.dart';
import 'repository_interfaces.dart';

class ActivityRepository implements IActivityRepository {
  ActivityRepository({
    required LocalDatabase database,
    Uuid? uuid,
  })  : _database = database,
        _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  // ---------------------------------------------------------------------------
  // IActivityRepository — AppResult-wrapped public API
  // ---------------------------------------------------------------------------

  @override
  Future<AppResult<List<Activity>>> activities({
    bool includeDeleted = false,
  }) async {
    try {
      final db = await _database.db;
      final rows = await db.query(
        'activities',
        where: includeDeleted ? null : 'is_deleted = 0',
        orderBy: 'is_favorite desc, name asc',
      );
      return AppSuccess(rows.map(Activity.fromMap).toList());
    } catch (e) {
      return AppFailure('Failed to load activities: $e');
    }
  }

  @override
  Future<AppResult<List<Activity>>> oneOffActivities({
    bool includeDeleted = true,
  }) async {
    try {
      final db = await _database.db;
      final rows = await db.query(
        'activities',
        where: includeDeleted
            ? 'is_one_off = 1'
            : 'is_one_off = 1 and is_deleted = 0',
        orderBy: 'updated_at desc, name asc',
      );
      return AppSuccess(rows.map(Activity.fromMap).toList());
    } catch (e) {
      return AppFailure('Failed to load one-off activities: $e');
    }
  }

  @override
  Future<AppResult<Activity>> unassignedActivity() async {
    try {
      final activity = await ensureUnassignedActivity();
      return AppSuccess(activity);
    } catch (e) {
      return AppFailure('Failed to ensure unassigned activity: $e');
    }
  }

  @override
  Future<AppResult<Activity>> createActivity({
    required String name,
    required int color,
    String? userId,
    bool isOneOff = false,
  }) async {
    try {
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
      await _upsert(activity);
      return AppSuccess(activity);
    } catch (e) {
      return AppFailure('Failed to create activity: $e');
    }
  }

  @override
  Future<AppResult<Activity>> updateActivity({
    required Activity activity,
    required String name,
    required int color,
  }) async {
    try {
      if (activity.isUnassigned ||
          await activityIdIsUnassigned(activity.id)) {
        final unassigned = await ensureUnassignedActivity();
        return AppSuccess(unassigned);
      }
      final updated = activity.copyWith(
        name: name.trim(),
        color: color,
        updatedAt: DateTime.now(),
      );
      await _upsert(updated);
      return AppSuccess(updated);
    } catch (e) {
      return AppFailure('Failed to update activity: $e');
    }
  }

  @override
  Future<AppResult<Activity>> restoreOneOffActivity(Activity activity) async {
    try {
      final restored = activity.copyWith(
        isDeleted: false,
        isFavorite: false,
        isOneOff: true,
        updatedAt: DateTime.now(),
      );
      await _upsert(restored);
      return AppSuccess(restored);
    } catch (e) {
      return AppFailure('Failed to restore one-off activity: $e');
    }
  }

  @override
  Future<AppResult<void>> deleteActivity(Activity activity) async {
    try {
      if (activity.isUnassigned) {
        return const AppSuccess(null);
      }
      await _upsert(
        activity.copyWith(
          isDeleted: true,
          updatedAt: DateTime.now(),
        ),
      );
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to delete activity: $e');
    }
  }

  @override
  Future<AppResult<void>> upsertActivity(Activity activity) async {
    try {
      await _upsert(activity);
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to upsert activity: $e');
    }
  }

  @override
  Future<AppResult<void>> replaceActivityIfRemoteNewer(Activity remote) async {
    try {
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
        await _upsert(remote);
      }
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to replace activity: $e');
    }
  }

  @override
  Future<AppResult<List<Activity>>> activitiesSince(DateTime since) async {
    try {
      final db = await _database.db;
      final rows = await db.query(
        'activities',
        where: 'updated_at >= ?',
        whereArgs: [since.toUtc().toIso8601String()],
        orderBy: 'updated_at asc',
      );
      return AppSuccess(rows.map(Activity.fromMap).toList());
    } catch (e) {
      return AppFailure('Failed to load activities since: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers — used by TimeRepository for cross-domain operations
  // ---------------------------------------------------------------------------

  /// Raw upsert without AppResult wrapping (used by internal callers).
  Future<void> _upsert(Activity activity) async {
    final db = await _database.db;
    await db.insert(
      'activities',
      activity.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Activity?> activityById(
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

  Future<void> softDeleteOneOffActivityIfNeeded(
    String activityId,
    DateTime updatedAt, [
    DatabaseExecutor? executor,
  ]) async {
    final target = executor ?? await _database.db;
    final activity = await activityById(activityId, target);
    if (activity == null || !activity.isOneOff || activity.isDeleted) {
      return;
    }
    await target.insert(
      'activities',
      activity.copyWith(isDeleted: true, updatedAt: updatedAt).toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Activity> ensureUnassignedActivity() async {
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
        await _upsert(keep);
      }
      for (final row in rows.skip(1)) {
        final duplicate = Activity.fromMap(row);
        await _upsert(
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
      await _upsert(legacy);
      return legacy;
    }

    final now = DateTime.now();
    final activity = Activity(
      id: _uuid.v4(),
      userId: null,
      name: '未安排',
      color: AppConstants.defaultActivityColor,
      isFavorite: false,
      updatedAt: now,
      isDeleted: false,
      isUnassigned: true,
    );
    await _upsert(activity);
    return activity;
  }

  Future<bool> activityIdIsUnassigned(String activityId) async {
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
    return readBool(rows.first['is_unassigned']);
  }

  Future<TimeEntry> entryWithActivitySnapshot(
    TimeEntry entry,
    DatabaseExecutor executor,
  ) async {
    final activity = await activityById(entry.activityId, executor);
    if (activity == null) {
      return entry;
    }
    return entry.copyWith(
      activityNameSnapshot: activity.name,
      activityColorSnapshot: activity.color,
    );
  }

  /// Inserts seed activities if none exist (called by TimeRepository.ensureSeedData).
  Future<void> seedActivities() async {
    final db = await _database.db;
    final count = Sqflite.firstIntValue(
      await db
          .rawQuery('select count(*) from activities where is_unassigned = 0'),
    );
    if (count != 0) return;

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
      await _upsert(activity);
    }
  }
}
