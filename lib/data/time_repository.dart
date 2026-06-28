import 'package:sqflite/sqflite.dart';

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
import 'repository_interfaces.dart';
import 'repository_undo.dart';
import 'settings_repository.dart';
import 'sync_bundle.dart';
import 'time_entry_repository.dart';

// Re-export types that were previously defined here
export 'repository_interfaces.dart'
    show EntryMergeDirection, EntryMergeCandidate;
export 'time_entry_repository.dart' show TimeEntryRepository;
export 'action_log_repository.dart' show ActionLogRepository;

class TimeRepository {
  TimeRepository({
    required LocalDatabase database,
    required ActivityRepository activityRepository,
    required SettingsRepository settingsRepository,
    required DeviceIdStore deviceIdStore,
    required TimeEntryRepository timeEntryRepository,
    required ActionLogRepository actionLogRepository,
    ActivityCategoryRepository? activityCategoryRepository,
  })  : _database = database,
        _activityRepo = activityRepository,
        _settingsRepo = settingsRepository,
        _deviceIdStore = deviceIdStore,
        _entryRepo = timeEntryRepository,
        _logRepo = actionLogRepository,
        _categoryRepo = activityCategoryRepository ??
            ActivityCategoryRepository(database: database);

  final LocalDatabase _database;
  final ActivityRepository _activityRepo;
  final SettingsRepository _settingsRepo;
  final DeviceIdStore _deviceIdStore;
  final TimeEntryRepository _entryRepo;
  final ActionLogRepository _logRepo;
  final ActivityCategoryRepository _categoryRepo;

  // -------------------------------------------------------------------------
  // Seed & bundle orchestration
  // -------------------------------------------------------------------------

