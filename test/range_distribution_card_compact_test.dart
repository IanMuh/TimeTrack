import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/time_stats.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/stats_page.dart';

import 'test_fixtures.dart';

Future<TestAppFixture> _buildFixture() async {
  return buildTestAppFixture(
    seedData: false,
    refresh: false,
    now: DateTime(2026, 1, 2, 12),
    selectedDay: DateTime(2026, 1, 2),
  );
}

Future<void> _disposeFixture(
  WidgetTester tester,
  TestAppFixture fixture,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(fixture.dispose);
}

void main() {
  testWidgets('compact distribution card does not render a percent title',
      (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    addTearDown(() => _disposeFixture(tester, fixture));

    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: RangeDistributionCard(
              state: fixture.state,
              title: '今天分布',
              rows: const [
                StatsGroupRow(
                  id: 'work',
                  label: '工作',
                  totalDuration: Duration(hours: 1),
                  count: 1,
                  color: 0xff2563eb,
                ),
              ],
              totalMinutes: 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('100%'), findsNothing);
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact distribution legend uses English terse duration',
      (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    addTearDown(() => _disposeFixture(tester, fixture));

    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: RangeDistributionCard(
              state: fixture.state,
              title: 'Today distribution',
              rows: const [
                StatsGroupRow(
                  id: 'work',
                  label: 'Work',
                  totalDuration: Duration(hours: 1),
                  count: 3,
                  color: 0xff2563eb,
                ),
              ],
              totalMinutes: 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1h · 3x'), findsOneWidget);
    expect(find.textContaining('小时'), findsNothing);
    expect(find.textContaining('次'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
