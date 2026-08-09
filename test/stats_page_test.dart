import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/app_state.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/activity_category.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/stats_page.dart';
import 'test_fixtures.dart';

Future<TestAppFixture> _buildFixture() async {
  final fixture = await buildTestAppFixture(
    seedData: false,
    refresh: false,
    now: DateTime(2026, 1, 2, 12),
    selectedDay: DateTime(2026, 1, 2),
  );
  fixture.state.activities = [
    Activity(
      id: 'work',
      userId: null,
      name: '工作',
      color: 0xff2563eb,
      isFavorite: true,
      updatedAt: DateTime(2026, 1, 1),
      isDeleted: false,
    ),
  ];
  fixture.state.activityCategories = [
    ActivityCategory(
      id: 'cat-work',
      userId: null,
      name: '工作',
      color: 0xff0f766e,
      updatedAt: DateTime(2026, 1, 1),
      isDeleted: false,
    ),
  ];
  return fixture;
}

Future<void> _pumpStats(
  WidgetTester tester,
  AppState state, {
  required double width,
}) async {
  tester.view.physicalSize = Size(width, 900);
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
          width: width,
          height: 900,
          child: StatsPage(state: state),
        ),
      ),
    ),
  );
  await tester.pump();
  // StatsPage loads range stats asynchronously; give the future a chance
  // to complete before assertions run.
  await tester
      .runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
  await tester.pumpAndSettle();
}

Future<void> _disposeStatsFixture(
  WidgetTester tester,
  TestAppFixture fixture,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(fixture.dispose);
}

double _textTop(WidgetTester tester, String text) {
  return tester.getTopLeft(find.text(text)).dy;
}

double _textLeft(WidgetTester tester, String text) {
  return tester.getTopLeft(find.text(text)).dx;
}

void main() {
  testWidgets('stats page shows all five range preset options', (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    await _pumpStats(tester, state, width: 920);

    expect(find.text('今天'), findsWidgets);
    expect(find.text('昨天'), findsOneWidget);
    expect(find.text('本周'), findsWidgets);
    expect(find.text('上周'), findsOneWidget);
    expect(find.text('自选日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows loading indicator while stats load', (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    tester.view.physicalSize = const Size(920, 900);
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
            width: 920,
            height: 900,
            child: StatsPage(state: state),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('default preset shows this week labels', (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    await _pumpStats(tester, state, width: 920);

    expect(find.text('本周'), findsWidgets);
    expect(find.text('总时长'), findsOneWidget);
    expect(find.text('日均'), findsOneWidget);
    expect(find.text('每日时间 (小时)'), findsOneWidget);
    expect(find.text('事项时间'), findsOneWidget);
    expect(find.text('本周分布'), findsNothing);
    expect(find.text('范围总记录'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stats summary metrics render before mobile core charts',
      (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    await _pumpStats(tester, state, width: 920);
    await tester.pumpAndSettle();

    expect(_textTop(tester, '总时长'), lessThan(_textTop(tester, '每日时间 (小时)')));
    expect(_textTop(tester, '日均'), lessThan(_textTop(tester, '每日时间 (小时)')));
    expect(_textTop(tester, '总时长'), lessThan(_textTop(tester, '事项时间')));
    expect(_textTop(tester, '日均'), lessThan(_textTop(tester, '事项时间')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded stats layout places mobile charts side by side',
      (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    await _pumpStats(tester, state, width: 1200);
    await tester.pumpAndSettle();

    expect(
      _textTop(tester, '每日时间 (小时)'),
      lessThanOrEqualTo(_textTop(tester, '事项时间')),
    );
    expect(_textLeft(tester, '每日时间 (小时)'), lessThan(_textLeft(tester, '事项时间')));
    expect(find.text('筛选'), findsNothing);
    expect(find.text('统计维度'), findsNothing);
    expect(find.text('每日累计'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile stats matches the reference information flow',
      (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    await _pumpStats(tester, state, width: 320);

    expect(find.text('统计'), findsOneWidget);
    expect(find.text('本周'), findsOneWidget);
    expect(find.text('总时长'), findsOneWidget);
    expect(find.text('日均'), findsOneWidget);
    expect(find.text('每日时间 (小时)'), findsOneWidget);
    expect(find.text('事项时间'), findsOneWidget);
    expect(find.text('暂无数据'), findsWidgets);
    expect(
      _textTop(tester, '总时长'),
      lessThan(_textTop(tester, '每日时间 (小时)')),
    );
    expect(
      _textTop(tester, '每日时间 (小时)'),
      lessThan(_textTop(tester, '事项时间')),
    );
    expect(
        find.byKey(const ValueKey('mobile-stats-day-bar-0')), findsOneWidget);
    expect(find.byType(PieChart), findsNothing);
    expect(find.text('筛选'), findsNothing);
    expect(find.text('统计维度'), findsNothing);
    expect(find.text('每日累计'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile stats range menu switches the selected range',
      (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    await _pumpStats(tester, state, width: 320);

    await tester.tap(find.byKey(const ValueKey('mobile-stats-range-menu')));
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('昨天'), findsOneWidget);
    expect(find.text('上周'), findsOneWidget);

    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    await tester
        .runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('本周'), findsNothing);
    expect(find.text('统计维度'), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop stats hides extra filters and sort controls',
      (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    await _pumpStats(tester, state, width: 920);

    expect(find.text('统计维度'), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('每日累计'), findsNothing);
    expect(find.text('事项时间'), findsOneWidget);
    expect(find.text('排序'), findsNothing);
    expect(find.text('排序依据'), findsNothing);
    expect(find.text('顺序'), findsNothing);
    expect(find.text('倒序'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RangeDistributionCard legend count suffix is localized', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RangeDistributionCard(
            state: state,
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
    );
    await tester.pumpAndSettle();

    expect(find.text('次'), findsNothing);
    expect(find.text('1 hr 0 min · 3x'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RangeDistributionCard keeps compact legend beside chart', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));
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
              state: state,
              title: '今天分布',
              rows: const [
                StatsGroupRow(
                  id: 'work',
                  label: '工作',
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

    final chartRect = tester.getRect(find.byType(PieChart));
    final legendRect = tester.getRect(find.text('工作'));
    expect(legendRect.left, greaterThan(chartRect.right));
    expect(find.text('1小时 · 3次'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
