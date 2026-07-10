import 'package:sqflite/sqflite.dart';

import '../core/result.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/activity_category.dart';
import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';
import 'action_log_repository.dart';
import 'activity_category_repository.dart';
import 'activity_repository.dart';
import 'device_id_store.dart';
import 'local_database.dart';
import 'repository_result.dart';
import 'settings_repository.dart';
import 'sync_bundle.dart';
import 'sync_bundle_store.dart';
import 'time_entry_repository.dart';

class SyncBundleRepository implements SyncBundleStore {
  const SyncBundleRepository({
    required LocalDatabase database,
    required ActivityRepository activityRepository,
    required SettingsRepository settingsRepository,
    required DeviceIdStore deviceIdStore,
    required TimeEntryRepository timeEntryRepository,
    required ActionLogRepository actionLogRepository,
    required ActivityCategoryRepository activityCategoryRepository,
  })  : _database = database,
        _activityRepo = activityRepository,
        _settingsRepo = settingsRepository,
        _deviceIdStore = deviceIdStore,
        _entryRepo = timeEntryRepository,
        _logRepo = actionLogRepository,
        _categoryRepo = activityCategoryRepository;

  final LocalDatabase _database;
  final ActivityRepository _activityRepo;
  final SettingsRepository _settingsRepo;
  final DeviceIdStore _deviceIdStore;
  final TimeEntryRepository _entryRepo;
  final ActionLogRepository _logRepo;
  final ActivityCategoryRepository _categoryRepo;

  @override
  Future<SyncBundle> exportBundle() async {
    final deviceId = await _deviceIdStore.currentDeviceId();
    return SyncBundle(
      schemaVersion: SyncBundle.currentSchemaVersion,
      exportedAt: DateTime.now(),
      sourceDeviceId: deviceId,
      activities: _unwrap(
        await _activityRepo.activities(includeDeleted: true),
      ),
      categories: _unwrap(
        await _categoryRepo.categories(includeDeleted: true),
      ),
      categoryLinks: _unwrap(
        await _categoryRepo.activityCategoryLinks(includeDeleted: true),
      ),
      timeEntries: _unwrap(await _entryRepo.allEntries()),
      actionLogs: _unwrap(await _logRepo.allActionLogs()),
      profileSettings: _unwrap(await _settingsRepo.settings()),
    );
  }

  @override
  Future<void> mergeBundle(SyncBundle bundle) async {
    if (bundle.schemaVersion < 1 ||
        bundle.schemaVersion > SyncBundle.currentSchemaVersion) {
      throw FormatException(
        'Unsupported TimeTrack sync schema version: ${bundle.schemaVersion}.',
      );
    }

    final db = await _database.db;
    await db.transaction((txn) async {
      await _mergeRows<Activity>(
        executor: txn,
        table: 'activities',
        remoteRows: bundle.activities,
        idOf: (activity) => activity.id,
        fromMap: Activity.fromMap,
        toMap: (activity) => activity.toLocalMap(),
        updatedAtOf: (activity) => activity.updatedAt,
      );
      await _mergeRows<ActivityCategory>(
        executor: txn,
        table: 'activity_categories',
        remoteRows: bundle.categories,
        idOf: (category) => category.id,
        fromMap: ActivityCategory.fromMap,
        toMap: (category) => category.toLocalMap(),
        updatedAtOf: (category) => category.updatedAt,
      );
      await _mergeRows<ActivityCategoryLink>(
        executor: txn,
        table: 'activity_category_links',
        remoteRows: bundle.categoryLinks,
        idOf: (link) => link.id,
        fromMap: ActivityCategoryLink.fromMap,
        toMap: (link) => link.toLocalMap(),
        updatedAtOf: (link) => link.updatedAt,
      );
      await _mergeRows<TimeEntry>(
        executor: txn,
        table: 'time_entries',
        remoteRows: bundle.timeEntries,
        idOf: (entry) => entry.id,
        fromMap: TimeEntry.fromMap,
        toMap: (entry) => entry.toLocalMap(),
        updatedAtOf: (entry) => entry.updatedAt,
      );
      await _mergeRows<ActionLog>(
        executor: txn,
        table: 'action_logs',
        remoteRows: bundle.actionLogs,
        idOf: (log) => log.id,
        fromMap: ActionLog.fromMap,
        toMap: (log) => log.toLocalMap(),
        updatedAtOf: (log) => log.updatedAt,
      );
      await _mergeSettings(txn, bundle.profileSettings);
    });

    await _entryRepo.normalizeRunningEntriesAfterMerge();
    await _entryRepo.normalizeStoredCrossDayEntries();
    await _entryRepo.backfillMissingEntrySnapshots();
    final unassigned = await _activityRepo.ensureUnassignedActivity();
    await _entryRepo.mergeAdjacentUnassignedEntries(unassigned.id);
  }

  Future<void> _mergeRows<T>({
    required DatabaseExecutor executor,
    required String table,
    required Iterable<T> remoteRows,
    required String Function(T value) idOf,
    required T Function(Map<String, Object?> map) fromMap,
    required Map<String, Object?> Function(T value) toMap,
    required DateTime Function(T value) updatedAtOf,
  }) async {
    for (final remote in remoteRows) {
      final localRows = await executor.query(
        table,
        where: 'id = ?',
        whereArgs: [idOf(remote)],
        limit: 1,
      );
      if (_shouldReplace(
        localRows: localRows,
        fromMap: fromMap,
        remoteUpdatedAt: updatedAtOf(remote),
        updatedAtOf: updatedAtOf,
      )) {
        await executor.insert(
          table,
          toMap(remote),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  Future<void> _mergeSettings(
    DatabaseExecutor executor,
    ProfileSettings remote,
  ) async {
    final localRows = await executor.query('profile_settings', limit: 1);
    if (!_shouldReplace(
      localRows: localRows,
      fromMap: ProfileSettings.fromMap,
      remoteUpdatedAt: remote.updatedAt,
      updatedAtOf: (settings) => settings.updatedAt,
    )) {
      return;
    }
    await executor.insert(
      'profile_settings',
      remote.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  bool _shouldReplace<T>({
    required List<Map<String, Object?>> localRows,
    required T Function(Map<String, Object?> map) fromMap,
    required DateTime remoteUpdatedAt,
    required DateTime Function(T value) updatedAtOf,
  }) {
    if (localRows.isEmpty) {
      return true;
    }
    final local = fromMap(localRows.first);
    return updatedAtOf(local).isBefore(remoteUpdatedAt);
  }

  T _unwrap<T>(AppResult<T> result) {
    return unwrapRepositoryResult(result);
  }
}
