import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timetrack/app/app_state.dart';
import 'package:timetrack/core/date_time_ext.dart';
import 'package:timetrack/data/file_interop_service.dart';
import 'package:timetrack/data/lan_sync.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/sync_peer_store.dart';
import 'package:timetrack/data/sync_service.dart';
import 'package:timetrack/data/time_repository.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/time_entry.dart';
import 'package:timetrack/ui/timeline_page.dart';

class _TimelineFixture {
  const _TimelineFixture({
    required this.state,
    required this.repository,
    this.database,
  });

  final AppState state;
  final TimeRepository repository;
  final Database? database;
}

class _DelayedOverlapAppState extends AppState {
  _DelayedOverlapAppState({
    required super.repository,
    required super.syncService,
    required super.lanSyncServer,
    required super.lanSyncClient,
    required super.fileInteropService,
  });

  final overlapCompleter = Completer<List<TimeEntry>>();
  bool overlapRequested = false;

  @override
  Future<List<TimeEntry>> overlaps(TimeEntry entry) {
    overlapRequested = true;
    return overlapCompleter.future;
  }
}

AppState _createAppState({
  required LocalDatabase database,
  required TimeRepository repository,
  bool delayOverlaps = false,
}) {
  final peerStore = SyncPeerStore(database: database);
  final syncService = SyncService(repository: repository, client: null);
  final lanSyncServer = LanSyncServer(
    repository: repository,
    peerStore: peerStore,
    portCandidates: const [0],
  );
  final lanSyncClient = LanSyncClient(
    repository: repository,
    peerStore: peerStore,
  );
  final fileInteropService = FileInteropService(repository: repository);
  if (delayOverlaps) {
    return _DelayedOverlapAppState(
      repository: repository,
      syncService: syncService,
      lanSyncServer: lanSyncServer,
      lanSyncClient: lanSyncClient,
      fileInteropService: fileInteropService,
    );
  }
  return AppState(
    repository: repository,
    syncService: syncService,
    lanSyncServer: lanSyncServer,
    lanSyncClient: lanSyncClient,
    fileInteropService: fileInteropService,
  );
}

_TimelineFixture _buildFixture() {
  final database = LocalDatabase();
  final repository = TimeRepository(database: database);
  final state = _createAppState(database: database, repository: repository);
  state
    ..isLoading = false
    ..activities = [_activity, _unassignedActivity]
    ..selectedDay = DateTime(2026, 1, 2)
    ..now = DateTime(2026, 1, 2, 12);
  return _TimelineFixture(state: state, repository: repository);
}

Future<_TimelineFixture> _buildPersistedFixture({
  bool delayOverlaps = false,
}) async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await LocalDatabase.createSchema(db);
  final database = LocalDatabase(database: db);
  final repository = TimeRepository(database: database);
  await repository.ensureSeedData();
  final state = _createAppState(
    database: database,
    repository: repository,
    delayOverlaps: delayOverlaps,
  );
  state
    ..isLoading = false
    ..selectedDay = DateTime(2026, 1, 2)
    ..now = DateTime(2026, 1, 2, 12);
  final activity = (await repository.activities())
      .firstWhere((activity) => !activity.isUnassigned);
  await repository.createManualEntry(
    activityId: activity.id,
    startAt: DateTime(2026, 1, 2, 9),
    endAt: DateTime(2026, 1, 2, 10),
    note: '',
  );
  await state.refresh();
  return _TimelineFixture(
    state: state,
    repository: repository,
    database: db,
  );
}

Future<_TimelineFixture> _buildOverlappingPersistedFixture() async {
  final fixture = await _buildPersistedFixture();
  final activity = (await fixture.repository.activities())
      .firstWhere((activity) => !activity.isUnassigned);
  await fixture.database!.insert('time_entries', {
    'id': 'legacy-overlap',
    'user_id': null,
    'activity_id': activity.id,
    'start_at': DateTime(2026, 1, 2, 9, 30).toIso8601String(),
    'end_at': DateTime(2026, 1, 2, 10, 30).toIso8601String(),
    'note': '',
    'device_id': 'test-device',
    'updated_at': DateTime(2026, 1, 2, 9, 30).toIso8601String(),
    'is_deleted': 0,
  });
  await fixture.state.refresh();
  return fixture;
}

