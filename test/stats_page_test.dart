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
import 'package:timetrack/ui/stats_page.dart';

class _StatsFixture {
  const _StatsFixture({
    required this.state,
  });

  final AppState state;
}

_StatsFixture _buildFixture() {
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
    ..activities = [
      Activity(
        id: 'work',
        userId: null,
        name: '工作',
        color: 0xff2563eb,
        isFavorite: true,
        updatedAt: DateTime(2026, 1, 1),
        isDeleted: false,
      ),
    ]
    ..selectedDay = DateTime(2026, 1, 2)
    ..now = DateTime(2026, 1, 2, 12);
  return _StatsFixture(state: state);
}

Future<void> _pumpStats(
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
          child: StatsPage(state: state),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('stats page shows all five range preset options', (tester) async {
    final fixture = _buildFixture();
    final state = fixture.state;
    addTearDown(state.dispose);

    await _pumpStats(tester, state, width: 920);

    expect(find.text('今天'), findsWidgets);
    expect(find.text('昨天'), findsOneWidget);
    expect(find.text('本周'), findsOneWidget);
    expect(find.text('上周'), findsOneWidget);
    expect(find.text('单日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('default preset shows today labels', (tester) async {
    final fixture = _buildFixture();
    final state = fixture.state;
    addTearDown(state.dispose);

    await _pumpStats(tester, state, width: 920);

    expect(find.text('今天分布'), findsOneWidget);
    expect(find.text('范围总记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
