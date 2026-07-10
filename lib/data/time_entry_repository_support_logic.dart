part of 'time_entry_repository.dart';

mixin TimeEntryRepositorySupportLogic {
  LocalDatabase get _database;
  Uuid get _uuid;
  String? get _deviceIdOverride;
  String? get _cachedDeviceId;
  set _cachedDeviceId(String? value);

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
      updatedAt: occurredAt,
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
