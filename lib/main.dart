import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_state.dart';
import 'core/app_config.dart';
import 'data/activity_repository.dart';
import 'data/device_id_store.dart';
import 'data/file_interop_service.dart';
import 'data/lan_sync.dart';
import 'data/local_database.dart';
import 'data/settings_repository.dart';
import 'data/sync_peer_store.dart';
import 'data/sync_service.dart';
import 'data/time_repository.dart';
import 'l10n/app_localizations.dart';
import 'ui/app_shell.dart';
import 'ui/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SupabaseClient? client;
  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    client = Supabase.instance.client;
  }

  final database = LocalDatabase();
  final activityRepository = ActivityRepository(database: database);
  final settingsRepository = SettingsRepository(database: database);
  final deviceIdStore = DeviceIdStore(database: database);
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
  final peerStore = SyncPeerStore(database: database);
  final state = AppState(
    repository: repository,
    activityRepository: activityRepository,
    entryRepository: timeEntryRepository,
    syncService: SyncService(
      repository: repository,
      activityRepository: activityRepository,
      settingsRepository: settingsRepository,
      timeEntryRepository: timeEntryRepository,
      actionLogRepository: actionLogRepository,
      client: client,
    ),
    lanSyncServer: LanSyncServer(
      repository: repository,
      activityRepository: activityRepository,
      deviceIdStore: deviceIdStore,
      timeEntryRepository: timeEntryRepository,
      peerStore: peerStore,
    ),
    lanSyncClient: LanSyncClient(
      repository: repository,
      activityRepository: activityRepository,
      deviceIdStore: deviceIdStore,
      timeEntryRepository: timeEntryRepository,
      peerStore: peerStore,
    ),
    fileInteropService: FileInteropService(
      repository: repository,
      activityRepository: activityRepository,
      timeEntryRepository: timeEntryRepository,
    ),
  );
  await state.initialize();

  runApp(TimeTrackApp(state: state));
}

class TimeTrackApp extends StatelessWidget {
  const TimeTrackApp({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return MaterialApp(
          title: 'TimeTrack',
          debugShowCheckedModeBanner: false,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: TimeTrackTheme.light(),
          darkTheme: TimeTrackTheme.dark(),
          themeMode: ThemeMode.system,
          home: AppShell(state: state),
        );
      },
    );
  }
}
