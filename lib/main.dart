import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_dependencies.dart';
import 'app/app_state.dart';
import 'core/app_config.dart';
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

  final dependencies = buildAppDependencies(supabaseClient: client);
  final state = dependencies.appState;
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
