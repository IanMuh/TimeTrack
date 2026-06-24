import 'package:sqflite/sqflite.dart';

import 'local_database.dart';

class SyncStatus {
  const SyncStatus({
    this.lastSuccessfulSyncAt,
    this.lastError,
    this.lastTarget,
  });

  final DateTime? lastSuccessfulSyncAt;
  final String? lastError;
  final String? lastTarget;

  bool get hasError => lastError != null && lastError!.isNotEmpty;
}

class SyncStatusStore {
  SyncStatusStore({required LocalDatabase database})
      : _database = database,
        _memoryStatus = null;

  SyncStatusStore.memory()
      : _database = null,
        _memoryStatus = const SyncStatus();

  static const lastSuccessfulSyncAtKey = 'last_successful_sync_at';
  static const lastSyncErrorKey = 'last_sync_error';
  static const lastSyncTargetKey = 'last_sync_target';

  final LocalDatabase? _database;
  SyncStatus? _memoryStatus;

  Future<SyncStatus> load() async {
    final memoryStatus = _memoryStatus;
    if (memoryStatus != null) {
      return memoryStatus;
    }

    final db = await _database!.db;
    final rows = await db.query(
      'app_metadata',
      columns: ['key', 'value'],
      where: 'key in (?, ?, ?)',
      whereArgs: const [
        lastSuccessfulSyncAtKey,
        lastSyncErrorKey,
        lastSyncTargetKey,
      ],
    );
    final values = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    return SyncStatus(
      lastSuccessfulSyncAt: _parseDateTime(values[lastSuccessfulSyncAtKey]),
      lastError: _blankToNull(values[lastSyncErrorKey]),
      lastTarget: _blankToNull(values[lastSyncTargetKey]),
    );
  }

  Future<SyncStatus> markSuccess({
    required DateTime at,
    required String target,
  }) async {
    final status = SyncStatus(
      lastSuccessfulSyncAt: at.toUtc(),
      lastTarget: target,
    );
    final memoryStatus = _memoryStatus;
    if (memoryStatus != null) {
      _memoryStatus = status;
      return status;
    }

    final db = await _database!.db;
    await db.transaction((txn) async {
      await _upsert(txn, lastSuccessfulSyncAtKey, at.toUtc().toIso8601String());
      await _upsert(txn, lastSyncTargetKey, target);
      await txn.delete(
        'app_metadata',
        where: 'key = ?',
        whereArgs: const [lastSyncErrorKey],
      );
    });
    return status;
  }

  Future<SyncStatus> markFailure({
    required String error,
    required String target,
  }) async {
    final previous = await load();
    final status = SyncStatus(
      lastSuccessfulSyncAt: previous.lastSuccessfulSyncAt,
      lastError: error,
      lastTarget: target,
    );
    final memoryStatus = _memoryStatus;
    if (memoryStatus != null) {
      _memoryStatus = status;
      return status;
    }

    final db = await _database!.db;
    await db.transaction((txn) async {
      await _upsert(txn, lastSyncErrorKey, error);
      await _upsert(txn, lastSyncTargetKey, target);
    });
    return status;
  }

  static Future<void> _upsert(
    DatabaseExecutor db,
    String key,
    String value,
  ) {
    return db.insert(
      'app_metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }

  static String? _blankToNull(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }
}
