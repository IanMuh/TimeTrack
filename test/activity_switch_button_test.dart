import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/home_page.dart';

Activity _activity() {
  return Activity(
    id: 'work',
    userId: null,
    name: '工作',
    color: 0xff2563eb,
    isFavorite: true,
    updatedAt: DateTime(2026, 1, 1),
    isDeleted: false,
  );
}

void main() {
  testWidgets('activity button supports two tap confirmation flow', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(locale: const Locale('zh'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ActivitySwitchButton(
            activity: _activity(),
            selected: false,
            pending: false,
            onTap: () => taps += 1,
            onDoubleTap: () {},
            onEdit: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('工作'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 1));

    expect(taps, 1);

    await tester.tap(find.text('工作'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(taps, 2);
  });

  testWidgets('activity button exposes selected and pending visual states', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(locale: const Locale('zh'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              ActivitySwitchButton(
                activity: _activity(),
                selected: true,
                pending: false,
                onTap: () {},
                onDoubleTap: () {},
                onEdit: () {},
              ),
              ActivitySwitchButton(
                activity: _activity(),
                selected: false,
                pending: true,
                onTap: () {},
                onDoubleTap: () {},
                onEdit: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_double_arrow_right), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
