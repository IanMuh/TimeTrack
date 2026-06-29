import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/adaptive_layout.dart';
import 'package:timetrack/ui/ui_components.dart';
import 'package:timetrack/ui/timeline_page.dart';

void main() {
  test('adaptiveSizeClassFor maps default breakpoints', () {
    expect(adaptiveSizeClassFor(320), AdaptiveSizeClass.compact);
    expect(adaptiveSizeClassFor(600), AdaptiveSizeClass.medium);
    expect(adaptiveSizeClassFor(839), AdaptiveSizeClass.medium);
    expect(adaptiveSizeClassFor(840), AdaptiveSizeClass.expanded);
  });

  testWidgets('AdaptivePage lays out at compact and expanded widths', (
    tester,
  ) async {
    Future<void> pumpAtWidth(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 800,
              child: const AdaptivePage(
                children: [
                  Text('Header'),
                  SectionGap(),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Body'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpAtWidth(390);
    expect(find.text('Header'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpAtWidth(700);
    expect(find.text('Header'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpAtWidth(1200);
    expect(find.text('Body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared page header keeps actions visible at narrow widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: PageHeader(
              title: '统计',
              subtitle: '查看今天的时间分布。',
              trailing: StatusPill(
                label: '今天',
                icon: Icons.insights_outlined,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('统计'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TimelineHeader adapts at compact and expanded widths', (
    tester,
  ) async {
    Future<void> pumpAtWidth(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: TimelineHeader(
                selectedDay: DateTime(2026, 6, 13),
                mode: TimelineViewMode.entries,
                density: TimelineDensity.detailed,
                span: TimelineSpan.week,
                segmentsPerDay: 4,
                zoom: 1.25,
                onPreviousRange: () {},
                onNextRange: () {},
                onDateTap: () {},
                onModeChanged: (_) {},
                onDensityChanged: (_) {},
                onSpanChanged: (_) {},
                onSegmentsPerDayChanged: (_) {},
                onZoomChanged: (_) {},
                onAddEntry: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpAtWidth(390);
    expect(find.text('补记'), findsOneWidget);
    expect(find.text('视图'), findsOneWidget);
    expect(find.text('显示选项'), findsOneWidget);
    expect(find.text('单行缩放'), findsNothing);

    await tester.tap(find.text('显示选项'));
    await tester.pumpAndSettle();

    expect(find.text('详细'), findsOneWidget);
    expect(find.text('7日'), findsOneWidget);
    expect(find.text('单行缩放'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpAtWidth(920);
    expect(find.text('时间轴'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);
    expect(find.text('7日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TimelineHeader shows zoom only for record view', (
    tester,
  ) async {
    Future<void> pumpMode(TimelineViewMode mode) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: TimelineHeader(
                selectedDay: DateTime(2026, 6, 13),
                mode: mode,
                density: TimelineDensity.detailed,
                span: TimelineSpan.day,
                segmentsPerDay: 4,
                zoom: 0.25,
                onPreviousRange: () {},
                onNextRange: () {},
                onDateTap: () {},
                onModeChanged: (_) {},
                onDensityChanged: (_) {},
                onSpanChanged: (_) {},
                onSegmentsPerDayChanged: (_) {},
                onZoomChanged: (_) {},
                onAddEntry: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpMode(TimelineViewMode.entries);
    expect(find.byType(Slider), findsNothing);

    await tester.tap(find.text('显示选项'));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 0.25);
    expect(slider.max, 3);
    expect(slider.divisions, 11);
    expect(find.text('0.25x'), findsOneWidget);

    await pumpMode(TimelineViewMode.actions);
    await tester.tap(find.text('显示选项'));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsNothing);
    expect(find.text('0.25x'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
