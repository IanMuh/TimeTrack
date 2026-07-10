part of 'app_state.dart';

AppStateModules buildAppStateModules({
  required AppState appState,
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
  final inputs = AppStateModuleInputs(
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
    onFullRefresh: appState.refresh,
    onDailyRefresh: appState._refreshDailyData,
    selectedDay: () => appState.selectedDay,
    now: () => appState.now,
    activities: () => appState.activities,
    categories: () => appState.activityCategories,
    categoryLinks: () => appState.activityCategoryLinks,
    unassignedActivity: () => appState.unassignedActivity,
    dayEntries: () => appState.dayEntries,
    runningEntry: () => appState.runningEntry,
    entryIsUnassigned: appState._entryIsUnassigned,
    shouldStartLanServer: () =>
        Platform.isWindows && !appState.isLanServerRunning,
    startLanServer: appState.startLanServer,
    startStartupUpdateCheck: appState._startStartupUpdateCheck,
    setLoading: (value) {
      appState.isLoading = value;
    },
    setErrorMessage: (message) {
      appState.errorMessage = message;
    },
    setInteropMessage: (message) {
      appState.interopMessage = message;
    },
    notifyListeners: appState._notifyStateListeners,
    refresh: appState.refresh,
    sync: appState.sync,
  );
  return AppStateModules(inputs);
}
