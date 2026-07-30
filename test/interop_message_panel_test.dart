import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/interop_message_panel.dart';

void main() {
  testWidgets('interop message panel localizes exported message', (
    tester,
  ) async {
    const path = '/tmp/export.json';
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InteropMessagePanel(message: 'Exported: $path'),
        ),
      ),
    );

    expect(find.text('Exported'), findsOneWidget);
    expect(find.text(path), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('interop message panel localizes imported message', (
    tester,
  ) async {
    const path = '/tmp/import.json';
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InteropMessagePanel(message: 'Imported: $path'),
        ),
      ),
    );

    expect(find.text('Imported'), findsOneWidget);
    expect(find.text(path), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
