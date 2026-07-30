import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/sort_controls.dart';

void main() {
  testWidgets('sort order segmented button uses localized labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SortOrderSegmentedButton(
            value: SortOrder.ascending,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ascending'), findsOneWidget);
    expect(find.text('Descending'), findsOneWidget);
    expect(find.text('顺序'), findsNothing);
    expect(find.text('倒序'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
