import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../data/activity_category_repository.dart';
import '../data/activity_repository.dart';
import '../data/app_update_service.dart';
import '../data/device_id_store.dart';
import '../data/file_interop_service.dart';
import '../data/lan_sync.dart';
import '../data/local_database.dart';
import '../data/repository_action_log_repository.dart';
import '../data/repository_activity_repository.dart';
import '../data/repository_category_repository.dart';
import '../data/repository_entry_repository.dart';
import '../data/repository_undo_repository.dart';
import '../data/repository_seed_repository.dart';
import '../data/repository_settings_repository.dart';
import '../data/settings_repository.dart';
import '../data/sync_bundle_repository.dart';
import '../data/sync_peer_store.dart';
import '../data/sync_service.dart';
import '../data/sync_status_store.dart';
import '../data/time_repository.dart';
import 'app_state.dart';

class AppDependencies {
  AppDependencies._(this._container);

  final GetIt _container;

  AppState get appState => _container<AppState>();

  LocalDatabase get database => _container<LocalDatabase>();

  TimeRepository get repository => _container<TimeRepository>();

  RepositoryActionLogRepository get actionLogRepository =>
      _container<RepositoryActionLogRepository>();

  RepositoryActivityRepository get activityRepository =>
      _container<RepositoryActivityRepository>();

  RepositoryCategoryRepository get categoryRepository =>
      _container<RepositoryCategoryRepository>();

  RepositoryEntryRepository get entryRepository =>
      _container<RepositoryEntryRepository>();

  SyncBundleRepository get syncBundleRepository =>
      _container<SyncBundleRepository>();

  RepositoryUndoRepository get undoRepository =>
      _container<RepositoryUndoRepository>();

  RepositorySeedRepository get seedRepository =>
      _container<RepositorySeedRepository>();

  RepositorySettingsRepository get settingsRepository =>
      _container<RepositorySettingsRepository>();

  SyncService get syncService => _container<SyncService>();
}