  Future<void> ensureSeedData() async {
    final db = await _database.db;
    final unassigned = await _activityRepo.ensureUnassignedActivity();
    await _entryRepo.mergeAdjacentUnassignedEntries(unassigned.id);
    await _entryRepo.normalizeStoredCrossDayEntries();
    await _entryRepo.rolloverRunningEntriesIfNeeded();
    await _entryRepo.backfillMissingEntrySnapshots();

    final seeded = Sqflite.firstIntValue(
      await db.rawQuery(
        "select count(*) from app_metadata where key = 'seeded' and value = '1'",
      ),
    );
    if (seeded == 1) return;

    await _activityRepo.seedActivities();

    final settingsCount = Sqflite.firstIntValue(
      await db.rawQuery('select count(*) from profile_settings'),
    );
    if (settingsCount == 0) {
      await _settingsRepo.saveSettingsRaw(ProfileSettings.defaults());
    }

    await db.insert(
      'app_metadata',
      {'key': 'seeded', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SyncBundle> exportBundle() async {
    final deviceId = await currentDeviceId();
    return SyncBundle(
      schemaVersion: SyncBundle.currentSchemaVersion,
      exportedAt: DateTime.now(),
      sourceDeviceId: deviceId,
      activities: await activities(includeDeleted: true),
      categories: await categories(includeDeleted: true),
      categoryLinks: await activityCategoryLinks(includeDeleted: true),
      timeEntries: await allEntries(),
      actionLogs: await allActionLogs(),
      profileSettings: await settings(),
    );
  }

  Future<void> mergeBundle(SyncBundle bundle) async {
    if (bundle.schemaVersion < 1 ||
        bundle.schemaVersion > SyncBundle.currentSchemaVersion) {
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

      for (final category in bundle.categories) {
        final localRows = await txn.query(
          'activity_categories',
          where: 'id = ?',
          whereArgs: [category.id],
          limit: 1,
        );
        if (_shouldReplace(
          localRows,
          ActivityCategory.fromMap,
          category.updatedAt,
        )) {
          await txn.insert(
            'activity_categories',
            category.toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      for (final link in bundle.categoryLinks) {
        final localRows = await txn.query(
          'activity_category_links',
          where: 'id = ?',
          whereArgs: [link.id],
          limit: 1,
        );
        if (_shouldReplace(
          localRows,
          ActivityCategoryLink.fromMap,
          link.updatedAt,
        )) {
          await txn.insert(
            'activity_category_links',
            link.toLocalMap(),
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

    await _entryRepo.normalizeRunningEntriesAfterMerge();
    await _entryRepo.normalizeStoredCrossDayEntries();
    await _entryRepo.backfillMissingEntrySnapshots();
    final unassigned = await _activityRepo.ensureUnassignedActivity();
    await _entryRepo.mergeAdjacentUnassignedEntries(unassigned.id);
  }

  // -------------------------------------------------------------------------
  // Activity delegation (unwrap AppResult)
  // -------------------------------------------------------------------------

  Future<List<Activity>> activities({bool includeDeleted = false}) async {
    final result =
        await _activityRepo.activities(includeDeleted: includeDeleted);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<Activity>> oneOffActivities({
    bool includeDeleted = true,
  }) async {
    final result =
        await _activityRepo.oneOffActivities(includeDeleted: includeDeleted);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<Activity> unassignedActivity() async {
    final result = await _activityRepo.unassignedActivity();
    return result.fold(
      onSuccess: (activity) => activity,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> upsertActivity(Activity activity) async {
    final result = await _activityRepo.upsertActivity(activity);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<Activity> createActivity({
    required String name,
    required int color,
    String? userId,
    bool isOneOff = false,
  }) async {
    final result = await _activityRepo.createActivity(
      name: name,
      color: color,
      userId: userId,
      isOneOff: isOneOff,
    );
    return result.fold(
      onSuccess: (activity) => activity,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<Activity> updateActivity({
    required Activity activity,
    required String name,
    required int color,
  }) async {
    final result = await _activityRepo.updateActivity(
      activity: activity,
      name: name,
      color: color,
    );
    return result.fold(
      onSuccess: (updated) => updated,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<Activity> restoreOneOffActivity(Activity activity) async {
    final result = await _activityRepo.restoreOneOffActivity(activity);
    return result.fold(
      onSuccess: (restored) => restored,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> deleteActivity(Activity activity) async {
    if (activity.isUnassigned) {
      return;
    }
    final now = DateTime.now();
    final runningResult = await _entryRepo.runningEntry();
    final running = runningResult.fold(
      onSuccess: (r) => r,
      onFailure: (_) => null,
    );
    if (running?.activityId == activity.id) {
      final stopResult = await _entryRepo.stopRunning(at: now);
      stopResult.fold(
        onSuccess: (_) {},
        onFailure: (msg) => throw StateError(msg),
      );
    }
    final result = await _activityRepo.deleteActivity(activity);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
    final logResult = await _logRepo.addActionLog(
      actionType: ActionType.activityDelete,
      activityId: activity.id,
      entryId: null,
      occurredAt: now,
      message: '删除事项',
    );
    logResult.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<Activity>> activitiesSince(DateTime since) async {
    final result = await _activityRepo.activitiesSince(since);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> replaceActivityIfRemoteNewer(Activity remote) async {
    final result = await _activityRepo.replaceActivityIfRemoteNewer(remote);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
  }

  // -------------------------------------------------------------------------
  // Activity category delegation (unwrap AppResult)
  // -------------------------------------------------------------------------

  Future<List<ActivityCategory>> categories({
    bool includeDeleted = false,
  }) async {
    final result =
        await _categoryRepo.categories(includeDeleted: includeDeleted);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<ActivityCategory> createCategory({
    required String name,
    required int color,
    String? userId,
  }) async {
    final result = await _categoryRepo.createCategory(
      name: name,
      color: color,
      userId: userId,
    );
    return result.fold(
      onSuccess: (category) => category,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<ActivityCategory> updateCategory({
    required ActivityCategory category,
    required String name,
    required int color,
  }) async {
    final result = await _categoryRepo.updateCategory(
      category: category,
      name: name,
      color: color,
    );
    return result.fold(
      onSuccess: (updated) => updated,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> deleteCategory(ActivityCategory category) async {
    final result = await _categoryRepo.deleteCategory(category);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<ActivityCategoryLink>> activityCategoryLinks({
    bool includeDeleted = false,
  }) async {
    final result = await _categoryRepo.activityCategoryLinks(
      includeDeleted: includeDeleted,
    );
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<ActivityCategoryLink>> linksForActivity(
    String activityId, {
    bool includeDeleted = false,
  }) async {
    final result = await _categoryRepo.linksForActivity(
      activityId,
      includeDeleted: includeDeleted,
    );
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<ActivityCategoryLink>> setActivityCategories({
    required String activityId,
    required String? primaryCategoryId,
    required List<String> secondaryCategoryIds,
    String? userId,
  }) async {
    final result = await _categoryRepo.setActivityCategories(
      activityId: activityId,
      primaryCategoryId: primaryCategoryId,
      secondaryCategoryIds: secondaryCategoryIds,
      userId: userId,
    );
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<ActivityCategory>> categoriesSince(DateTime since) async {
    final result = await _categoryRepo.categoriesSince(since);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<ActivityCategoryLink>> categoryLinksSince(DateTime since) async {
    final result = await _categoryRepo.categoryLinksSince(since);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> replaceCategoryIfRemoteNewer(ActivityCategory remote) async {
    final result = await _categoryRepo.replaceCategoryIfRemoteNewer(remote);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> replaceCategoryLinkIfRemoteNewer(
    ActivityCategoryLink remote,
  ) async {
    final result = await _categoryRepo.replaceCategoryLinkIfRemoteNewer(remote);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
  }

  // -------------------------------------------------------------------------
  // Entry delegation (unwrap AppResult)
  // -------------------------------------------------------------------------

  Future<TimeEntry?> runningEntry() async {
    final result = await _entryRepo.runningEntry();
    return result.fold(
      onSuccess: (entry) => entry,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<TimeEntry> switchToActivity(String activityId, {DateTime? at}) async {
    final result = await _entryRepo.switchToActivity(activityId, at: at);
    return result.fold(
      onSuccess: (entry) => entry,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> stopRunning({DateTime? at}) async {
    final result = await _entryRepo.stopRunning(at: at);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<TimeEntry>> saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  }) async {
    final result = await _entryRepo.saveEntry(
      entry,
      logEdit: logEdit,
      cutOverlaps: cutOverlaps,
    );
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<TimeEntry>> splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) async {
    final result = await _entryRepo.splitEntry(
      entryId: entryId,
      splitAt: splitAt,
    );
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<TimeEntry> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
    String? userId,
  }) async {
    final result = await _entryRepo.createManualEntry(
      activityId: activityId,
      startAt: startAt,
      endAt: endAt,
      note: note,
      userId: userId,
    );
    return result.fold(
      onSuccess: (entry) => entry,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> deleteEntry(TimeEntry entry) async {
    final result = await _entryRepo.deleteEntry(entry);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<TimeEntry>> entriesForDay(DateTime day) async {
    final result = await _entryRepo.entriesForDay(day);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<TimeEntry>> entriesForRange(
    DateTime start,
    DateTime end,
  ) async {
    final result = await _entryRepo.entriesForRange(start, end);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<TimeEntry>> entriesSince(DateTime since) async {
    final result = await _entryRepo.entriesSince(since);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<TimeEntry>> allEntries() async {
    final result = await _entryRepo.allEntries();
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<EntryMergeCandidate?> mergeCandidateForEntry(
    String entryId,
    EntryMergeDirection direction,
  ) async {
    final result = await _entryRepo.mergeCandidateForEntry(entryId, direction);
    return result.fold(
      onSuccess: (candidate) => candidate,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<TimeEntry?> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) async {
    final result = await _entryRepo.mergeEntryWithNeighbor(
      entryId: entryId,
      direction: direction,
      confirmed: confirmed,
    );
    return result.fold(
      onSuccess: (entry) => entry,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<TimeEntry>> overlappingEntries(TimeEntry entry) async {
    final result = await _entryRepo.overlappingEntries(entry);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> replaceEntryIfRemoteNewer(TimeEntry remote) async {
    final result = await _entryRepo.replaceEntryIfRemoteNewer(remote);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> rolloverRunningEntriesIfNeeded({DateTime? at}) async {
    await _entryRepo.rolloverRunningEntriesIfNeeded(at: at);
  }

  Future<void> normalizeRunningEntriesAfterMerge() async {
    await _entryRepo.normalizeRunningEntriesAfterMerge();
  }

  Future<void> normalizeStoredCrossDayEntries() async {
    await _entryRepo.normalizeStoredCrossDayEntries();
  }

  Future<void> backfillMissingEntrySnapshots() async {
    await _entryRepo.backfillMissingEntrySnapshots();
  }

  // -------------------------------------------------------------------------
  // Action log delegation (unwrap AppResult)
  // -------------------------------------------------------------------------

  Future<List<ActionLog>> actionLogsForDay(DateTime day) async {
    final result = await _logRepo.actionLogsForDay(day);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<ActionLog>> actionLogsForRange(
    DateTime start,
    DateTime end,
  ) async {
    final result = await _logRepo.actionLogsForRange(start, end);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<ActionLog>> actionLogsSince(DateTime since) async {
    final result = await _logRepo.actionLogsSince(since);
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<List<ActionLog>> allActionLogs() async {
    final result = await _logRepo.allActionLogs();
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> addActionLog({
    required ActionType actionType,
    required String? activityId,
    required String? entryId,
    required DateTime occurredAt,
    required String message,
  }) async {
    final result = await _logRepo.addActionLog(
      actionType: actionType,
      activityId: activityId,
      entryId: entryId,
      occurredAt: occurredAt,
      message: message,
    );
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> replaceActionLogIfRemoteNewer(ActionLog remote) async {
    final result = await _logRepo.replaceActionLogIfRemoteNewer(remote);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
  }

  // -------------------------------------------------------------------------
  // Undo / redo
  // -------------------------------------------------------------------------

  Future<RepositoryUndoSnapshot> undoSnapshot() async {
    final activityRows = await activities(includeDeleted: true);
    final categoryRows = await categories(includeDeleted: true);
    final categoryLinkRows = await activityCategoryLinks(includeDeleted: true);
    final entryRows = await allEntries();
    final logRows = await allActionLogs();
    return RepositoryUndoSnapshot(
      activities: {
        for (final activity in activityRows) activity.id: activity,
      },
      categories: {
        for (final category in categoryRows) category.id: category,
      },
      categoryLinks: {
        for (final link in categoryLinkRows) link.id: link,
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
      for (final change in changeSet.categories) {
        await _applyCategoryUndoChange(txn, change, direction, updatedAt);
      }
      for (final change in changeSet.categoryLinks) {
        await _applyCategoryLinkUndoChange(txn, change, direction, updatedAt);
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
      actionType: direction == RepositoryUndoDirection.undo
          ? ActionType.undo
          : ActionType.redo,
      activityId: null,
      entryId: null,
      occurredAt: updatedAt,
      message: '$actionLabel：${changeSet.label}',
    );
  }

  // -------------------------------------------------------------------------
  // Settings delegation
  // -------------------------------------------------------------------------

  Future<ProfileSettings> settings() async {
    final result = await _settingsRepo.settings();
    return result.fold(
      onSuccess: (settings) => settings,
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> saveSettings(ProfileSettings settings) async {
    final result = await _settingsRepo.saveSettings(settings);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
  }

  Future<void> replaceSettingsIfRemoteNewer(ProfileSettings remote) async {
    final result = await _settingsRepo.replaceSettingsIfRemoteNewer(remote);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
  }

  // -------------------------------------------------------------------------
  // Device ID
  // -------------------------------------------------------------------------

  Future<String> currentDeviceId() async {
    return _deviceIdStore.currentDeviceId();
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  Future<void> _validateUndoChangeSet(
    DatabaseExecutor executor,
    RepositoryUndoChangeSet changeSet,
    RepositoryUndoDirection direction,
  ) async {
    for (final change in changeSet.activities) {
      final current = await _activityRepo.activityById(change.id, executor);
      if (!_rowMatchesExpected<Activity>(
        current: current,
        expected: change.expectedFor(direction),
        toMap: (value) => value.toLocalMap(),
        isDeleted: (value) => value.isDeleted,
      )) {
        throw _undoConflict(direction);
      }
    }
    for (final change in changeSet.categories) {
      final current = await _categoryRepo.categoryById(change.id, executor);
      if (!_rowMatchesExpected<ActivityCategory>(
        current: current,
        expected: change.expectedFor(direction),
        toMap: (value) => value.toLocalMap(),
        isDeleted: (value) => value.isDeleted,
      )) {
        throw _undoConflict(direction);
      }
    }
    for (final change in changeSet.categoryLinks) {
      final current = await _categoryRepo.categoryLinkById(change.id, executor);
      if (!_rowMatchesExpected<ActivityCategoryLink>(
        current: current,
        expected: change.expectedFor(direction),
        toMap: (value) => value.toLocalMap(),
        isDeleted: (value) => value.isDeleted,
      )) {
        throw _undoConflict(direction);
      }
    }
    for (final change in changeSet.timeEntries) {
      final current = await _entryRepo.entryByIdWithExecutor(
        change.id,
        executor,
      );
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
      final current = await _logRepo.actionLogById(change.id, executor);
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

  Future<void> _applyCategoryUndoChange(
    DatabaseExecutor executor,
    RepositoryUndoRowChange<ActivityCategory> change,
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
      'activity_categories',
      value.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _applyCategoryLinkUndoChange(
    DatabaseExecutor executor,
    RepositoryUndoRowChange<ActivityCategoryLink> change,
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
      'activity_category_links',
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
}
