import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/app_theme.dart';
import 'package:timetrack/ui/today_page.dart';

import 'app_shell_test_support.dart';
import 'today_reference_state.dart';

Future<void> _pumpTodayPage(
  WidgetTester tester,
  ShellTestState state, {
  ThemeData? theme,
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
  VoidCallback? onOpenTimeline,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? TimeTrackTheme.light(),
      home: Scaffold(
        body: TodayPage(
          state: state,
          onOpenTimeline: onOpenTimeline,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('TodayPage shows the reference daily summary surface',
      (tester) async {
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);

    await _pumpTodayPage(tester, state);

    expect(
        find.byKey(const PageStorageKey<String>('today-page')), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('May 15, 2024'), findsOneWidget);
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.byTooltip('Select date'), findsOneWidget);
    expect(find.text('Total Time'), findsOneWidget);
    expect(find.text('6h 38m'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Focus Time'), findsOneWidget);
    expect(find.text('4h 15m'), findsOneWidget);
    expect(find.text('Break Time'), findsOneWidget);
    expect(find.text('1h 18m'), findsOneWidget);
    expect(find.text('Top Activities'), findsOneWidget);
    expect(find.text('Deep Work'), findsOneWidget);
    expect(find.text('2h 45m'), findsOneWidget);
    expect(find.text('41%'), findsOneWidget);
    expect(find.text('Meetings'), findsOneWidget);
    expect(find.text('1h 30m'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TodayPage uses desktop reference layout on expanded width',
      (tester) async {
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);

    await _pumpTodayPage(
      tester,
      state,
      size: const Size(920, 900),
      onOpenTimeline: () {},
    );

    expect(
      find.byKey(const PageStorageKey<String>('today-page')),
      findsOneWidget,
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Time by Activity'), findsNothing);
    expect(find.text('View full timeline'), findsOneWidget);
    expect(find.text('Top Activities'), findsOneWidget);
    expect(find.text('Project Phoenix'), findsOneWidget);
    expect(find.text('Team Standup'), findsOneWidget);
    expect(find.text('UX Course'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('1h 5m'), findsOneWidget);
    expect(find.text('Deep Work'), findsWidgets);
    expect(find.text('Personal'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TodayPage opens the full timeline from desktop preview',
      (tester) async {
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);
    var openedTimeline = false;

    await _pumpTodayPage(
      tester,
      state,
      size: const Size(920, 900),
      onOpenTimeline: () => openedTimeline = true,
    );

    await tester.tap(find.text('View full timeline'));
    await tester.pump();

    expect(openedTimeline, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TodayPage localizes desktop labels in Chinese without overflow',
      (tester) async {
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);

    await _pumpTodayPage(
      tester,
      state,
      size: const Size(920, 900),
      locale: const Locale('zh'),
      onOpenTimeline: () {},
    );

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('事项用时'), findsNothing);
    expect(find.text('查看完整时间线'), findsOneWidget);
    expect(find.text('高频事项'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TodayPage keeps summary cards legible in dark mode',
      (tester) async {
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);

    await _pumpTodayPage(tester, state, theme: TimeTrackTheme.dark());

    final context = tester.element(find.byType(TodayPage));
    expect(Theme.of(context).colorScheme.brightness, Brightness.dark);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Total Time'), findsOneWidget);
    expect(find.text('6h 38m'), findsOneWidget);
    expect(find.text('Top Activities'), findsOneWidget);
    expect(find.text('Deep Work'), findsOneWidget);
    expect(find.text('41%'), findsOneWidget);
    final darkCardColor =
        TimeTrackTheme.dark().colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.52,
            );
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) {
          return false;
        }
        final decoration = widget.decoration;
        return decoration is BoxDecoration && decoration.color == darkCardColor;
      }),
      findsAtLeastNWidgets(4),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TodayPage date picker updates the selected day', (tester) async {
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);

    await _pumpTodayPage(tester, state);

    await tester.tap(find.byTooltip('Select date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(state.selectedDay, DateTime(2024, 5, 20));
    expect(find.text('May 20, 2024'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
