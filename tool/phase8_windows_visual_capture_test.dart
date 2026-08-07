import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/app_shell.dart';
import 'package:timetrack/ui/app_theme.dart';

import '../test/app_shell_test_support.dart';
import '../test/stats_reference_state.dart';
import '../test/test_fixtures.dart';
import '../test/timeline_reference_state.dart';
import '../test/today_reference_state.dart';

const _timerCaptureKey = ValueKey('phase8-desktop-timer-shell-capture');
const _timelineCaptureKey = ValueKey('phase8-desktop-timeline-shell-capture');
const _statsCaptureKey = ValueKey('phase8-desktop-stats-shell-capture');

void main() {
  testWidgets('capture Phase 8 desktop Timer shell', (tester) async {
    await tester.runAsync(_loadRobotoFonts);
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);

    _setDesktopViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: TimeTrackTheme.light(),
        home: RepaintBoundary(
          key: _timerCaptureKey,
          child: AppShell(state: state),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Timer'), findsAtLeastNWidgets(1));
    expect(find.text('Current Session'), findsWidgets);
    expect(find.text('Quick Activity'), findsOneWidget);
    expect(find.text('View full timeline'), findsOneWidget);
    await expectLater(
      find.byKey(_timerCaptureKey),
      matchesGoldenFile('goldens/phase8-timer-desktop.png'),
    );
  });

  testWidgets('capture Phase 8 desktop Timeline shell', (tester) async {
    await tester.runAsync(_loadRobotoFonts);
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTimelineReferenceState(state);

    _setDesktopViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: TimeTrackTheme.light(),
        home: RepaintBoundary(
          key: _timelineCaptureKey,
          child: AppShell(state: state),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Timeline'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Timeline'), findsAtLeastNWidgets(1));
    expect(find.text('Range total'), findsOneWidget);
    expect(find.text('Zoomable timeline'), findsOneWidget);
    expect(find.text('Entry list'), findsOneWidget);
    await expectLater(
      find.byKey(_timelineCaptureKey),
      matchesGoldenFile('goldens/phase8-timeline-desktop.png'),
    );
  });

  testWidgets('capture Phase 8 desktop Stats shell', (tester) async {
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

    _setDesktopViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: TimeTrackTheme.light(),
        home: RepaintBoundary(
          key: _statsCaptureKey,
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

    expect(find.text('Stats'), findsAtLeastNWidgets(1));
    expect(find.text('Range total'), findsOneWidget);
    expect(find.text('This week distribution'), findsOneWidget);
    expect(find.text('Stats dimension'), findsOneWidget);
    expect(find.text('Daily total'), findsOneWidget);
    await expectLater(
      find.byKey(_statsCaptureKey),
      matchesGoldenFile('goldens/phase8-stats-desktop.png'),
    );
  });
}

void _setDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
