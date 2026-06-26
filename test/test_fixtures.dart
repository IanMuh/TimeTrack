import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timetrack/app/app_state.dart';
import 'package:timetrack/data/activity_repository.dart';
import 'package:timetrack/data/app_update_service.dart';
import 'package:timetrack/data/device_id_store.dart';
import 'package:timetrack/data/file_interop_service.dart';
import 'package:timetrack/data/lan_sync.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/settings_repository.dart';
import 'package:timetrack/data/sync_peer_store.dart';
import 'package:timetrack/data/sync_service.dart';
import 'package:timetrack/data/sync_status_store.dart';
import 'package:timetrack/data/time_repository.dart';

class TestRepositoryFixture {
  const TestRepositoryFixture({
    required this.database,
    required this.sqliteDatabase,
    required this.activityRepository,
    required this.settingsRepository,
    required this.deviceIdStore,
    required this.timeEntryRepository,
    required this.actionLogRepository,
    required this.repository,
    required this.peerStore,
    required this.syncStatusStore,
  });

  final LocalDatabase database;
  final Database sqliteDatabase;
  final ActivityRepository activityRepository;
  final SettingsRepository settingsRepository;
  final DeviceIdStore deviceIdStore;
  final TimeEntryRepository timeEntryRepository;
  final ActionLogRepository actionLogRepository;
  final TimeRepository repository;
  final SyncPeerStore peerStore;
  final SyncStatusStore syncStatusStore;

  SyncService createSyncService() {
    return SyncService(
      activityRepository: activityRepository,
      settingsRepository: settingsRepository,
      timeEntryRepository: timeEntryRepository,
      actionLogRepository: actionLogRepository,
      client: null,
    );
  }

  LanSyncServer createLanSyncServer({
    List<int> portCandidates = const [0],
    InternetAddress? bindAddress,
  }) {
    return LanSyncServer(
      repository: repository,
      deviceIdStore: deviceIdStore,
      peerStore: peerStore,
      portCandidates: portCandidates,
      bindAddress: bindAddress,
    );
  }

  LanSyncClient createLanSyncClient({
    Duration timeout = const Duration(seconds: 8),
  }) {
    return LanSyncClient(
      repository: repository,
      deviceIdStore: deviceIdStore,
      peerStore: peerStore,
      timeout: timeout,
    );
  }

  FileInteropService createFileInteropService({
    SaveLocationPicker? saveLocationPicker,
    OpenFilePicker? openFilePicker,
    ExportDirectoryPicker? exportDirectoryPicker,
    ExportDirectoryProvider? exportDirectoryProvider,
  }) {
    return FileInteropService(
      repository: repository,
      saveLocationPicker: saveLocationPicker,
      openFilePicker: openFilePicker,
      exportDirectoryPicker: exportDirectoryPicker,
      exportDirectoryProvider: exportDirectoryProvider,
    );
  }

  AppState createAppState({
    SyncService? syncService,
    LanSyncServer? lanSyncServer,
    LanSyncClient? lanSyncClient,
    FileInteropService? fileInteropService,
    AppUpdateService? updateService,
    AppVersionLoader? appVersionLoader,
    TargetPlatformLoader? targetPlatformLoader,
    SyncStatusStore? syncStatusStore,
  }) {
    return AppState(
      repository: repository,
      activityRepository: activityRepository,
      entryRepository: timeEntryRepository,
      syncService: syncService ?? createSyncService(),
      lanSyncServer: lanSyncServer ?? createLanSyncServer(),
      lanSyncClient: lanSyncClient ?? createLanSyncClient(),
      fileInteropService: fileInteropService ?? createFileInteropService(),
      updateService: updateService,
      appVersionLoader: appVersionLoader,
      targetPlatformLoader: targetPlatformLoader,
      syncStatusStore: syncStatusStore ?? this.syncStatusStore,
    );
  }

  Future<void> close() {
    return sqliteDatabase.close();
  }
}

