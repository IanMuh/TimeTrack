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
import 'repository_action_log_repository.dart';
import 'repository_activity_repository.dart';
import 'repository_category_repository.dart';
import 'repository_entry_repository.dart';
import 'repository_interfaces.dart';
import 'repository_seed_repository.dart';
import 'repository_settings_repository.dart';
import 'repository_undo.dart';
import 'repository_undo_repository.dart';
import 'settings_repository.dart';
import 'sync_bundle.dart';
import 'sync_bundle_repository.dart';
import 'sync_bundle_store.dart';
import 'time_entry_repository.dart';

// Re-export types that were previously defined here
export 'repository_interfaces.dart'
    show EntryMergeDirection, EntryMergeCandidate;
export 'time_entry_repository.dart' show TimeEntryRepository;
export 'action_log_repository.dart' show ActionLogRepository;

part 'time_repository_activity_facade.dart';
part 'time_repository_category_facade.dart';
part 'time_repository_entry_facade.dart';
part 'time_repository_action_log_facade.dart';
part 'time_repository_undo_facade.dart';
part 'time_repository_settings_facade.dart';

class TimeRepository
    with
        TimeRepositoryActivityFacade,
        TimeRepositoryCategoryFacade,
        TimeRepositoryEntryFacade,
        TimeRepositoryActionLogFacade,
        TimeRepositoryUndoFacade,
        TimeRepositorySettingsFacade
    implements SyncBundleStore {
  TimeRepository({
    required LocalDatabase database,
    required ActivityRepository activityRepository,
    required SettingsRepository settingsRepository,
    required DeviceIdStore deviceIdStore,
    required TimeEntryRepository timeEntryRepository,
    required ActionLogRepository actionLogRepository,
    ActivityCategoryRepository? activityCategoryRepository,
    RepositoryActionLogRepository? actionLogFacade,
    RepositoryActivityRepository? activityFacade,
    RepositoryCategoryRepository? categoryFacade,
    RepositoryEntryRepository? entryFacade,
    RepositorySeedRepository? seedRepository,
    RepositorySettingsRepository? settingsFacade,
    SyncBundleRepository? syncBundleRepository,
    RepositoryUndoRepository? undoRepository,
  }) : _categoryRepo = activityCategoryRepository ??
            ActivityCategoryRepository(database: database) {
    _actionLogFacade = actionLogFacade ??
        RepositoryActionLogRepository(
          actionLogRepository: actionLogRepository,
        );
    _activityFacade = activityFacade ??
        RepositoryActivityRepository(
          activityRepository: activityRepository,
          timeEntryRepository: timeEntryRepository,
          actionLogRepository: actionLogRepository,
        );
    _categoryFacade = categoryFacade ??
        RepositoryCategoryRepository(categoryRepository: _categoryRepo);
    _entryFacade = entryFacade ??
        RepositoryEntryRepository(entryRepository: timeEntryRepository);
    _settingsFacade = settingsFacade ??
        RepositorySettingsRepository(
          settingsRepository: settingsRepository,
          deviceIdStore: deviceIdStore,
        );
    _seedRepo = seedRepository ??
        RepositorySeedRepository(
          database: database,
          activityRepository: activityRepository,
          settingsRepository: settingsRepository,
          timeEntryRepository: timeEntryRepository,
        );
    _bundleRepo = syncBundleRepository ??
        SyncBundleRepository(
          database: database,
          activityRepository: activityRepository,
          settingsRepository: settingsRepository,
          deviceIdStore: deviceIdStore,
          timeEntryRepository: timeEntryRepository,
          actionLogRepository: actionLogRepository,
          activityCategoryRepository: _categoryRepo,
        );
    _undoRepo = undoRepository ??
        RepositoryUndoRepository(
          database: database,
          activityRepository: activityRepository,
          activityCategoryRepository: _categoryRepo,
          timeEntryRepository: timeEntryRepository,
          actionLogRepository: actionLogRepository,
        );
  }

  final ActivityCategoryRepository _categoryRepo;
  @override
  late final RepositoryActionLogRepository _actionLogFacade;
  @override
  late final RepositoryActivityRepository _activityFacade;
  @override
  late final RepositoryCategoryRepository _categoryFacade;
  @override
  late final RepositoryEntryRepository _entryFacade;
  late final RepositorySeedRepository _seedRepo;
  @override
  late final RepositorySettingsRepository _settingsFacade;
  late final SyncBundleRepository _bundleRepo;
  @override
  late final RepositoryUndoRepository _undoRepo;

  // -------------------------------------------------------------------------
  // Seed & bundle orchestration
  // -------------------------------------------------------------------------

  Future<void> ensureSeedData() async {
    await _seedRepo.ensureSeedData();
  }

  @override
  Future<SyncBundle> exportBundle() async {
    return _bundleRepo.exportBundle();
  }

  @override
  Future<void> mergeBundle(SyncBundle bundle) async {
    await _bundleRepo.mergeBundle(bundle);
  }
}
