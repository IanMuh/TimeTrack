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
    expect(find.text('本地模式：设置里可开启互通或导入导出'), findsOneWidget);
    expect(find.text('快捷切换'), findsOneWidget);
    expect(find.byType(ActivitySwitchButton), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('当前正在做')).dy,
      lessThan(tester.getTopLeft(find.text('本地模式：设置里可开启互通或导入导出')).dy),
    );
    expect(
      tester.getTopLeft(find.text('快捷切换')).dy,
      lessThan(tester.getTopLeft(find.byType(ActivitySwitchButton).first).dy),
    );
    expect(find.byTooltip('排序依据'), findsOneWidget);
    expect(_activitySortDropdownFinder(), findsNothing);

    await tester.tap(find.byTooltip('排序依据'));
    await tester.pumpAndSettle();

    expect(_activitySortDropdownFinder(), findsOneWidget);
    expect(find.byType(ActivitySwitchButton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('current status only shows stop action while recording',
      (tester) async {
    final clock = ValueNotifier(DateTime(2026, 1, 2, 12));
    addTearDown(clock.dispose);
    var stopCount = 0;

    Future<void> pumpStatus(Activity? runningActivity) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CurrentStatusCard(
              runningActivity: runningActivity,
              clockNotifier: clock,
              runningDurationAt: (_) => const Duration(minutes: 12),
              onStop: () => stopCount += 1,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpStatus(null);
    expect(find.text('停止当前事项'), findsNothing);

    await pumpStatus(
      Activity(
        id: 'work',
        userId: null,
        name: '工作',
        color: 0xff0d9488,
        isFavorite: true,
        updatedAt: DateTime(2026, 1, 2),
        isDeleted: false,
      ),
    );
    expect(find.text('停止当前事项'), findsOneWidget);

    await tester.tap(find.text('停止当前事项'));
    expect(stopCount, 1);
    expect(tester.takeException(), isNull);
  });
}

Finder _activitySortDropdownFinder() {
  return find.byWidgetPredicate(
    (widget) => widget is DropdownButtonFormField<ActivitySortMetric>,
  );
}
