import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_shell_test_support.dart';

void main() {
  testWidgets('undo and redo keyboard shortcuts invoke state actions',
      (tester) async {
    final state = ShellTestState()
      ..setHistory(canUndo: true, canRedo: false, undoLabel: '补记时间段');
    addTearDown(state.dispose);
    await pumpShell(tester, state, width: 1000);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pumpShortcutFrame(tester);

    expect(state.undoCount, 1);
    expect(state.canRedo, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pumpShortcutFrame(tester);

    expect(state.redoCount, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pumpShortcutFrame(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pumpShortcutFrame(tester);

    expect(state.redoCount, 2);
  });

  testWidgets('undo shortcut does not override focused text editing',
      (tester) async {
    final state = ShellTestState()
      ..setHistory(canUndo: true, canRedo: false, undoLabel: '补记时间段');
    addTearDown(state.dispose);
    await pumpShell(tester, state, width: 1000);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pumpShortcutFrame(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pumpShortcutFrame(tester);

    await tester.enterText(
      find.byKey(const ValueKey('entry-activity-search-field')),
      '新事项',
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pumpShortcutFrame(tester);

    expect(state.undoCount, 0);
  });

  testWidgets('destination and timeline shortcuts work', (tester) async {
    final state = ShellTestState();
    addTearDown(state.dispose);
    await pumpShell(tester, state, width: 1000);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pumpShortcutFrame(tester);
    expect(find.text('时间轴'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await pumpShortcutFrame(tester);
    expect(state.selectedDay, DateTime(2025, 12, 31));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await pumpShortcutFrame(tester);
    expect(state.selectedDay, DateTime(2026, 1, 1));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pumpShortcutFrame(tester);
    expect(find.widgetWithText(AlertDialog, '补记时间段'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await pumpShortcutFrame(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pumpShortcutFrame(tester);
    expect(find.text('设置'), findsWidgets);
  });
}
