import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/date_time_ext.dart';
import '../core/result.dart';
import '../domain/action_log.dart';
import 'local_database.dart';
import 'repository_interfaces.dart';

class ActionLogRepository implements IActionLogRepository {
  ActionLogRepository({
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

  // -------------------------------------------------------------------------
  // IActionLogRepository — AppResult-wrapped public API
  // -------------------------------------------------------------------------

  @override
  Future<AppResult<List<ActionLog>>> actionLogsForDay(DateTime day) async {
    try {
      return AppSuccess(await _actionLogsForDay(day));
    } catch (e) {
      return AppFailure('Failed to load action logs for day: $e');
    }
  }

  @override
  Future<AppResult<List<ActionLog>>> actionLogsForRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      return AppSuccess(await _actionLogsForRange(start, end));
    } catch (e) {
      return AppFailure('Failed to load action logs for range: $e');
    }
  }

  @override
  Future<AppResult<List<ActionLog>>> actionLogsSince(DateTime since) async {
    try {
      return AppSuccess(await _actionLogsSince(since));
    } catch (e) {
      return AppFailure('Failed to load action logs since: $e');
    }
  }

  @override
  Future<AppResult<List<ActionLog>>> allActionLogs() async {
    try {
      return AppSuccess(await _allActionLogs());
    } catch (e) {
      return AppFailure('Failed to load all action logs: $e');
    }
  }

  @override
  Future<AppResult<void>> addActionLog({
    required ActionType actionType,
    required String? activityId,
    required String? entryId,
    required DateTime occurredAt,
    required String message,
  }) async {
    try {
      await _addActionLog(
        actionType: actionType,
        activityId: activityId,
        entryId: entryId,
        occurredAt: occurredAt,
        message: message,
      );
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to add action log: $e');
    }
  }

  @override
  Future<AppResult<void>> replaceActionLogIfRemoteNewer(
    ActionLog remote,
  ) async {
    try {
      await _replaceActionLogIfRemoteNewer(remote);
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to replace action log: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Internal implementations (raw return types)
  // -------------------------------------------------------------------------

  Future<List<ActionLog>> _actionLogsForDay(DateTime day) async {
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

  Future<List<ActionLog>> _actionLogsForRange(
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

  Future<List<ActionLog>> _actionLogsSince(DateTime since) async {
    final db = await _database.db;
    final rows = await db.query(
      'action_logs',
      where: 'updated_at >= ?',
      whereArgs: [since.toUtc().toIso8601String()],
      orderBy: 'updated_at asc',
    );
    return rows.map(ActionLog.fromMap).toList();
  }

  Future<List<ActionLog>> _allActionLogs() async {
    final db = await _database.db;
    final rows = await db.query(
      'action_logs',
      orderBy: 'updated_at asc',
    );
    return rows.map(ActionLog.fromMap).toList();
  }

  Future<void> _addActionLog({
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

  Future<void> _replaceActionLogIfRemoteNewer(ActionLog remote) async {
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

  // -------------------------------------------------------------------------
  // Public helpers (not in interface) — used by TimeRepository
  // -------------------------------------------------------------------------

  Future<ActionLog?> actionLogById(
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

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

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
