import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/ui/settings_page.dart';

import 'app_shell_test_support.dart';

void main() {
  testWidgets('update snackbar appears once and action opens settings',
      (tester) async {
    final state = ShellTestState();
    addTearDown(state.dispose);
    await pumpShell(tester, state, width: 1000);

    state.showUpdatePrompt();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('TimeTrack 0.2.0-pre 已可用。'), findsOneWidget);
    expect(state.updatePromptMarkCount, 1);

    state.showUpdatePrompt();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('TimeTrack 0.2.0-pre 已可用。'), findsOneWidget);
    expect(state.updatePromptMarkCount, 1);

    final settingsAction = find.byWidgetPredicate(
      (widget) => widget is SnackBarAction && widget.label == '设置',
    );
    expect(settingsAction, findsOneWidget);

    await tester.tap(settingsAction);
    await tester.pumpAndSettle();

    expect(find.byType(VersionUpdateSettingsCard), findsOneWidget);
    expect(find.text('当前版本'), findsOneWidget);
  });
}
