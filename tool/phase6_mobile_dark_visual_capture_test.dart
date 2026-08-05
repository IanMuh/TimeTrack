import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/time_entry.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/app_shell.dart';
import 'package:timetrack/ui/app_theme.dart';

import '../test/app_shell_test_support.dart';
import '../test/today_reference_state.dart';

const _timerCaptureKey = ValueKey('phase6-dark-timer-shell-capture');
const _todayCaptureKey = ValueKey('phase6-dark-today-shell-capture');

void main() {
  testWidgets('capture Phase 6 mobile dark Timer shell', (tester) async {
    await tester.runAsync(_loadRobotoFonts);
    final state = ShellTestState();
    addTearDown(state.dispose);
    _seedTimerReferenceState(state);

    _setMobileViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: TimeTrackTheme.dark(),
        home: RepaintBoundary(
          key: _timerCaptureKey,
          child: AppShell(state: state),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Timer'), findsAtLeastNWidgets(1));
    expect(find.text('Deep Work'), findsWidgets);
    expect(find.text('Quick Activity'), findsOneWidget);
    await expectLater(
      find.byKey(_timerCaptureKey),
      matchesGoldenFile('goldens/phase6-timer-dark-mobile.png'),
    );
  });

  testWidgets('capture Phase 6 mobile dark Today shell', (tester) async {
    await tester.runAsync(_loadRobotoFonts);
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);

    _setMobileViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: TimeTrackTheme.dark(),
        home: RepaintBoundary(
          key: _todayCaptureKey,
          child: AppShell(state: state),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Today'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Today'), findsAtLeastNWidgets(1));
    expect(find.text('May 15, 2024'), findsOneWidget);
    expect(find.text('Top Activities'), findsOneWidget);
    await expectLater(
      find.byKey(_todayCaptureKey),
      matchesGoldenFile('goldens/phase6-today-dark-mobile.png'),
    );
  });
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _loadRobotoFonts() async {
  final loader = FontLoader('Roboto')
    ..addFont(_fontData(
      r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-regular.ttf',
    ))
    ..addFont(_fontData(
      r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-medium.ttf',
    ))
    ..addFont(_fontData(
      r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-bold.ttf',
    ))
    ..addFont(_fontData(
      r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-black.ttf',
    ));
  await loader.load();

  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(_fontData(
      r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
    ));
  await iconLoader.load();
}

Future<ByteData> _fontData(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}

void _seedTimerReferenceState(ShellTestState state) {
  final now = DateTime(2024, 5, 15, 10, 25, 17);
  state.now = now;
  state.clockNotifier.value = now;
  state.selectedDay = DateTime(2024, 5, 15);
  state.activities = _timerReferenceActivities(now);
  state.startRunning(
    elapsed: const Duration(hours: 1, minutes: 24, seconds: 17),
  );
  state.dayEntries = [
    state.runningEntry!,
    TimeEntry(
      id: 'meeting-entry',
      userId: null,
      activityId: 'meetings',
      activityNameSnapshot: 'Meetings',
      activityColorSnapshot: 0xff3b82f6,
      startAt: DateTime(2024, 5, 15, 8, 20),
      endAt: DateTime(2024, 5, 15, 9, 50),
      note: '',
      deviceId: 'phase6-dark-visual',
      updatedAt: now,
      isDeleted: false,
    ),
    TimeEntry(
      id: 'learning-entry',
      userId: null,
      activityId: 'learning',
      activityNameSnapshot: 'Learning',
      activityColorSnapshot: 0xff8b5cf6,
      startAt: DateTime(2024, 5, 15, 7, 30),
      endAt: DateTime(2024, 5, 15, 8, 35),
      note: '',
      deviceId: 'phase6-dark-visual',
      updatedAt: now,
      isDeleted: false,
    ),
    TimeEntry(
      id: 'admin-entry',
      userId: null,
      activityId: 'admin',
      activityNameSnapshot: 'Admin',
      activityColorSnapshot: 0xff64748b,
      startAt: DateTime(2024, 5, 15, 9, 55),
      endAt: DateTime(2024, 5, 15, 10, 7),
      note: '',
      deviceId: 'phase6-dark-visual',
      updatedAt: now,
      isDeleted: false,
    ),
  ];
}

List<Activity> _timerReferenceActivities(DateTime now) {
  return [
    Activity(
      id: 'work',
      userId: null,
      name: 'Deep Work',
      color: 0xff14b8a6,
      isFavorite: true,
      updatedAt: now,
      isDeleted: false,
    ),
    Activity(
      id: 'meetings',
      userId: null,
      name: 'Meetings',
      color: 0xff3b82f6,
      isFavorite: true,
      updatedAt: now,
      isDeleted: false,
    ),
    Activity(
      id: 'learning',
      userId: null,
      name: 'Learning',
      color: 0xff8b5cf6,
      isFavorite: true,
      updatedAt: now,
      isDeleted: false,
    ),
    Activity(
      id: 'exercise',
      userId: null,
      name: 'Exercise',
      color: 0xff22c55e,
      isFavorite: true,
      updatedAt: now,
      isDeleted: false,
    ),
  ];
}
