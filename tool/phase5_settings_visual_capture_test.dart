import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/data/sync_status_store.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/app_shell.dart';
import 'package:timetrack/ui/app_theme.dart';

import '../test/app_shell_test_support.dart';
import '../test/today_reference_state.dart';

const _captureKey = ValueKey('phase5-settings-shell-capture');

void main() {
  testWidgets('capture Phase 5 mobile Settings shell', (tester) async {
    await tester.runAsync(_loadRobotoFonts);
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);
    state.currentAppVersion = '1.0.0';
    state.syncStatus = SyncStatus(
      lastSuccessfulSyncAt: DateTime(2024, 5, 15, 9, 30),
      lastTarget: SyncTarget.cloud,
    );

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: TimeTrackTheme.light(),
        home: RepaintBoundary(
          key: _captureKey,
          child: AppShell(state: state),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Settings'), findsAtLeastNWidgets(1));
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('First Day of Week'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Time Format'), findsOneWidget);
    expect(find.text('12-hour'), findsOneWidget);
    expect(find.text('Default Session Length'), findsOneWidget);
    expect(find.text('25 min'), findsOneWidget);
    expect(find.text('Quick Reminder'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Backup & Export'), findsOneWidget);
    expect(find.text('Export Data'), findsOneWidget);
    expect(find.text('Clear All Data'), findsOneWidget);
    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('Sync Mode'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('Last Sync'), findsOneWidget);
    expect(find.text('May 15, 9:30 AM'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('About TimeTrack'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/phase5-settings-mobile.png'),
    );
  });
}

Future<void> _loadRobotoFonts() async {
  final loader = FontLoader('Roboto')
    ..addFont(
      _fontData(
        r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-regular.ttf',
      ),
    )
    ..addFont(
      _fontData(
        r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-medium.ttf',
      ),
    )
    ..addFont(
      _fontData(
        r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-bold.ttf',
      ),
    )
    ..addFont(
      _fontData(
        r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-black.ttf',
      ),
    );
  await loader.load();

  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(
      _fontData(
        r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
      ),
    );
  await iconLoader.load();
}

Future<ByteData> _fontData(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}