class TestAppFixture {
  const TestAppFixture({
    required this.repositories,
    required this.state,
    required this.syncService,
    required this.lanSyncServer,
    required this.lanSyncClient,
    required this.fileInteropService,
  });

  final TestRepositoryFixture repositories;
  final AppState state;
  final SyncService syncService;
  final LanSyncServer lanSyncServer;
  final LanSyncClient lanSyncClient;
  final FileInteropService fileInteropService;

  TimeRepository get repository => repositories.repository;

  LocalDatabase get database => repositories.database;

  Database get sqliteDatabase => repositories.sqliteDatabase;

  ActivityRepository get activityRepository => repositories.activityRepository;

  TimeEntryRepository get timeEntryRepository =>
      repositories.timeEntryRepository;

  DeviceIdStore get deviceIdStore => repositories.deviceIdStore;

  SyncStatusStore get syncStatusStore => repositories.syncStatusStore;

  Future<void> dispose() async {
    await lanSyncServer.stop();
    state.dispose();
    await repositories.close();
  }
}

Future<TestRepositoryFixture> buildTestRepositoryFixture({
  bool seedData = true,
  String? deviceId,
}) async {
  sqfliteFfiInit();
  final sqliteDatabase = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await LocalDatabase.createSchema(sqliteDatabase);
  final database = LocalDatabase(database: sqliteDatabase);
  final activityRepository = ActivityRepository(database: database);
  final settingsRepository = SettingsRepository(database: database);
  final deviceIdStore = DeviceIdStore(
    database: database,
    deviceId: deviceId,
  );
  final timeEntryRepository = TimeEntryRepository(
    database: database,
    activityRepository: activityRepository,
  );
  final actionLogRepository = ActionLogRepository(database: database);
  final repository = TimeRepository(
    database: database,
    activityRepository: activityRepository,
    settingsRepository: settingsRepository,
    deviceIdStore: deviceIdStore,
    timeEntryRepository: timeEntryRepository,
    actionLogRepository: actionLogRepository,
  );
  if (seedData) {
    await repository.ensureSeedData();
  }
  return TestRepositoryFixture(
    database: database,
    sqliteDatabase: sqliteDatabase,
    activityRepository: activityRepository,
    settingsRepository: settingsRepository,
    deviceIdStore: deviceIdStore,
    timeEntryRepository: timeEntryRepository,
    actionLogRepository: actionLogRepository,
    repository: repository,
    peerStore: SyncPeerStore(database: database),
    syncStatusStore: SyncStatusStore(database: database),
  );
}

Future<TestAppFixture> buildTestAppFixture({
  bool seedData = true,
  bool refresh = true,
  String? deviceId,
  DateTime? now,
  DateTime? selectedDay,
  bool isLoading = false,
  List<int> lanPortCandidates = const [0],
  InternetAddress? lanBindAddress,
  Duration lanClientTimeout = const Duration(seconds: 8),
}) async {
  final repositories = await buildTestRepositoryFixture(
    seedData: seedData,
    deviceId: deviceId,
  );
  final syncService = repositories.createSyncService();
  final lanSyncServer = repositories.createLanSyncServer(
    portCandidates: lanPortCandidates,
    bindAddress: lanBindAddress,
  );
  final lanSyncClient = repositories.createLanSyncClient(
    timeout: lanClientTimeout,
  );
  final fileInteropService = repositories.createFileInteropService();
  final state = repositories.createAppState(
    syncService: syncService,
    lanSyncServer: lanSyncServer,
    lanSyncClient: lanSyncClient,
    fileInteropService: fileInteropService,
  )..isLoading = isLoading;
  if (now != null) {
    state.now = now;
  }
  if (selectedDay != null) {
    state.selectedDay = selectedDay;
  }
  if (refresh) {
    await state.refresh();
  }
  return TestAppFixture(
    repositories: repositories,
    state: state,
    syncService: syncService,
    lanSyncServer: lanSyncServer,
    lanSyncClient: lanSyncClient,
    fileInteropService: fileInteropService,
  );
}
