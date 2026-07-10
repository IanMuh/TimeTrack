import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/app_update_service.dart';
import '../data/file_interop_service.dart';
import '../data/lan_sync.dart';
import '../data/repository_interfaces.dart';
import '../data/repository_undo.dart';
import '../data/sync_peer_store.dart';
import '../data/sync_service.dart';
import '../data/sync_status_store.dart';
import '../data/time_repository.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/activity_category.dart';
import '../domain/profile_settings.dart';
import '../domain/stats_period.dart';
import '../domain/time_entry.dart';
import 'activity_mutation_state.dart';
import 'activity_state.dart';
import 'app_lifecycle_state.dart';
import 'app_refresh_state.dart';
import 'app_runtime_state.dart';
import 'auth_state.dart';
import 'category_mutation_state.dart';
import 'category_state.dart';
import 'entry_mutation_state.dart';
import 'entry_state.dart';
import 'interop_coordinator_state.dart';
import 'interop_state.dart';
import 'lan_coordinator_state.dart';
import 'lan_state.dart';
import 'reminder_coordinator_state.dart';
import 'reminder_state.dart';
import 'settings_coordinator_state.dart';
import 'settings_state.dart';
import 'stats_state.dart';
import 'sync_coordinator_state.dart';
import 'sync_state.dart';
import 'time_stats.dart';
import 'undo_coordinator_state.dart';
import 'update_state.dart';

export 'time_stats.dart'
    show
        ActivityStatsSnapshot,
        StatsDimension,
        StatsEntrySlice,
        StatsGroupRow,
        TimeRangeStats;
export 'update_state.dart' show AppVersionLoader, TargetPlatformLoader;

part 'app_state_activity_facade.dart';
part 'app_state_activity_mutation_facade.dart';
part 'app_state_auth_facade.dart';
part 'app_state_category_facade.dart';
part 'app_state_core_facade.dart';
part 'app_state_entry_facade.dart';
part 'app_state_entry_mutation_facade.dart';
part 'app_state_interop_facade.dart';
part 'app_state_lan_facade.dart';
part 'app_state_module_inputs.dart';
part 'app_state_module_factory.dart';
part 'app_state_module_accessors.dart';
part 'app_state_modules.dart';
part 'app_state_reminder_facade.dart';
part 'app_state_runtime_facade.dart';
part 'app_state_settings_facade.dart';
part 'app_state_stats_facade.dart';
part 'app_state_sync_facade.dart';
part 'app_state_undo_facade.dart';
part 'app_state_update_facade.dart';

class AppState extends ChangeNotifier
    with
        AppStateModuleAccessors,
        AppStateCoreFacade,
        AppStateActivityFacade,
        AppStateActivityMutationFacade,
        AppStateAuthFacade,
        AppStateCategoryFacade,
        AppStateEntryFacade,
        AppStateEntryMutationFacade,
        AppStateInteropFacade,
        AppStateLanFacade,
        AppStateUpdateFacade,
        AppStateReminderFacade,
        AppStateSettingsFacade,
        AppStateStatsFacade,
        AppStateSyncFacade,
        AppStateUndoFacade,
        AppStateRuntimeFacade {
  AppState({
    required TimeRepository repository,
    required IActivityCatalogRepository activityCatalog,
    required IActivityCommandRepository activityCommands,
    required ITimeEntryQueryRepository entryQueries,
    required ITimeEntryCommandRepository entryCommands,
    required SyncService syncService,
    required LanSyncServer lanSyncServer,
    required LanSyncClient lanSyncClient,
    required FileInteropService fileInteropService,
    AppUpdateService? updateService,
    AppVersionLoader? appVersionLoader,
    TargetPlatformLoader? targetPlatformLoader,
    SyncStatusStore? syncStatusStore,
  }) {
    _modules = buildAppStateModules(
      appState: this,
      repository: repository,
      activityCatalog: activityCatalog,
      activityCommands: activityCommands,
      entryQueries: entryQueries,
      entryCommands: entryCommands,
      syncService: syncService,
      lanSyncServer: lanSyncServer,
      lanSyncClient: lanSyncClient,
      fileInteropService: fileInteropService,
      updateService: updateService,
      appVersionLoader: appVersionLoader,
      targetPlatformLoader: targetPlatformLoader,
      syncStatusStore: syncStatusStore,
    );
    _bindSubStateListeners();
  }

  @override
  late final AppStateModules _modules;
}
