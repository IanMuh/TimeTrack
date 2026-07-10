part of 'app_state.dart';

final class AppStateModuleInputs {
  const AppStateModuleInputs({
    required this.repository,
    required this.activityCatalog,
    required this.activityCommands,
    required this.entryQueries,
    required this.entryCommands,
    required this.syncService,
    required this.lanSyncServer,
    required this.lanSyncClient,
    required this.fileInteropService,
    required this.onFullRefresh,
    required this.onDailyRefresh,
    required this.selectedDay,
    required this.now,
    required this.activities,
    required this.categories,
    required this.categoryLinks,
    required this.unassignedActivity,
    required this.dayEntries,
    required this.runningEntry,
    required this.entryIsUnassigned,
    required this.shouldStartLanServer,
    required this.startLanServer,
    required this.startStartupUpdateCheck,
    required this.setLoading,
    required this.setErrorMessage,
    required this.setInteropMessage,
    required this.notifyListeners,
    required this.refresh,
    required this.sync,
    this.updateService,
    this.appVersionLoader,
    this.targetPlatformLoader,
    this.syncStatusStore,
  });

  final TimeRepository repository;
  final IActivityCatalogRepository activityCatalog;
  final IActivityCommandRepository activityCommands;
  final ITimeEntryQueryRepository entryQueries;
  final ITimeEntryCommandRepository entryCommands;
  final SyncService syncService;
  final LanSyncServer lanSyncServer;
  final LanSyncClient lanSyncClient;
  final FileInteropService fileInteropService;
  final Future<void> Function() onFullRefresh;
  final Future<void> Function() onDailyRefresh;
  final DateTime Function() selectedDay;
  final DateTime Function() now;
  final List<Activity> Function() activities;
  final List<ActivityCategory> Function() categories;
  final List<ActivityCategoryLink> Function() categoryLinks;
  final Activity? Function() unassignedActivity;
  final List<TimeEntry> Function() dayEntries;
  final TimeEntry? Function() runningEntry;
  final bool Function(TimeEntry entry) entryIsUnassigned;
  final bool Function() shouldStartLanServer;
  final Future<void> Function() startLanServer;
  final void Function() startStartupUpdateCheck;
  final void Function(bool value) setLoading;
  final void Function(String? message) setErrorMessage;
  final void Function(String? message) setInteropMessage;
  final void Function() notifyListeners;
  final Future<void> Function() refresh;
  final Future<void> Function() sync;
  final AppUpdateService? updateService;
  final AppVersionLoader? appVersionLoader;
  final TargetPlatformLoader? targetPlatformLoader;
  final SyncStatusStore? syncStatusStore;
}