AppDependencies buildAppDependencies({
  required SupabaseClient? supabaseClient,
  String? databasePath,
}) {
  final container = GetIt.asNewInstance();

  container.registerLazySingleton<LocalDatabase>(
    () => LocalDatabase(databasePath: databasePath),
  );
  container.registerLazySingleton<ActivityRepository>(
    () => ActivityRepository(database: container<LocalDatabase>()),
  );
  container.registerLazySingleton<ActivityCategoryRepository>(
    () => ActivityCategoryRepository(database: container<LocalDatabase>()),
  );
  container.registerLazySingleton<SettingsRepository>(
    () => SettingsRepository(database: container<LocalDatabase>()),
  );
  container.registerLazySingleton<DeviceIdStore>(
    () => DeviceIdStore(database: container<LocalDatabase>()),
  );
  container.registerLazySingleton<RepositorySettingsRepository>(
    () => RepositorySettingsRepository(
      settingsRepository: container<SettingsRepository>(),
      deviceIdStore: container<DeviceIdStore>(),
    ),
  );
  container.registerLazySingleton<TimeEntryRepository>(
    () => TimeEntryRepository(
      database: container<LocalDatabase>(),
      activityRepository: container<ActivityRepository>(),
    ),
  );
  container.registerLazySingleton<ActionLogRepository>(
    () => ActionLogRepository(database: container<LocalDatabase>()),
  );
  container.registerLazySingleton<RepositoryActionLogRepository>(
    () => RepositoryActionLogRepository(
      actionLogRepository: container<ActionLogRepository>(),
    ),
  );
  container.registerLazySingleton<RepositoryActivityRepository>(
    () => RepositoryActivityRepository(
      activityRepository: container<ActivityRepository>(),
      timeEntryRepository: container<TimeEntryRepository>(),
      actionLogRepository: container<ActionLogRepository>(),
    ),
  );
  container.registerLazySingleton<RepositoryCategoryRepository>(
    () => RepositoryCategoryRepository(
      categoryRepository: container<ActivityCategoryRepository>(),
    ),
  );
  container.registerLazySingleton<RepositoryEntryRepository>(
    () => RepositoryEntryRepository(
      entryRepository: container<TimeEntryRepository>(),
    ),
  );
  container.registerLazySingleton<SyncBundleRepository>(
    () => SyncBundleRepository(
      database: container<LocalDatabase>(),
      activityRepository: container<ActivityRepository>(),
      settingsRepository: container<SettingsRepository>(),
      deviceIdStore: container<DeviceIdStore>(),
      timeEntryRepository: container<TimeEntryRepository>(),
      actionLogRepository: container<ActionLogRepository>(),
      activityCategoryRepository: container<ActivityCategoryRepository>(),
    ),
  );
  container.registerLazySingleton<RepositoryUndoRepository>(
    () => RepositoryUndoRepository(
      database: container<LocalDatabase>(),
      activityRepository: container<ActivityRepository>(),
      activityCategoryRepository: container<ActivityCategoryRepository>(),
      timeEntryRepository: container<TimeEntryRepository>(),
      actionLogRepository: container<ActionLogRepository>(),
    ),
  );
  container.registerLazySingleton<RepositorySeedRepository>(
    () => RepositorySeedRepository(
      database: container<LocalDatabase>(),
      activityRepository: container<ActivityRepository>(),
      settingsRepository: container<SettingsRepository>(),
      timeEntryRepository: container<TimeEntryRepository>(),
    ),
  );
  container.registerLazySingleton<TimeRepository>(
    () => TimeRepository(
      database: container<LocalDatabase>(),
      activityRepository: container<ActivityRepository>(),
      settingsRepository: container<SettingsRepository>(),
      deviceIdStore: container<DeviceIdStore>(),
      timeEntryRepository: container<TimeEntryRepository>(),
      actionLogRepository: container<ActionLogRepository>(),
      activityCategoryRepository: container<ActivityCategoryRepository>(),
      actionLogFacade: container<RepositoryActionLogRepository>(),
      activityFacade: container<RepositoryActivityRepository>(),
      categoryFacade: container<RepositoryCategoryRepository>(),
      entryFacade: container<RepositoryEntryRepository>(),
      seedRepository: container<RepositorySeedRepository>(),
      settingsFacade: container<RepositorySettingsRepository>(),
      syncBundleRepository: container<SyncBundleRepository>(),
      undoRepository: container<RepositoryUndoRepository>(),
    ),
  );
  container.registerLazySingleton<SyncPeerStore>(
    () => SyncPeerStore(database: container<LocalDatabase>()),
  );
  container.registerLazySingleton<SyncService>(
    () => SyncService(
      activityRepository: container<ActivityRepository>(),
      activityCategoryRepository: container<ActivityCategoryRepository>(),
      settingsRepository: container<SettingsRepository>(),
      timeEntryRepository: container<TimeEntryRepository>(),
      actionLogRepository: container<ActionLogRepository>(),
      client: supabaseClient,
    ),
  );
  container.registerLazySingleton<LanSyncServer>(
    () => LanSyncServer(
      bundleStore: container<SyncBundleRepository>(),
      deviceIdStore: container<DeviceIdStore>(),
      peerStore: container<SyncPeerStore>(),
    ),
  );
  container.registerLazySingleton<LanSyncClient>(
    () => LanSyncClient(
      bundleStore: container<SyncBundleRepository>(),
      deviceIdStore: container<DeviceIdStore>(),
      peerStore: container<SyncPeerStore>(),
    ),
  );
  container.registerLazySingleton<FileInteropService>(
    () => FileInteropService(bundleStore: container<SyncBundleRepository>()),
  );
  container.registerLazySingleton<AppUpdateService>(
    () => AppUpdateService(releasesUri: AppConfig.updateReleasesUri),
  );
  container.registerLazySingleton<SyncStatusStore>(
    () => SyncStatusStore(database: container<LocalDatabase>()),
  );
  container.registerLazySingleton<AppState>(
    () => AppState(
      repository: container<TimeRepository>(),
      activityCatalog: container<ActivityRepository>(),
      activityCommands: container<ActivityRepository>(),
      entryQueries: container<TimeEntryRepository>(),
      entryCommands: container<TimeEntryRepository>(),
      syncService: container<SyncService>(),
      lanSyncServer: container<LanSyncServer>(),
      lanSyncClient: container<LanSyncClient>(),
      fileInteropService: container<FileInteropService>(),
      updateService: container<AppUpdateService>(),
      syncStatusStore: container<SyncStatusStore>(),
    ),
  );

  return AppDependencies._(container);
}
