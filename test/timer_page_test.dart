import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/app_theme.dart';
import 'package:timetrack/ui/timer_page.dart';

import 'app_shell_test_support.dart';

Future<void> _pumpTimerPage(
  WidgetTester tester,
  ShellTestState state, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  double width = 390,
  double height = 844,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? TimeTrackTheme.light(),
      home: Scaffold(body: TimerPage(state: state)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('TimerPage shows the reference timer surface while recording',
      (tester) async {
    final state = ShellTestState()..startRunning();
    addTearDown(state.dispose);
    state.activities = [
      Activity(
        id: 'work',
        userId: null,
        name: 'Deep Work',
        color: 0xff14b8a6,
        isFavorite: true,
        updatedAt: state.now,
        isDeleted: false,
      ),
      Activity(
        id: 'meetings',
        userId: null,
        name: 'Meetings',
        color: 0xff3b82f6,
        isFavorite: true,
        updatedAt: state.now,
        isDeleted: false,
      ),
      Activity(
        id: 'learning',
        userId: null,
        name: 'Learning',
        color: 0xff8b5cf6,
        isFavorite: true,
        updatedAt: state.now,
        isDeleted: false,
      ),
    ];

    await _pumpTimerPage(tester, state);

    expect(
        find.byKey(const PageStorageKey<String>('timer-page')), findsOneWidget);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('00:42:00'), findsOneWidget);
    expect(find.text('Current Session'), findsOneWidget);
    expect(find.text('Deep Work'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Stop'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Switch'), findsOneWidget);
    expect(find.text('Quick Activity'), findsOneWidget);
    expect(find.text('Meetings'), findsOneWidget);
    expect(find.text('Learning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TimerPage uses the mobile timer surface at expanded width',
      (tester) async {
    final state = ShellTestState()..startRunning();
    addTearDown(state.dispose);
    state.activities = [
      Activity(
        id: 'work',
        userId: null,
        name: 'Deep Work',
        color: 0xff14b8a6,
        isFavorite: true,
        updatedAt: state.now,
        isDeleted: false,
      ),
      Activity(
        id: 'meetings',
        userId: null,
        name: 'Meetings',
        color: 0xff3b82f6,
        isFavorite: true,
        updatedAt: state.now,
        isDeleted: false,
      ),
      Activity(
        id: 'learning',
        userId: null,
        name: 'Learning',
        color: 0xff8b5cf6,
        isFavorite: true,
        updatedAt: state.now,
        isDeleted: false,
      ),
    ];

    await _pumpTimerPage(tester, state, width: 1200, height: 900);

    expect(
        find.byKey(const PageStorageKey<String>('timer-page')), findsOneWidget);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('Current Session'), findsWidgets);
    expect(find.text('Quick Activity'), findsOneWidget);
    expect(find.textContaining('Today'), findsWidgets);
    expect(find.textContaining('Sessions'), findsWidgets);
    expect(find.text('View full timeline'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Stop'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Switch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TimerPage keeps reference content legible in dark mode',
      (tester) async {
    final state = ShellTestState()..startRunning();
    addTearDown(state.dispose);
    state.activities = [
      Activity(
        id: 'work',
        userId: null,
        name: 'Deep Work',
        color: 0xff14b8a6,
        isFavorite: true,
        updatedAt: state.now,
        isDeleted: false,
      ),
      Activity(
        id: 'meetings',
        userId: null,
        name: 'Meetings',
        color: 0xff3b82f6,
        isFavorite: true,
        updatedAt: state.now,
        isDeleted: false,
      ),
    ];

    await _pumpTimerPage(tester, state, theme: TimeTrackTheme.dark());

    final context = tester.element(find.byType(TimerPage));
    expect(Theme.of(context).colorScheme.brightness, Brightness.dark);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('00:42:00'), findsOneWidget);
    expect(find.text('Deep Work'), findsWidgets);
    expect(find.text('Meetings'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Stop'), findsOneWidget);
    final stopButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Stop'),
    );
    expect(
      stopButton.style?.backgroundColor?.resolve({}),
      const Color(0xffef4444),
    );
    expect(find.widgetWithText(OutlinedButton, 'Switch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
