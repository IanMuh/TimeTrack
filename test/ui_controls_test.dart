import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/app_state.dart';
import 'package:timetrack/data/file_interop_service.dart';
import 'package:timetrack/data/lan_sync.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/sync_peer_store.dart';
import 'package:timetrack/data/sync_service.dart';
import 'package:timetrack/data/time_repository.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/time_entry.dart';
import 'package:timetrack/ui/home_page.dart';
import 'package:timetrack/ui/settings_page.dart';
import 'package:timetrack/ui/stats_page.dart';
import 'package:timetrack/ui/timeline_page.dart';
import 'package:timetrack/ui/ui_components.dart';

void main() {
  testWidgets('ActivityColorPicker updates preview from RGB input', (
    tester,
  ) async {
    var selectedColor = 0xff112233;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ActivityColorPicker(
                selectedColor: selectedColor,
                onColorChanged: (color) =>
                    setState(() => selectedColor = color),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('#112233'), findsOneWidget);

    await tester.tap(find.text('RGB 调色'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'R'),
      '255',
    );
    await tester.pumpAndSettle();

    expect(selectedColor, 0xffff2233);
    expect(find.text('#FF2233'), findsNWidgets(2));
  });

  testWidgets('StatsHeader renders compact and expanded range controls', (
    tester,
  ) async {
    Future<void> pumpAtWidth(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: StatsHeader(
                range: StatsRange(
                  start: DateTime(2026, 6, 15),
                  end: DateTime(2026, 6, 22),
                  label: '本周',
                ),
                selectedPreset: StatsPreset.thisWeek,
                onPresetChanged: (_) {},
                onPickCustomDay: () {},
                onPreviousDay: () {},
                onNextDay: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpAtWidth(390);
    expect(find.text('范围'), findsOneWidget);
    expect(find.text('06-15 - 06-21'), findsOneWidget);
    expect(find.text('选择日期'), findsNothing);
    expect(find.byTooltip('前一天'), findsOneWidget);
    expect(find.byTooltip('后一天'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpAtWidth(920);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('上周'), findsOneWidget);
    expect(find.text('06-15 - 06-21'), findsOneWidget);
    expect(find.byTooltip('前一天'), findsOneWidget);
    expect(find.byTooltip('后一天'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatusPill wraps long export paths on compact width', (
    tester,
  ) async {
    const longExportMessage =
        '已导出：/data/user/0/com.example.timetrack/app_flutter/'
        'timetrack-export-20260620-123456.json';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: StatusPill(
              label: longExportMessage,
              icon: Icons.info_outline,
              color: Colors.blue,
            ),
          ),
        ),
      ),
    );

    expect(find.text(longExportMessage), findsOneWidget);
    expect(
        tester.getSize(find.text(longExportMessage)).height, greaterThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsPage shows full exported path on compact width', (
    tester,
  ) async {
    const exportPath = '/data/user/0/com.example.timetrack/app_flutter/'
        'timetrack-export-20260620-123456.timetrack.json';
    final state = _FakeAppState()..interopMessage = '已导出：$exportPath';
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 1100,
            child: SettingsPage(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pathFinder = find.byWidgetPredicate(
      (widget) => widget is SelectableText && widget.data == exportPath,
    );
    expect(find.text('已导出'), findsOneWidget);
    expect(pathFinder, findsOneWidget);
    expect(tester.getSize(pathFinder).height, greaterThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RangeTimelineCard uses one shared time scale for multi-day view',
      (tester) async {
    final state = _FakeAppState();
    final activity = state.activities.first;
    final entries = [
      TimeEntry(
        id: 'entry-1',
        userId: null,
        activityId: activity.id,
        startAt: DateTime(2026, 6, 16, 9),
        endAt: DateTime(2026, 6, 16, 11),
        note: '',
        deviceId: 'test',
        updatedAt: DateTime(2026, 6, 16, 9),
        isDeleted: false,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: RangeTimelineCard(
                state: state,
                entries: entries,
                rangeStart: DateTime(2026, 6, 15),
                span: TimelineSpan.week,
                density: TimelineDensity.detailed,
                zoom: 2,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('24:00'), findsOneWidget);
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RangeTimelineCard gives compact screens a wider viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _FakeAppState();
    final activity = state.activities.first;
    final entries = [
      TimeEntry(
        id: 'entry-1',
        userId: null,
        activityId: activity.id,
        startAt: DateTime(2026, 6, 16, 9),
        endAt: DateTime(2026, 6, 16, 11),
        note: '',
        deviceId: 'test',
        updatedAt: DateTime(2026, 6, 16, 9),
        isDeleted: false,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 390,
              child: RangeTimelineCard(
                state: state,
                entries: entries,
                rangeStart: DateTime(2026, 6, 15),
                span: TimelineSpan.week,
                density: TimelineDensity.detailed,
                zoom: 2,
              ),
            ),
          ),
        ),
      ),
    );

    final horizontalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          axisDirectionToAxis(widget.axisDirection) == Axis.horizontal,
    );
    final viewportWidth = tester.getSize(horizontalScrollable).width;
    final firstLaneWidth = tester
        .getSize(find.byKey(const ValueKey('timeline-lane-06-15 Mon')))
        .width;

    expect(viewportWidth, greaterThan(340));
    expect(firstLaneWidth, 1920);
    expect(find.text('06-15 Mon'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('24:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RangeTimelineCard can scroll horizontally after zooming',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = _FakeAppState();
    final activity = state.activities.first;
    final entries = [
      TimeEntry(
        id: 'entry-1',
        userId: null,
        activityId: activity.id,
        startAt: DateTime(2026, 6, 16, 9),
        endAt: DateTime(2026, 6, 16, 11),
        note: '',
        deviceId: 'test',
        updatedAt: DateTime(2026, 6, 16, 9),
        isDeleted: false,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: RangeTimelineCard(
              state: state,
              entries: entries,
              rangeStart: DateTime(2026, 6, 15),
              span: TimelineSpan.week,
              density: TimelineDensity.detailed,
              zoom: 2,
            ),
          ),
        ),
      ),
    );

    final horizontalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          axisDirectionToAxis(widget.axisDirection) == Axis.horizontal,
    );
    final scrollableState = tester.state<ScrollableState>(horizontalScrollable);

    expect(scrollableState.position.pixels, 0);

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.down(tester.getCenter(horizontalScrollable));
    await tester.pump();
    await gesture.moveBy(const Offset(-360, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(scrollableState.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('showEntryEditor creates an unmatched typed activity',
      (tester) async {
    final state = _FakeAppState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () => showEntryEditor(context, state),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.widgetWithText(ChoiceChip, '工作'), findsOneWidget);
    expect(find.text('未安排'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('entry-activity-search-field')),
      '新事项',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, '创建事项'), findsOneWidget);
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(state.activities.any((activity) => activity.name == '新事项'), isTrue);
    expect(find.widgetWithText(AlertDialog, '补记时间段'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showActivityEditorDialog opens as a centered dialog',
      (tester) async {
    final state = _FakeAppState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () => showActivityEditorDialog(context, state),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.widgetWithText(AlertDialog, '新增事项'), findsOneWidget);
    expect(tester.getCenter(find.byType(AlertDialog)).dy, closeTo(300, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomePage hides unassigned and one-off activities from switcher',
      (tester) async {
    final state = _FakeAppState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('快捷切换'), findsOneWidget);
    expect(find.text('切换事项'), findsNothing);
    expect(find.text('未安排'), findsNothing);
    expect(find.text('一次性会议'), findsNothing);
    expect(find.byType(ActivitySwitchButton), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.byTooltip('系统事项，不能编辑'), findsNothing);
    expect(find.byTooltip('编辑事项'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomePage starts a one-off activity from a temporary tile',
      (tester) async {
    final state = _FakeAppState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '临时事项'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, '临时事项'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '名称'), '特别电话');
    await tester.tap(find.widgetWithText(FilledButton, '开始'));
    await tester.pumpAndSettle();

    expect(state.runningActivity?.name, '特别电话');
    expect(state.runningActivity?.isOneOff, isTrue);
    expect(find.text('特别电话'), findsOneWidget);
    expect(find.byType(ActivitySwitchButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one-off dialog can reuse a previous temporary activity',
      (tester) async {
    final state = _FakeAppState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '临时事项'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, '临时事项'), findsOneWidget);
    expect(find.text('一次性会议'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, '名称'), '会议');
    await tester.pumpAndSettle();
    expect(find.text('一次性会议'), findsOneWidget);
    expect(find.text('单次'), findsOneWidget);

    await tester.tap(find.text('一次性会议'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '开始'));
    await tester.pumpAndSettle();

    expect(state.runningActivity?.id, 'one-off-existing');
    expect(state.runningActivity?.name, '一次性会议');
    expect(state.runningActivity?.isOneOff, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'SettingsPage keeps sync and LAN controls usable on compact width',
      (tester) async {
    final state = _FakeAppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 1200,
            child: SettingsPage(state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('提醒'), findsOneWidget);
    expect(find.text('时间线'), findsOneWidget);
    expect(find.text('合并阈值'), findsOneWidget);
    expect(find.text('云同步'), findsOneWidget);
    expect(find.text('设备互通'), findsOneWidget);
    expect(find.text('配对并同步'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showEntryEditor keeps search selection after editing activity',
      (tester) async {
    final state = _FakeAppState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () => showEntryEditor(context, state),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('编辑当前事项'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(find.widgetWithText(TextField, '名称'), '深度工作');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '保存').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(find.text('深度工作'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAppState extends AppState {
  _FakeAppState()
      : super(
          repository: _repository,
          syncService: SyncService(repository: _repository, client: null),
          lanSyncServer: LanSyncServer(
            repository: _repository,
            peerStore: _peerStore,
            portCandidates: const [0],
          ),
          lanSyncClient: LanSyncClient(
            repository: _repository,
            peerStore: _peerStore,
            timeout: const Duration(milliseconds: 50),
          ),
          fileInteropService: FileInteropService(repository: _repository),
        ) {
    now = DateTime(2026, 6, 16, 12);
    selectedDay = DateTime(2026, 6, 16);
    activities = [
      Activity(
        id: 'activity-1',
        userId: null,
        name: '工作',
        color: 0xff2563eb,
        isFavorite: true,
        updatedAt: now,
        isDeleted: false,
      ),
      Activity(
        id: 'unassigned',
        userId: null,
        name: '未安排',
        color: 0xff64748b,
        isFavorite: false,
        updatedAt: now,
        isDeleted: false,
        isUnassigned: true,
      ),
      Activity(
        id: 'one-off-existing',
        userId: null,
        name: '一次性会议',
        color: 0xffdb2777,
        isFavorite: false,
        updatedAt: now,
        isDeleted: false,
        isOneOff: true,
      ),
    ];
  }

  static final LocalDatabase _database = LocalDatabase();
  static final TimeRepository _repository = TimeRepository(database: _database);
  static final SyncPeerStore _peerStore = SyncPeerStore(database: _database);

  int _nextActivityId = 2;

  @override
  Future<List<Activity>> entryActivityChoices() async {
    return [
      for (final activity in activities)
        if (!activity.isUnassigned && !activity.isOneOff) activity,
    ];
  }

  @override
  Future<Activity> createActivity(String name, int color) async {
    final activity = Activity(
      id: 'activity-${_nextActivityId++}',
      userId: null,
      name: name,
      color: color,
      isFavorite: true,
      updatedAt: now,
      isDeleted: false,
    );
    activities = [...activities, activity];
    notifyListeners();
    return activity;
  }

  @override
  Future<List<Activity>> oneOffActivitySuggestions() async {
    return [
      for (final activity in activities)
        if (activity.isOneOff) activity,
    ];
  }

  @override
  Future<T> runUndoBatch<T>(
    Future<T> Function() action, {
    String? label,
  }) {
    return action();
  }

  @override
  Future<Activity> createEntryActivity(
    String name,
    int color, {
    required bool isOneOff,
    Activity? reuseActivity,
  }) async {
    final activity = reuseActivity ??
        Activity(
          id: isOneOff
              ? 'one-off-${_nextActivityId++}'
              : 'activity-${_nextActivityId++}',
          userId: null,
          name: name,
          color: color,
          isFavorite: !isOneOff,
          updatedAt: now,
          isDeleted: false,
          isOneOff: isOneOff,
        );
    activities = [
      for (final item in activities)
        if (item.id != activity.id) item,
      activity,
    ];
    notifyListeners();
    return activity;
  }

  @override
  Future<Activity> createOneOffActivity(
    String name,
    int color, {
    Activity? reuseActivity,
  }) async {
    final activity = reuseActivity ??
        Activity(
          id: 'one-off-${_nextActivityId++}',
          userId: null,
          name: name,
          color: color,
          isFavorite: false,
          updatedAt: now,
          isDeleted: false,
          isOneOff: true,
        );
    if (reuseActivity == null) {
      activities = [...activities, activity];
    }
    runningEntry = TimeEntry(
      id: 'entry-${activity.id}',
      userId: null,
      activityId: activity.id,
      activityNameSnapshot: activity.name,
      activityColorSnapshot: activity.color,
      startAt: now,
      endAt: null,
      note: '',
      deviceId: 'test-device',
      updatedAt: now,
      isDeleted: false,
    );
    notifyListeners();
    return activity;
  }

  @override
  Future<Activity> updateActivity(
    Activity activity, {
    required String name,
    required int color,
  }) async {
    final updated = activity.copyWith(name: name, color: color, updatedAt: now);
    activities = [
      for (final item in activities)
        if (item.id == updated.id) updated else item,
    ];
    notifyListeners();
    return updated;
  }

  @override
  Future<List<TimeEntry>> overlaps(TimeEntry entry) async {
    return const [];
  }

  @override
  Future<void> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
  }) async {
    final activity = activityById(activityId);
    dayEntries = [
      TimeEntry(
        id: 'manual-${_nextActivityId++}',
        userId: null,
        activityId: activityId,
        activityNameSnapshot: activity?.name ?? '',
        activityColorSnapshot: activity?.color,
        startAt: startAt,
        endAt: endAt,
        note: note,
        deviceId: 'test-device',
        updatedAt: now,
        isDeleted: false,
      ),
    ];
    notifyListeners();
  }
}
