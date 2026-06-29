import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/home_page.dart';

import 'test_fixtures.dart';

Future<void> _pumpHome(
  WidgetTester tester,
  TestAppFixture fixture, {
  required double width,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 900,
          child: HomePage(state: fixture.state),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('compact home prioritizes current status and folds sorting',
      (tester) async {
    final fixture = (await tester.runAsync(
      () => buildTestAppFixture(
        seedData: false,
        refresh: false,
        now: DateTime(2026, 1, 2, 12),
      ),
    ))!;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(fixture.dispose);
    });
    fixture.state.activities = [
      Activity(
        id: 'work',
        userId: null,
        name: '工作',
        color: 0xff2563eb,
        isFavorite: true,
        updatedAt: DateTime(2026, 1, 2),
        isDeleted: false,
      ),
      Activity(
        id: 'study',
        userId: null,
        name: '学习',
        color: 0xff0f766e,
        isFavorite: false,
        updatedAt: DateTime(2026, 1, 1),
        isDeleted: false,
      ),
    ];

    await _pumpHome(tester, fixture, width: 390);

    expect(find.text('当前正在做'), findsOneWidget);
    expect(find.text('本地模式：可在设置中开启局域网互通或导入导出'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('当前正在做')).dy,
      lessThan(tester.getTopLeft(find.text('本地模式：可在设置中开启局域网互通或导入导出')).dy),
    );
    expect(find.byTooltip('排序依据'), findsOneWidget);
    expect(_activitySortDropdownFinder(), findsNothing);

    await tester.tap(find.byTooltip('排序依据'));
    await tester.pumpAndSettle();

    expect(_activitySortDropdownFinder(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Finder _activitySortDropdownFinder() {
  return find.byWidgetPredicate(
    (widget) => widget is DropdownButtonFormField<ActivitySortMetric>,
  );
}
