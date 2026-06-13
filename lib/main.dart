import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_state.dart';
import 'core/app_config.dart';
import 'data/local_database.dart';
import 'data/sync_service.dart';
import 'data/time_repository.dart';
import 'ui/app_shell.dart';

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

  final repository = TimeRepository(database: LocalDatabase());
  final state = AppState(
    repository: repository,
    syncService: SyncService(repository: repository, client: client),
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
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff2563eb),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xfff7f8fa),
          ),
          home: AppShell(state: state),
        );
      },
    );
  }
}
