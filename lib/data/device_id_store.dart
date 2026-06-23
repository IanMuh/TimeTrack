import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'local_database.dart';
import 'repository_interfaces.dart';

class DeviceIdStore implements IDeviceIdStore {
  DeviceIdStore({
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

  @override
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

  /// Returns cached value if available, without hitting the database.
  /// Falls back to 'local-device' if nothing is cached.
  String get cachedOrFallback => _deviceIdOverride ?? _cachedDeviceId ?? 'local-device';
}
