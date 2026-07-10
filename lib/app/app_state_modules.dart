part of 'app_state.dart';

class AppStateModules {
  AppStateModules(AppStateModuleInputs inputs)
      : repository = inputs.repository {
    final repository = inputs.repository;
    final activityCatalog = inputs.activityCatalog;
    final activityCommands = inputs.activityCommands;
    final entryQueries = inputs.entryQueries;
    final entryCommands = inputs.entryCommands;
    final syncService = inputs.syncService;
    final lanSyncServer = inputs.lanSyncServer;
    final lanSyncClient = inputs.lanSyncClient;
    final fileInteropService = inputs.fileInteropService;
    final onFullRefresh = inputs.onFullRefresh;
    final onDailyRefresh = inputs.onDailyRefresh;
    final selectedDay = inputs.selectedDay;
    final now = inputs.now;
    final activities = inputs.activities;
    final categories = inputs.categories;
    final categoryLinks = inputs.categoryLinks;
    final unassignedActivity = inputs.unassignedActivity;
    final dayEntries = inputs.dayEntries;
    final runningEntry = inputs.runningEntry;
    final entryIsUnassigned = inputs.entryIsUnassigned;
    final shouldStartLanServer = inputs.shouldStartLanServer;
    final startLanServer = inputs.startLanServer;
    final startStartupUpdateCheck = inputs.startStartupUpdateCheck;
    final setLoading = inputs.setLoading;
    final setErrorMessage = inputs.setErrorMessage;
    final setInteropMessage = inputs.setInteropMessage;
    final notifyListeners = inputs.notifyListeners;
    final refresh = inputs.refresh;
    final sync = inputs.sync;
    final updateService = inputs.updateService;
    final appVersionLoader = inputs.appVersionLoader;
    final targetPlatformLoader = inputs.targetPlatformLoader;
    final syncStatusStore = inputs.syncStatusStore;

    runtimeState = AppRuntimeState();
    lanState = LanState(server: lanSyncServer, client: lanSyncClient);
    categoryState = CategoryState(repository: repository);
    settingsState = SettingsState(repository: repository);
    interopState = InteropState(fileInteropService: fileInteropService);
    updateState = UpdateState(
      updateService: updateService,
      appVersionLoader: appVersionLoader,
      targetPlatformLoader: targetPlatformLoader,
    );
    syncState = SyncState(
      syncService: syncService,
      statusStore: syncStatusStore ?? SyncStatusStore.memory(),
    );
    activityState = ActivityState(
      activityCatalog: activityCatalog,
      activityCommands: activityCommands,
      entryQueries: entryQueries,
      entryCommands: entryCommands,
      onFullRefresh: onFullRefresh,
      onEntryRefresh: onDailyRefresh,
    );
    entryState = EntryState(
      entryQueries: entryQueries,
      entryCommands: entryCommands,
      now: now,
      onFullRefresh: onDailyRefresh,
    );
    refreshState = AppRefreshState(
      repository: repository,
      activityState: activityState,
      categoryState: categoryState,
      settingsState: settingsState,
      lanState: lanState,
      syncState: syncState,
      entryState: entryState,
      notifyListeners: notifyListeners,
    );
    lifecycleState = AppLifecycleState(
      ensureSeedData: repository.ensureSeedData,
      refresh: refresh,
      shouldStartLanServer: shouldStartLanServer,
      startLanServer: startLanServer,
      startStartupUpdateCheck: startStartupUpdateCheck,
      tickClock: refreshState.tick,
      setLoading: setLoading,
      setErrorMessage: setErrorMessage,
      notifyListeners: notifyListeners,
    );
    settingsCoordinatorState = SettingsCoordinatorState(
      settingsState: settingsState,
      notifyListeners: notifyListeners,
      sync: sync,
    );
    authState = AuthState(
      syncService: syncService,
      refresh: refresh,
      sync: sync,
    );
    lanCoordinatorState = LanCoordinatorState(
      lanState: lanState,
      setInteropMessage: setInteropMessage,
      notifyListeners: notifyListeners,
      sync: sync,
    );
    interopCoordinatorState = InteropCoordinatorState(
      interopState: interopState,
      setInteropMessage: setInteropMessage,
      notifyListeners: notifyListeners,
      refresh: refresh,
    );
    statsState = StatsState(
      selectedDay: selectedDay,
      now: now,
      activities: activities,
      categories: categories,
      categoryLinks: categoryLinks,
      unassignedActivity: unassignedActivity,
      dayEntries: dayEntries,
      entriesForRange: entryState.entriesForRange,
      actionLogsForRange: ({
        required DateTime start,
        required DateTime end,
      }) {
        return repository.actionLogsForRange(start, end);
      },
      allEntries: repository.allEntries,
    );
    syncCoordinatorState = SyncCoordinatorState(
      syncService: syncService,
      lanState: lanState,
      syncState: syncState,
      setErrorMessage: setErrorMessage,
      notifyListeners: notifyListeners,
      refresh: refresh,
    );
    undoCoordinatorState = UndoCoordinatorState(
      repository: repository,
      selectedDay: selectedDay,
      now: now,
      systemNow: DateTime.now,
      operationNow: DateTime.now,
      dayEntries: dayEntries,
      runningEntry: runningEntry,
      refresh: refresh,
      sync: sync,
      setErrorMessage: setErrorMessage,
      notifyListeners: notifyListeners,
    );
    entryMutationState = EntryMutationState(
      entryState: entryState,
      now: now,
      runningEntry: runningEntry,
      recordUndoable: undoCoordinatorState.record,
      entryUndoScope: undoCoordinatorState.entryScope,
      entryIdUndoScope: undoCoordinatorState.entryIdScope,
      entryIntervalUndoScope: undoCoordinatorState.entryIntervalScope,
    );
    categoryMutationState = CategoryMutationState(
      categoryState: categoryState,
      recordUndoable: undoCoordinatorState.record,
      notifyListeners: notifyListeners,
      sync: sync,
    );
    reminderCoordinatorState = ReminderCoordinatorState(
      reminderState: ReminderState(),
      now: now,
      actionNow: DateTime.now,
      settings: () => settingsState.settings,
      runningEntry: runningEntry,
      entryIsUnassigned: entryIsUnassigned,
      notifyListeners: notifyListeners,
    );
    activityMutationState = ActivityMutationState(
      activityState: activityState,
      recordUndoable: undoCoordinatorState.record,
      activeEntryUndoScope: undoCoordinatorState.activeEntryScope,
      setActivityCategories: categoryMutationState.setActivityCategoriesRaw,
    );
  }

  final TimeRepository repository;
  late final ActivityState activityState;
  late final ActivityMutationState activityMutationState;
  late final AuthState authState;
  late final CategoryState categoryState;
  late final CategoryMutationState categoryMutationState;
  late final EntryState entryState;
  late final EntryMutationState entryMutationState;
  late final AppLifecycleState lifecycleState;
  late final AppRefreshState refreshState;
  late final AppRuntimeState runtimeState;
  late final InteropState interopState;
  late final InteropCoordinatorState interopCoordinatorState;
  late final LanState lanState;
  late final LanCoordinatorState lanCoordinatorState;
  late final ReminderCoordinatorState reminderCoordinatorState;
  late final SettingsState settingsState;
  late final SettingsCoordinatorState settingsCoordinatorState;
  late final SyncState syncState;
  late final SyncCoordinatorState syncCoordinatorState;
  late final StatsState statsState;
  late final UndoCoordinatorState undoCoordinatorState;
  late final UpdateState updateState;
}