final _activity = Activity(
  id: 'work',
  userId: null,
  name: '工作',
  color: 0xff2563eb,
  isFavorite: true,
  updatedAt: DateTime(2026, 1, 1),
  isDeleted: false,
);

final _unassignedActivity = Activity(
  id: 'unassigned',
  userId: null,
  name: '未安排',
  color: 0xff64748b,
  isFavorite: false,
  updatedAt: DateTime(2026, 1, 1),
  isDeleted: false,
  isUnassigned: true,
);

TimeEntry _entry({
  required String id,
  required DateTime startAt,
  required DateTime? endAt,
  String note = '',
}) {
  return TimeEntry(
    id: id,
    userId: null,
    activityId: _activity.id,
    startAt: startAt,
    endAt: endAt,
    note: note,
    deviceId: 'test-device',
    updatedAt: DateTime(2026, 1, 2, 12),
    isDeleted: false,
  );
}

Future<void> _pumpTimeline(
  WidgetTester tester,
  AppState state, {
  required double width,
  bool defaultToTodayOnOpen = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 900,
          child: TimelinePage(
            state: state,
            defaultToTodayOnOpen: defaultToTodayOnOpen,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _tapAndPumpUntil(
  WidgetTester tester,
  Finder finder,
  Finder doneFinder,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(finder);
  });
  await tester.pumpAndSettle();
  for (var attempt = 0; attempt < 40; attempt += 1) {
    if (doneFinder.evaluate().isNotEmpty) {
      break;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(doneFinder, findsWidgets);
}

Future<void> _tapAndPumpUntilGone(
  WidgetTester tester,
  Finder finder,
  Finder goneFinder,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(finder);
  });
  await tester.pumpAndSettle();
  for (var attempt = 0; attempt < 40; attempt += 1) {
    if (goneFinder.evaluate().isEmpty) {
      break;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(goneFinder, findsNothing);
}

Future<void> _tapEntryEditButton(
  WidgetTester tester, {
  required String title,
}) async {
  final entryCard = find.ancestor(
    of: find.text(title),
    matching: find.byType(TimelineEntryCard),
  );
  await _tapEntryEditButtonInCard(tester, entryCard);
}

Future<void> _tapEntryEditButtonInCard(
  WidgetTester tester,
  Finder entryCard,
) async {
  expect(entryCard, findsOneWidget);
  await tester.ensureVisible(entryCard);
  await tester.pumpAndSettle();
  final editButton = find.descendant(
    of: entryCard,
    matching: find.byTooltip('编辑'),
  );
  expect(editButton, findsOneWidget);
  await tester.tap(
    editButton,
  );
  await tester.pumpAndSettle();
}

Future<void> _chooseEntryActivity(
  WidgetTester tester,
  String activityName,
) async {
  await tester.enterText(
    find.byKey(const ValueKey('entry-activity-search-field')),
    activityName,
  );
  await tester.pumpAndSettle();
  final chip = find.ancestor(
    of: find.text(activityName).last,
    matching: find.byType(ChoiceChip),
  );
  await tester.tap(chip.last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('timeline defaults to today and shows timeline with list', (
    tester,
  ) async {
    final fixture = _buildFixture();
    final state = fixture.state;
    addTearDown(state.dispose);
    final today = DateTime.now().startOfDay;
    state
      ..selectedDay = DateTime(2026, 1, 2)
      ..now = today.add(const Duration(hours: 12))
      ..dayEntries = [
        _entry(
          id: 'today-entry',
          startAt: today.add(const Duration(hours: 9)),
          endAt: today.add(const Duration(hours: 10)),
        ),
      ];

    await _pumpTimeline(
      tester,
      state,
      width: 920,
      defaultToTodayOnOpen: true,
    );

    expect(state.selectedDay.isSameDate(today), isTrue);
    expect(find.text('可缩放时间线'), findsOneWidget);
    expect(find.byType(TimelineEntryCard), findsWidgets);
    expect(find.text('记录列表'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline appears above the entry list at common widths', (
    tester,
  ) async {
    final fixture = _buildFixture();
    final state = fixture.state;
    addTearDown(state.dispose);
    state.dayEntries = [
      _entry(
        id: 'entry',
        startAt: DateTime(2026, 1, 2, 9),
        endAt: DateTime(2026, 1, 2, 10),
      ),
    ];

    for (final width in [390.0, 920.0]) {
      await _pumpTimeline(tester, state, width: width);

      expect(
        tester.getTopLeft(find.text('可缩放时间线')).dy,
        lessThan(tester.getTopLeft(find.text('记录列表')).dy),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('actions view hides timeline zoom controls', (tester) async {
    final fixture = _buildFixture();
    final state = fixture.state;
    addTearDown(state.dispose);

    await _pumpTimeline(tester, state, width: 920);
    await tester.tap(find.text('指令'));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsNothing);
    expect(find.text('可缩放时间线'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cross-day entries render the selected-day interval', (
    tester,
  ) async {
    final fixture = _buildFixture();
    final state = fixture.state;
    addTearDown(state.dispose);

    state.dayEntries = [
      _entry(
        id: 'cross-day',
        startAt: DateTime(2026, 1, 1, 23, 30),
        endAt: DateTime(2026, 1, 2, 0, 30),
        note: 'cross day',
      ),
    ];
    state.now = DateTime(2026, 1, 2, 12);

    await _pumpTimeline(tester, state, width: 390);

    expect(find.text('30 分钟'), findsOneWidget);
    expect(find.text('00:00:00 - 00:30:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('running entry editor can keep the entry running', (
    tester,
  ) async {
    final fixture = _buildFixture();
    final state = fixture.state;
    addTearDown(state.dispose);
    final runningEntry = _entry(
      id: 'running',
      startAt: DateTime(2026, 1, 2, 9),
      endAt: null,
      note: 'cross day',
    );
    state
      ..dayEntries = [runningEntry]
      ..runningEntry = runningEntry
      ..now = DateTime(2026, 1, 2, 10, 15);

    await _pumpTimeline(tester, state, width: 920);
    final runningCard = find.ancestor(
      of: find.text('工作'),
      matching: find.byType(TimelineEntryCard),
    );
    await _tapEntryEditButtonInCard(tester, runningCard);

    expect(find.text('保持进行中'), findsWidgets);
    expect(find.text('关闭后可把这条记录保存为已结束。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline list shows unassigned gaps as activity entries', (
    tester,
  ) async {
    final fixture = _buildFixture();
    final state = fixture.state;
    addTearDown(state.dispose);
    state
      ..selectedDay = DateTime(2026, 1, 1)
      ..now = DateTime(2026, 1, 2, 12);

    await _pumpTimeline(tester, state, width: 390);

    expect(
      find.ancestor(
        of: find.text('未安排'),
        matching: find.byType(TimelineEntryCard),
      ),
      findsOneWidget,
    );
    expect(find.text('24 小时 0 分钟'), findsOneWidget);
    expect(find.text('00:00:00 - 24:00:00'), findsOneWidget);
    expect(find.text('这一天还没有记录。'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline editor saves an unassigned gap as a real activity', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_buildPersistedFixture))!;
    final state = fixture.state;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());

    await tester.runAsync(
      () => fixture.repository.deleteEntry(state.dayEntries.single),
    );
    await tester.runAsync(state.refresh);
    final gap = state.visibleDayEntries().singleWhere(
          (entry) => entry.deviceId == 'unassigned-gap',
        );

    await _pumpTimeline(tester, state, width: 390);
    final gapCard = find.ancestor(
      of: find.text('未安排'),
      matching: find.byType(TimelineEntryCard),
    );
    expect(gapCard, findsOneWidget);

    await _tapEntryEditButtonInCard(tester, gapCard);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('entry-activity-search-field')),
          )
          .controller
          ?.text,
      '',
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == '编辑当前事项',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(find.widgetWithText(ChoiceChip, '工作'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '未安排'), findsNothing);
    await _tapAndPumpUntil(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.text('请选择一个有效事项。'),
    );

    final entriesBeforeSelection =
        await tester.runAsync(fixture.repository.allEntries);
    final logsBeforeSelection =
        await tester.runAsync(fixture.repository.allActionLogs);
    expect(
        entriesBeforeSelection!.where((entry) => entry.id == gap.id), isEmpty);
    expect(
      entriesBeforeSelection.where(
        (entry) =>
            entry.deviceId == 'unassigned-gap' ||
            (!entry.isDeleted &&
                entry.activityId == state.unassignedActivity!.id),
      ),
      isEmpty,
    );
    expect(logsBeforeSelection!.where((log) => log.entryId == gap.id), isEmpty);

    await _chooseEntryActivity(tester, '工作');
    await _tapAndPumpUntilGone(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.widgetWithText(AlertDialog, '编辑时间段'),
    );

    expect(tester.takeException(), isNull);
    expect(
      state.dayEntries.where((entry) => entry.deviceId != 'unassigned-gap'),
      hasLength(1),
    );
    expect(state.dayEntries.single.activityId,
        isNot(state.unassignedActivity!.id));
    final allEntries = await tester.runAsync(fixture.repository.allEntries);
    final allLogs = await tester.runAsync(fixture.repository.allActionLogs);
    final realEntries = allEntries!
        .where(
            (entry) => !entry.isDeleted && entry.deviceId != 'unassigned-gap')
        .toList();
    expect(realEntries, hasLength(1));
    expect(realEntries.single.id, isNot(gap.id));
    expect(realEntries.single.activityId, isNot(state.unassignedActivity!.id));
    expect(allEntries.where((entry) => entry.id == gap.id), isEmpty);
    expect(allEntries.where((entry) => entry.deviceId == 'unassigned-gap'),
        isEmpty);
    expect(allLogs!.where((log) => log.entryId == gap.id), isEmpty);
    expect(
      allLogs.where(
        (log) =>
            log.actionType == 'manual' && log.entryId == realEntries.single.id,
      ),
      hasLength(1),
    );
  });

  testWidgets('timeline editor cannot delete a generated unassigned gap', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_buildPersistedFixture))!;
    final state = fixture.state;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());

    await tester.runAsync(
      () => fixture.repository.deleteEntry(state.dayEntries.single),
    );
    await tester.runAsync(state.refresh);
    final gap = state.visibleDayEntries().singleWhere(
          (entry) => entry.deviceId == 'unassigned-gap',
        );

    await _pumpTimeline(tester, state, width: 390);
    final gapCard = find.ancestor(
      of: find.text('未安排'),
      matching: find.byType(TimelineEntryCard),
    );
    await _tapEntryEditButtonInCard(tester, gapCard);

    expect(find.widgetWithText(AlertDialog, '编辑时间段'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '删除'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    final allEntries = await tester.runAsync(fixture.repository.allEntries);
    final allLogs = await tester.runAsync(fixture.repository.allActionLogs);
    expect(
      allEntries!.where((entry) => entry.id == gap.id),
      isEmpty,
    );
    expect(
      allLogs!.where((log) => log.entryId == gap.id),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline editor updates an existing entry activity', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_buildPersistedFixture))!;
    final state = fixture.state;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());
    final originalEntry = state.dayEntries.single;
    final targetActivity = state.activities.firstWhere(
      (activity) =>
          !activity.isUnassigned && activity.id != originalEntry.activityId,
    );

    await _pumpTimeline(tester, state, width: 920);
    final originalActivity = state.activityById(originalEntry.activityId)!;
    final entryCard = find.ancestor(
      of: find.text(originalActivity.name),
      matching: find.byType(TimelineEntryCard),
    );
    await _tapEntryEditButtonInCard(tester, entryCard);
    await _chooseEntryActivity(tester, targetActivity.name);
    await _tapAndPumpUntilGone(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.widgetWithText(AlertDialog, '编辑时间段'),
    );

    final storedEntries = await tester.runAsync(
      () => fixture.repository.entriesForDay(state.selectedDay),
    );
    expect(tester.takeException(), isNull);
    final realDayEntries = state.dayEntries
        .where((entry) => entry.deviceId != 'unassigned-gap')
        .toList();
    expect(realDayEntries, hasLength(1));
    expect(realDayEntries.single.activityId, targetActivity.id);
    expect(storedEntries!.single.activityId, targetActivity.id);
  });

  testWidgets('timeline editor splits an entry at the midpoint', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_buildPersistedFixture))!;
    final state = fixture.state;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());
    final originalEntry = state.dayEntries.single;

    await _pumpTimeline(tester, state, width: 920);
    final activity = state.activityById(originalEntry.activityId)!;
    await _tapEntryEditButton(tester, title: activity.name);
    await _tapAndPumpUntil(
      tester,
      find.widgetWithText(OutlinedButton, '切割'),
      find.widgetWithText(AlertDialog, '切割时间段'),
    );
    await _tapAndPumpUntilGone(
      tester,
      find.widgetWithText(FilledButton, '切割'),
      find.widgetWithText(AlertDialog, '编辑时间段'),
    );

    final entries = await tester.runAsync(
      () => fixture.repository.entriesForDay(state.selectedDay),
    );
    expect(tester.takeException(), isNull);
    expect(entries, hasLength(2));
    expect(entries![0].id, originalEntry.id);
    expect(entries[0].startAt, DateTime(2026, 1, 2, 9));
    expect(entries[0].endAt, DateTime(2026, 1, 2, 9, 30));
    expect(entries[1].startAt, DateTime(2026, 1, 2, 9, 30));
    expect(entries[1].endAt, DateTime(2026, 1, 2, 10));
  });

  testWidgets(
      'timeline editor extends an entry to now and removes covered rows', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_buildPersistedFixture))!;
    final state = fixture.state;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());
    final originalEntry = state.dayEntries.single;
    late TimeEntry coveredEntry;
    await tester.runAsync(() async {
      final activity = (await fixture.repository.activities())
          .firstWhere((activity) => !activity.isUnassigned);
      coveredEntry = await fixture.repository.createManualEntry(
        activityId: activity.id,
        startAt: DateTime(2026, 1, 2, 10),
        endAt: DateTime(2026, 1, 2, 11),
        note: '',
      );
      await state.refresh();
    });

    await _pumpTimeline(tester, state, width: 920);
    final entryCard = find.ancestor(
      of: find.text('09:00:00 - 10:00:00'),
      matching: find.byType(TimelineEntryCard),
    );
    await _tapEntryEditButtonInCard(tester, entryCard);
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '延续到现在'));
    await tester.pumpAndSettle();
    await _tapAndPumpUntilGone(
      tester,
      find.widgetWithText(OutlinedButton, '延续到现在'),
      find.widgetWithText(AlertDialog, '编辑时间段'),
    );

    final entries = await tester.runAsync(
      () => fixture.repository.entriesForDay(state.selectedDay),
    );
    final runningEntry = await tester.runAsync(fixture.repository.runningEntry);
    final allEntries = await tester.runAsync(fixture.repository.allEntries);
    final covered =
        allEntries!.singleWhere((entry) => entry.id == coveredEntry.id);
    expect(tester.takeException(), isNull);
    expect(entries, hasLength(1));
    expect(entries!.single.id, originalEntry.id);
    expect(entries.single.startAt, DateTime(2026, 1, 2, 9));
    expect(entries.single.endAt, isNull);
    expect(runningEntry?.id, originalEntry.id);
    expect(runningEntry?.endAt, isNull);
    expect(covered.isDeleted, isTrue);
  });

  testWidgets('timeline editor can choose a previous one-off activity', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_buildPersistedFixture))!;
    final state = fixture.state;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());
    final originalEntry = state.dayEntries.single;
    late Activity oneOff;
    await tester.runAsync(() async {
      oneOff = await fixture.repository.createActivity(
        name: '临时电话',
        color: 0xffdb2777,
        isOneOff: true,
      );
      await fixture.repository.replaceActivityIfRemoteNewer(
        oneOff.copyWith(
          isDeleted: true,
          updatedAt: DateTime.now().add(const Duration(seconds: 1)),
        ),
      );
      await state.refresh();
    });

    await _pumpTimeline(tester, state, width: 920);
    final activity = state.activityById(originalEntry.activityId)!;
    await _tapEntryEditButton(tester, title: activity.name);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
    expect(find.text('临时电话'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('entry-activity-search-field')),
      '临时',
    );
    await tester.pumpAndSettle();
    expect(find.text('临时电话'), findsOneWidget);
    expect(find.text('单次'), findsOneWidget);
    await _chooseEntryActivity(tester, '临时电话');
    await _tapAndPumpUntilGone(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.widgetWithText(AlertDialog, '编辑时间段'),
    );

    final entries = await tester.runAsync(
      () => fixture.repository.entriesForDay(state.selectedDay),
    );
    expect(tester.takeException(), isNull);
    expect(entries!.single.activityId, oneOff.id);
    expect(entries.single.activityNameSnapshot, '临时电话');
  });

  testWidgets(
      'timeline editor shows deleted activity snapshot until user selects',
      (tester) async {
    final fixture = (await tester.runAsync(_buildPersistedFixture))!;
    final state = fixture.state;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());
    final originalEntry = state.dayEntries.single;
    final originalActivity = state.activityById(originalEntry.activityId)!;
    final targetActivity = state.activities.firstWhere(
      (activity) =>
          !activity.isUnassigned && activity.id != originalEntry.activityId,
    );

    await tester.runAsync(() async {
      await fixture.repository.replaceActivityIfRemoteNewer(
        originalActivity.copyWith(
          isDeleted: true,
          updatedAt: DateTime.now().add(const Duration(seconds: 1)),
        ),
      );
      await state.refresh();
    });

    await _pumpTimeline(tester, state, width: 920);
    final entryCard = find.ancestor(
      of: find.text(originalActivity.name),
      matching: find.byType(TimelineEntryCard),
    );
    await _tapEntryEditButtonInCard(tester, entryCard);

    await _tapAndPumpUntil(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.text('请选择一个有效事项。'),
    );

    var storedEntries = await tester.runAsync(
      () => fixture.repository.entriesForDay(state.selectedDay),
    );
    expect(find.text('请选择一个有效事项。'), findsOneWidget);
    expect(storedEntries!.single.activityId, originalEntry.activityId);

    await _chooseEntryActivity(tester, targetActivity.name);
    await _tapAndPumpUntilGone(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.widgetWithText(AlertDialog, '编辑时间段'),
    );

    storedEntries = await tester.runAsync(
      () => fixture.repository.entriesForDay(state.selectedDay),
    );
    expect(tester.takeException(), isNull);
    expect(storedEntries!.single.activityId, targetActivity.id);
  });

  testWidgets('timeline editor saves an activity change after overlap warning',
      (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_buildOverlappingPersistedFixture))!;
    final state = fixture.state;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());
    final entryToEdit = state.dayEntries.first;
    final targetActivity = state.activities.firstWhere(
      (activity) =>
          !activity.isUnassigned && activity.id != entryToEdit.activityId,
    );

    await _pumpTimeline(tester, state, width: 920);
    final entryCard = find.ancestor(
      of: find.text('09:00:00 - 10:00:00'),
      matching: find.byType(TimelineEntryCard),
    );
    await _tapEntryEditButtonInCard(tester, entryCard);
    await _chooseEntryActivity(tester, targetActivity.name);
    await _tapAndPumpUntil(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.textContaining('重叠'),
    );

    expect(find.textContaining('重叠'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tapAndPumpUntilGone(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.widgetWithText(AlertDialog, '编辑时间段'),
    );

    final storedEntries = await tester.runAsync(
      () => fixture.repository.entriesForDay(state.selectedDay),
    );
    final editedEntry = storedEntries!.singleWhere(
      (entry) => entry.id == entryToEdit.id,
    );
    expect(tester.takeException(), isNull);
    expect(editedEntry.activityId, targetActivity.id);
  });

  testWidgets('timeline editor merges a short right neighbor directly',
      (tester) async {
    final fixture = (await tester.runAsync(_buildPersistedFixture))!;
    final state = fixture.state;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());
    final activity = state.activities.firstWhere(
      (activity) => !activity.isUnassigned,
    );
    await tester.runAsync(() async {
      await fixture.repository.createManualEntry(
        activityId: activity.id,
        startAt: DateTime(2026, 1, 2, 10),
        endAt: DateTime(2026, 1, 2, 10, 1),
        note: '',
      );
      await state.refresh();
    });

    await _pumpTimeline(tester, state, width: 920);
    final entryCard = find.ancestor(
      of: find.text('09:00:00 - 10:00:00'),
      matching: find.byType(TimelineEntryCard),
    );
    await _tapEntryEditButtonInCard(tester, entryCard);
    await _tapAndPumpUntilGone(
      tester,
      find.widgetWithText(OutlinedButton, '合并右侧'),
      find.widgetWithText(AlertDialog, '编辑时间段'),
    );

    final entries = await tester.runAsync(
      () => fixture.repository.entriesForDay(state.selectedDay),
    );
    expect(entries, hasLength(1));
    expect(entries!.single.startAt, DateTime(2026, 1, 2, 9));
    expect(entries.single.endAt, DateTime(2026, 1, 2, 10, 1));
  });

  testWidgets('timeline editor confirms before merging a longer neighbor',
      (tester) async {
    final fixture = (await tester.runAsync(_buildPersistedFixture))!;
    final state = fixture.state;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());
    final activity = state.activities.firstWhere(
      (activity) => !activity.isUnassigned,
    );
    await tester.runAsync(() async {
      await fixture.repository.createManualEntry(
        activityId: activity.id,
        startAt: DateTime(2026, 1, 2, 10),
        endAt: DateTime(2026, 1, 2, 10, 2),
        note: '',
      );
      await state.refresh();
    });

    await _pumpTimeline(tester, state, width: 920);
    final entryCard = find.ancestor(
      of: find.text('09:00:00 - 10:00:00'),
      matching: find.byType(TimelineEntryCard),
    );
    await _tapEntryEditButtonInCard(tester, entryCard);
    await _tapAndPumpUntil(
      tester,
      find.widgetWithText(OutlinedButton, '合并右侧'),
      find.widgetWithText(AlertDialog, '合并右侧记录'),
    );
    await _tapAndPumpUntilGone(
      tester,
      find.widgetWithText(FilledButton, '合并'),
      find.widgetWithText(AlertDialog, '编辑时间段'),
    );

    final entries = await tester.runAsync(
      () => fixture.repository.entriesForDay(state.selectedDay),
    );
    expect(entries, hasLength(1));
    expect(entries!.single.endAt, DateTime(2026, 1, 2, 10, 2));
  });

  testWidgets('timeline editor asks again when overlap candidate changes', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_buildOverlappingPersistedFixture))!;
    final state = fixture.state;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());
    final entryToEdit = state.dayEntries.first;
    final targetActivities = state.activities
        .where(
          (activity) =>
              !activity.isUnassigned && activity.id != entryToEdit.activityId,
        )
        .toList();
    final firstTargetActivity = targetActivities.first;
    final secondTargetActivity = targetActivities[1];

    await _pumpTimeline(tester, state, width: 920);
    final entryCard = find.ancestor(
      of: find.text('09:00:00 - 10:00:00'),
      matching: find.byType(TimelineEntryCard),
    );
    await _tapEntryEditButtonInCard(tester, entryCard);
    await _chooseEntryActivity(tester, firstTargetActivity.name);
    await _tapAndPumpUntil(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.textContaining('重叠'),
    );

    expect(find.textContaining('重叠'), findsOneWidget);

    await _chooseEntryActivity(tester, secondTargetActivity.name);
    expect(find.textContaining('重叠'), findsNothing);

    await _tapAndPumpUntil(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.textContaining('重叠'),
    );

    final storedEntries = await tester.runAsync(
      () => fixture.repository.entriesForDay(state.selectedDay),
    );
    final editedEntry = storedEntries!.singleWhere(
      (entry) => entry.id == entryToEdit.id,
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('重叠'), findsOneWidget);
    expect(find.widgetWithText(AlertDialog, '编辑时间段'), findsOneWidget);
    expect(editedEntry.activityId, isNot(secondTargetActivity.id));
  });

  testWidgets('timeline editor validates activity after refresh while open', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_buildPersistedFixture))!;
    final state = fixture.state;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());
    final originalEntry = state.dayEntries.single;
    final deletedActivityId = originalEntry.activityId;
    final targetActivity = state.activities.firstWhere(
      (activity) =>
          !activity.isUnassigned && activity.id != originalEntry.activityId,
    );

    await _pumpTimeline(tester, state, width: 920);
    final originalActivity = state.activityById(originalEntry.activityId)!;
    final entryCard = find.ancestor(
      of: find.text(originalActivity.name),
      matching: find.byType(TimelineEntryCard),
    );
    await _tapEntryEditButtonInCard(tester, entryCard);

    await tester.runAsync(() async {
      await fixture.repository.replaceActivityIfRemoteNewer(
        originalActivity.copyWith(
          isDeleted: true,
          updatedAt: DateTime.now().add(const Duration(seconds: 1)),
        ),
      );
      await state.refresh();
    });

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(AlertDialog, '编辑时间段'), findsOneWidget);
    expect(state.activityById(deletedActivityId), isNull);

    await _tapAndPumpUntil(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.text('请选择一个有效事项。'),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('请选择一个有效事项。'), findsOneWidget);
    expect(find.widgetWithText(AlertDialog, '编辑时间段'), findsOneWidget);

    await _chooseEntryActivity(tester, targetActivity.name);
    await _tapAndPumpUntilGone(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.widgetWithText(AlertDialog, '编辑时间段'),
    );

    final storedEntries = await tester.runAsync(
      () => fixture.repository.entriesForDay(state.selectedDay),
    );
    expect(tester.takeException(), isNull);
    expect(storedEntries!.single.activityId, targetActivity.id);
  });

  testWidgets('timeline editor ignores delayed overlap after dialog closes', (
    tester,
  ) async {
    final fixture = (await tester
        .runAsync(() => _buildPersistedFixture(delayOverlaps: true)))!;
    final state = fixture.state as _DelayedOverlapAppState;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());

    await _pumpTimeline(tester, state, width: 920);
    final activity = state.activityById(state.dayEntries.single.activityId)!;
    await _tapEntryEditButton(tester, title: activity.name);
    await tester.runAsync(
      () async => tester.tap(find.widgetWithText(FilledButton, '保存').last),
    );
    for (var attempt = 0; attempt < 20; attempt += 1) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      if (state.overlapRequested) {
        break;
      }
    }

    expect(state.overlapRequested, isTrue);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    state.overlapCompleter.complete([
      state.dayEntries.single.copyWith(id: 'other-entry'),
    ]);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AlertDialog, '编辑时间段'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'timeline editor does not reuse note controller after closing during save',
    (tester) async {
      final fixture = (await tester
          .runAsync(() => _buildPersistedFixture(delayOverlaps: true)))!;
      final state = fixture.state as _DelayedOverlapAppState;
      addTearDown(state.dispose);
      addTearDown(() async => fixture.database?.close());

      await _pumpTimeline(tester, state, width: 920);
      final activity = state.activityById(state.dayEntries.single.activityId)!;
      await _tapEntryEditButton(tester, title: activity.name);
      await tester.enterText(find.widgetWithText(TextField, '备注'), '关闭时仍在保存');
      await tester.pump();
      await tester.runAsync(
        () async => tester.tap(find.widgetWithText(FilledButton, '保存').last),
      );
      for (var attempt = 0; attempt < 20; attempt += 1) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (state.overlapRequested) {
          break;
        }
      }

      expect(state.overlapRequested, isTrue);

      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      state.overlapCompleter.complete(<TimeEntry>[]);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AlertDialog, '编辑时间段'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('entry editor avoids overflow while editing current activity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fixture = _buildFixture();
    final state = fixture.state;
    addTearDown(state.dispose);
    final entry = _entry(
      id: 'entry',
      startAt: DateTime(2026, 1, 2, 9),
      endAt: DateTime(2026, 1, 2, 10),
    );
    state.dayEntries = [entry];

    await _pumpTimeline(tester, state, width: 360);
    await _tapEntryEditButton(tester, title: _activity.name);
    await tester.tap(find.byTooltip('编辑当前事项'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AlertDialog, '编辑事项'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline editor saves after renaming the current activity', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_buildPersistedFixture))!;
    final state = fixture.state;
    addTearDown(state.dispose);
    addTearDown(() async => fixture.database?.close());

    await _pumpTimeline(tester, state, width: 920);
    final activity = state.activityById(state.dayEntries.single.activityId)!;
    await _tapEntryEditButton(tester, title: activity.name);
    await tester.tap(find.byTooltip('编辑当前事项'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '名称'), '深度工作');
    await tester.pump();
    await _tapAndPumpUntilGone(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.widgetWithText(AlertDialog, '编辑事项'),
    );

    expect(find.text('深度工作'), findsWidgets);
    expect(tester.takeException(), isNull);

    await _tapAndPumpUntilGone(
      tester,
      find.widgetWithText(FilledButton, '保存').last,
      find.widgetWithText(AlertDialog, '编辑时间段'),
    );

    expect(find.text('深度工作'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date text shows calendar icon', (tester) async {
    final fixture = _buildFixture();
    final state = fixture.state;
    addTearDown(state.dispose);

    await _pumpTimeline(tester, state, width: 920);

    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('future day shows banner when selectedDay is ahead of now',
      (tester) async {
    final fixture = _buildFixture();
    final state = fixture.state;
    addTearDown(state.dispose);

    state
      ..selectedDay = DateTime(2026, 1, 10)
      ..now = DateTime(2026, 1, 2, 12);

    await _pumpTimeline(tester, state, width: 920);

    expect(find.textContaining('尚未到来'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
