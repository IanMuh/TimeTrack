import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_state.dart';
import 'core/app_config.dart';
import 'data/file_interop_service.dart';
import 'data/lan_sync.dart';
import 'data/local_database.dart';
import 'data/sync_peer_store.dart';
import 'data/sync_service.dart';
import 'data/time_repository.dart';
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
  final repository = TimeRepository(database: database);
  final peerStore = SyncPeerStore(database: database);
  final state = AppState(
    repository: repository,
    syncService: SyncService(repository: repository, client: client),
    lanSyncServer: LanSyncServer(
      repository: repository,
      peerStore: peerStore,
    ),
    lanSyncClient: LanSyncClient(
      repository: repository,
      peerStore: peerStore,
    ),
    fileInteropService: FileInteropService(repository: repository),
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
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: TimeTrackTheme.light(),
          home: AppShell(state: state),
        );
      },
    );
  }
}
