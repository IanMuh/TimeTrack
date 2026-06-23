import 'package:sqflite/sqflite.dart';

import '../core/result.dart';
import '../domain/profile_settings.dart';
import 'local_database.dart';
import 'repository_interfaces.dart';

class SettingsRepository implements ISettingsRepository {
  SettingsRepository({
    required LocalDatabase database,
  }) : _database = database;

  final LocalDatabase _database;

  @override
  Future<AppResult<ProfileSettings>> settings() async {
    try {
      final db = await _database.db;
      final rows = await db.query('profile_settings', limit: 1);
      if (rows.isEmpty) {
        final defaults = ProfileSettings.defaults();
        await _saveSettingsImpl(db, defaults);
        return AppSuccess(defaults);
      }
      return AppSuccess(ProfileSettings.fromMap(rows.first));
    } catch (e) {
      return AppFailure('Failed to load settings: $e');
    }
  }

  @override
  Future<AppResult<void>> saveSettings(ProfileSettings settings) async {
    try {
      final db = await _database.db;
      await _saveSettingsImpl(db, settings);
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to save settings: $e');
    }
  }

  @override
  Future<AppResult<void>> replaceSettingsIfRemoteNewer(
    ProfileSettings remote,
  ) async {
    try {
      final result = await settings();
      if (result is AppFailure<ProfileSettings>) {
        return AppFailure((result as AppFailure).message);
      }
      final local = (result as AppSuccess<ProfileSettings>).value;
      if (local.updatedAt.isBefore(remote.updatedAt)) {
        return saveSettings(remote);
      }
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to replace settings: $e');
    }
  }

  /// Raw save without AppResult wrapping (used by internal callers and TimeRepository coordination).
  Future<void> saveSettingsRaw(ProfileSettings settings) async {
    final db = await _database.db;
    await _saveSettingsImpl(db, settings);
  }

  Future<void> _saveSettingsImpl(DatabaseExecutor db, ProfileSettings settings) async {
    await db.insert(
      'profile_settings',
      settings.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
