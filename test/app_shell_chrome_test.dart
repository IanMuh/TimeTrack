import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/ui/adaptive_layout.dart';
import 'package:timetrack/ui/app_shell_footer.dart';
import 'package:timetrack/ui/app_shell_navigation_rail.dart';
import 'package:timetrack/ui/running_timer_bar.dart';

import 'app_shell_test_support.dart';
import 'today_reference_state.dart';

void main() {
  testWidgets('shell shows undo and redo controls on expanded layout',
      (tester) async {
    final state = ShellTestState();
    addTearDown(state.dispose);

    await pumpShell(tester, state, width: 1000);

    expect(find.byTooltip('撤销 Ctrl+Z'), findsOneWidget);
    expect(find.byTooltip('重做 Ctrl+Y'), findsOneWidget);
    expect(find.byType(RunningTimerBar), findsOneWidget);
    expect(tester.widget<IconButton>(historyButton('撤销')).onPressed, isNull);
    expect(tester.widget<IconButton>(historyButton('重做')).onPressed, isNull);

    state.setHistory(
      canUndo: true,
      canRedo: true,
      undoLabel: '补记时间段',
      redoLabel: '删除时间段',
    );
    await pumpShortcutFrame(tester);

    expect(find.byTooltip('撤销：补记时间段 Ctrl+Z'), findsOneWidget);
    expect(find.byTooltip('重做：删除时间段 Ctrl+Y'), findsOneWidget);
  });

  testWidgets('medium desktop rail uses lighter density and selected labels',
      (tester) async {
    final state = ShellTestState();
    addTearDown(state.dispose);

    await pumpShell(tester, state, width: 700);

    final rail = tester.widget<DesktopNavigationRail>(
      find.byType(DesktopNavigationRail),
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(rail.selectedIndex, 0);
    expect(
      tester.getSize(find.byType(DesktopNavigationRail)).width,
      desktopRailWidth(AdaptiveSizeClass.medium),
    );
    expect(find.text('TimeTrack'), findsOneWidget);
    expect(find.byType(RunningTimerBar), findsOneWidget);
    expect(find.byTooltip('撤销 Ctrl+Z'), findsOneWidget);
    expect(find.byTooltip('重做 Ctrl+Y'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop body reserves space above running timer footer',
      (tester) async {
    final state = ShellTestState();
    addTearDown(state.dispose);

    await pumpShell(tester, state, width: 1000);

    final page = find.byKey(const PageStorageKey<String>('timer-page'));
    expect(page, findsOneWidget);
    expect(find.byType(RunningTimerBar), findsOneWidget);

    final pageBottom = tester.getBottomLeft(page).dy;
    final footerTop = tester.getTopLeft(find.byType(RunningTimerBar)).dy;

    expect(footerTop - pageBottom, closeTo(shellDesktopFooterSafeGap, 0.1));
  });

  testWidgets('shell shows undo and redo controls on compact layout',
      (tester) async {
    final state = ShellTestState();
    addTearDown(state.dispose);

    await pumpShell(tester, state, width: 390);

    expect(find.byTooltip('撤销 Ctrl+Z / 重做 Ctrl+Y'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(RunningTimerBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).labelBehavior,
      NavigationDestinationLabelBehavior.alwaysShow,
    );
    expect(find.text('计时'), findsAtLeastNWidgets(1));
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('时间线'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    final page = find.byKey(const PageStorageKey<String>('timer-page'));
    final pageBottom = tester.getBottomLeft(page).dy;
    final footerTop = tester.getTopLeft(find.byType(NavigationBar)).dy;

    expect(footerTop - pageBottom, closeTo(shellCompactFooterSafeGap, 0.1));

    state.setHistory(
      canUndo: true,
      canRedo: true,
      undoLabel: '补记时间段',
      redoLabel: '删除时间段',
    );
    await pumpShortcutFrame(tester);

    await tester.tap(find.byTooltip('撤销 Ctrl+Z / 重做 Ctrl+Y'));
    await tester.pumpAndSettle();

    expect(find.text('撤销：补记时间段 Ctrl+Z'), findsOneWidget);
    expect(find.text('重做：删除时间段 Ctrl+Y'), findsOneWidget);

    await tester.tap(find.text('撤销：补记时间段 Ctrl+Z'));
    await tester.pumpAndSettle();

    expect(state.undoCount, 1);
  });

  testWidgets('running timer bar stays visible and returns to current page',
      (tester) async {
    final state = ShellTestState()..startRunning();
    addTearDown(state.dispose);

    await pumpShell(tester, state, width: 1000);

    expect(find.byType(RunningTimerBar), findsOneWidget);
    expect(tester.getSize(find.byType(RunningTimerBar)).height, 52);
    expect(find.text('00:42:00'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('时间线'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DesktopNavigationRail>(find.byType(DesktopNavigationRail))
            .selectedIndex,
        2);

    await tester.tap(find.byType(RunningTimerBar));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DesktopNavigationRail>(find.byType(DesktopNavigationRail))
            .selectedIndex,
        0);
  });

  testWidgets('desktop Today timeline action selects the Timeline destination',
      (tester) async {
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);

    await pumpShell(tester, state, width: 1000);
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看完整时间线'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DesktopNavigationRail>(find.byType(DesktopNavigationRail))
          .selectedIndex,
      2,
    );
    expect(tester.takeException(), isNull);
  });
}
