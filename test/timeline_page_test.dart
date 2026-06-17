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
import 'package:timetrack/ui/timeline_page.dart';

class _TimelineFixture {
  const _TimelineFixture({
    required this.state,
    required this.repository,
  });

  final AppState state;
  final TimeRepository repository;
}

_TimelineFixture _buildFixture() {
  final database = LocalDatabase();
  final repository = TimeRepository(database: database);
  final peerStore = SyncPeerStore(database: database);
  final state = AppState(
    repository: repository,
    syncService: SyncService(repository: repository, client: null),
    lanSyncServer: LanSyncServer(
      repository: repository,
      peerStore: peerStore,
      portCandidates: const [0],
    ),
    lanSyncClient: LanSyncClient(
      repository: repository,
      peerStore: peerStore,
    ),
    fileInteropService: FileInteropService(repository: repository),
  );
  state
    ..isLoading = false
    ..activities = [_activity]
    ..selectedDay = DateTime(2026, 1, 2)
    ..now = DateTime(2026, 1, 2, 12);
  return _TimelineFixture(state: state, repository: repository);
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
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 900,
          child: TimelinePage(state: state),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
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
    await tester.tap(find.byTooltip('编辑'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('保持进行中'), findsWidgets);
    expect(find.text('关闭后可把这条记录保存为已结束。'), findsOneWidget);
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
