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
}

Future<void> _disposeStatsFixture(
  WidgetTester tester,
  TestAppFixture fixture,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(fixture.dispose);
}

void main() {
  testWidgets('stats page shows all five range preset options', (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    await _pumpStats(tester, state, width: 920);

    expect(find.text('今天'), findsWidgets);
    expect(find.text('昨天'), findsOneWidget);
    expect(find.text('本周'), findsOneWidget);
    expect(find.text('上周'), findsOneWidget);
    expect(find.text('自选日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('default preset shows today labels', (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    await _pumpStats(tester, state, width: 920);

    expect(find.text('今天分布'), findsOneWidget);
    expect(find.text('范围总记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stats page keeps quiet metric and empty states on compact width',
      (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    await _pumpStats(tester, state, width: 390);

    expect(find.text('统计'), findsOneWidget);
    expect(find.text('暂无数据'), findsWidgets);
    expect(find.text('筛选'), findsOneWidget);
    expect(find.text('统计维度'), findsNothing);
    expect(find.text('每日累计'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact stats filters expand and toggle category chips',
      (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    await _pumpStats(tester, state, width: 390);

    await tester.ensureVisible(find.text('筛选'));
    await tester.tap(find.text('筛选'));
    await tester.pumpAndSettle();

    expect(find.text('统计维度'), findsWidgets);
    expect(find.byType(FilterChip), findsOneWidget);
    expect(
        tester.widget<FilterChip>(find.byType(FilterChip)).selected, isFalse);

    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilterChip>(find.byType(FilterChip)).selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stats page exposes dimension filters without sort controls',
      (tester) async {
    final fixture = (await tester.runAsync(_buildFixture))!;
    final state = fixture.state;
    addTearDown(() => _disposeStatsFixture(tester, fixture));

    await _pumpStats(tester, state, width: 920);

    expect(find.text('统计维度'), findsOneWidget);
    expect(find.text('事项'), findsWidgets);
    expect(find.text('主分类'), findsOneWidget);
    expect(find.text('单条时长'), findsOneWidget);
    expect(find.text('分类+时长'), findsOneWidget);
    expect(find.text('排序'), findsNothing);
    expect(find.text('排序依据'), findsNothing);
    expect(find.text('顺序'), findsNothing);
    expect(find.text('倒序'), findsNothing);
    expect(find.text('工作'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
