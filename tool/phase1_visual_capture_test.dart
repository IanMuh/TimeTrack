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

const _captureKey = ValueKey('phase1-shell-capture');

void main() {
  testWidgets('capture Phase 1 mobile Timer shell', (tester) async {
    await tester.runAsync(_loadRobotoFonts);
    final state = ShellTestState();
    addTearDown(state.dispose);
    _seedReferenceState(state);

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
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Timer'), findsAtLeastNWidgets(1));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/phase1-shell-mobile.png'),
    );
  });
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

void _seedReferenceState(ShellTestState state) {
  final now = DateTime(2024, 5, 15, 10, 25, 17);
  state.now = now;
  state.selectedDay = DateTime(2024, 5, 15);
  state.activities = [
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
  state.startRunning(
      elapsed: const Duration(hours: 1, minutes: 24, seconds: 17));
  state.dayEntries = [
    state.runningEntry!,
    _entry(
      id: 'meeting-entry',
      activityId: 'meetings',
      activityName: 'Meetings',
      color: 0xff3b82f6,
      start: DateTime(2024, 5, 15, 8, 20),
      end: DateTime(2024, 5, 15, 9, 50),
      updatedAt: now,
    ),
    _entry(
      id: 'learning-entry',
      activityId: 'learning',
      activityName: 'Learning',
      color: 0xff8b5cf6,
      start: DateTime(2024, 5, 15, 7, 30),
      end: DateTime(2024, 5, 15, 8, 35),
      updatedAt: now,
    ),
    _entry(
      id: 'admin-entry',
      activityId: 'exercise',
      activityName: 'Exercise',
      color: 0xff22c55e,
      start: DateTime(2024, 5, 15, 9, 55),
      end: DateTime(2024, 5, 15, 10, 7),
      updatedAt: now,
    ),
  ];
}

TimeEntry _entry({
  required String id,
  required String activityId,
  required String activityName,
  required int color,
  required DateTime start,
  required DateTime end,
  required DateTime updatedAt,
}) {
  return TimeEntry(
    id: id,
    userId: null,
    activityId: activityId,
    activityNameSnapshot: activityName,
    activityColorSnapshot: color,
    startAt: start,
    endAt: end,
    note: '',
    deviceId: 'phase1-visual',
    updatedAt: updatedAt,
    isDeleted: false,
  );
}
