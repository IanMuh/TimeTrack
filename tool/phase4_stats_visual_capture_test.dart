import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/app_shell.dart';
import 'package:timetrack/ui/app_theme.dart';

import '../test/stats_reference_state.dart';
import '../test/test_fixtures.dart';

const _captureKey = ValueKey('phase4-stats-shell-capture');

void main() {
  testWidgets('capture Phase 4 mobile Stats shell', (tester) async {
    await tester.runAsync(_loadRobotoFonts);
    final fixture = (await tester.runAsync(() async {
      final fixture = await buildTestAppFixture(
        seedData: false,
        refresh: false,
        now: DateTime(2024, 5, 19, 17, 0, 17),
        selectedDay: DateTime(2024, 5, 19),
      );
      await seedStatsReferenceFixture(fixture);
      return fixture;
    }))!;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(fixture.dispose);
    });

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
          child: AppShell(state: fixture.state),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Stats'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('Total Time'), findsOneWidget);
    expect(find.text('28h 14m'), findsOneWidget);
    expect(find.text('Daily Avg'), findsOneWidget);
    expect(find.text('4h 02m'), findsOneWidget);
    expect(find.text('Time by Day (h)'), findsOneWidget);
    expect(find.text('Time by Activity'), findsOneWidget);
    expect(find.text('Deep Work'), findsAtLeastNWidgets(1));
    expect(find.text('40%'), findsOneWidget);
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/phase4-stats-mobile.png'),
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
