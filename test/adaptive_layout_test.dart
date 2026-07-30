import 'package:flutter/gestures.dart';
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

  testWidgets('AdaptivePage lays out at planned QA widths', (
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

    for (final width in [390.0, 600.0, 840.0, 920.0, 1200.0]) {
      await pumpAtWidth(width);
      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('AdaptivePage scrollbar handles mouse wheel scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 920,
            height: 500,
            child: AdaptivePage(
              children: [
                for (var index = 0; index < 40; index++)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Row $index'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: const Offset(460, 250));
    await tester.pump();

    tester.binding.handlePointerEvent(
      const PointerScrollEvent(
        position: Offset(460, 250),
        scrollDelta: Offset(0, 320),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('AdaptivePage leaves bottom room for fixed shell chrome', (
    tester,
  ) async {
    Future<void> pumpAt({
      required double width,
      required double expectedGap,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 500,
              child: const AdaptivePage(
                children: [
                  Text('Header'),
                  SizedBox(height: 700),
                  Text('Footer marker'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(
        500 - tester.getBottomLeft(find.text('Footer marker')).dy,
        closeTo(expectedGap, 0.1),
      );
      expect(tester.takeException(), isNull);
    }

    await pumpAt(
      width: 390,
      expectedGap: 16 + adaptiveCompactScrollEndGap,
    );
    await pumpAt(
      width: 920,
      expectedGap: 24 + adaptiveWideScrollEndGap,
    );
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

    void expectPrimaryControlsBeforeOptions({
      required String modeLabel,
    }) {
      expect(find.text('补记'), findsOneWidget);
      expect(find.text(modeLabel), findsOneWidget);
      expect(find.text('显示选项'), findsOneWidget);
      expect(find.text('单行缩放'), findsNothing);
      final optionsTop = tester.getTopLeft(find.text('显示选项')).dy;
      expect(
        tester.getTopLeft(find.byTooltip('前一天')).dy,
        lessThan(optionsTop),
      );
      expect(
        tester.getTopLeft(find.text(modeLabel)).dy,
        lessThan(optionsTop),
      );
      expect(
        tester.getTopLeft(find.text('补记')).dy,
        lessThan(optionsTop),
      );
    }

    await pumpAtWidth(390);
    expectPrimaryControlsBeforeOptions(modeLabel: '视图');

    await tester.tap(find.text('显示选项'));
    await tester.pumpAndSettle();

    expect(find.text('详细'), findsOneWidget);
    expect(find.text('7日'), findsOneWidget);
    expect(find.text('单行缩放'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpAtWidth(600);
    expectPrimaryControlsBeforeOptions(modeLabel: '记录');

    await pumpAtWidth(840);
    expectPrimaryControlsBeforeOptions(modeLabel: '记录');

    await pumpAtWidth(920);
    expect(find.text('时间轴'), findsOneWidget);
    expectPrimaryControlsBeforeOptions(modeLabel: '记录');

    await pumpAtWidth(1200);
    expectPrimaryControlsBeforeOptions(modeLabel: '记录');

    await tester.tap(find.text('显示选项'));
    await tester.pumpAndSettle();

    expect(find.text('详细'), findsOneWidget);
    expect(find.text('7日'), findsOneWidget);
    expect(find.text('单行缩放'), findsOneWidget);
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

  testWidgets('TimelineHeader segment control uses localized strings', (
    tester,
  ) async {
    var displayMode = TimelineDisplayMode.singleLine;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 840,
            child: StatefulBuilder(
              builder: (context, setState) => TimelineHeader(
                selectedDay: DateTime(2026, 6, 13),
                mode: TimelineViewMode.entries,
                density: TimelineDensity.detailed,
                span: TimelineSpan.week,
                segmentsPerDay: 4,
                zoom: 1.25,
                displayMode: displayMode,
                onDisplayModeChanged: (value) {
                  setState(() => displayMode = value);
                },
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Display options'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Segmented day'));
    await tester.pumpAndSettle();

    expect(find.text('每天 4 段'), findsNothing);
    expect(find.text('4 segments/day'), findsOneWidget);
    expect(find.byTooltip('减少分段'), findsNothing);
    expect(find.byTooltip('Decrease segments'), findsOneWidget);
    expect(find.byTooltip('增加分段'), findsNothing);
    expect(find.byTooltip('Increase segments'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'AdaptivePage wraps content in RefreshIndicator when onRefresh is set',
      (tester) async {
    var refreshCount = 0;
    Future<void> onRefresh() async {
      refreshCount++;
    }

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 800,
            child: AdaptivePage(
              onRefresh: onRefresh,
              children: const [
                Text('Header'),
                SizedBox(height: 600),
                Text('Footer'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.drag(find.text('Header'), const Offset(0, 200));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshCount, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
