import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timetrack/app/app_state.dart';
import 'package:timetrack/data/file_interop_service.dart';
import 'package:timetrack/data/lan_sync.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/sync_peer_store.dart';
import 'package:timetrack/data/sync_service.dart';
import 'package:timetrack/data/time_repository.dart';
import 'package:timetrack/domain/profile_settings.dart';

Future<AppState> _buildState() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await LocalDatabase.createSchema(db);
  final database = LocalDatabase(database: db);
  final repository = TimeRepository(database: database);
  final peerStore = SyncPeerStore(database: database);
  await repository.ensureSeedData();
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
  await state.refresh();
  return state;
}

void main() {
  test('reminder interval controls repeated reminder cadence', () async {
    final state = await _buildState();
    addTearDown(state.dispose);
    final activity = state.activities.first;
    final startedAt = DateTime(2026, 1, 1, 9);

    await state.switchTo(activity);
    state.runningEntry = state.runningEntry?.copyWith(startAt: startedAt);
    state.settings = state.settings.copyWith(
      reminderMinutes: 30,
      reminderIntervalMinutes: 15,
      reminderMethod: ReminderMethod.dialog,
    );
    state.now = DateTime(2026, 1, 1, 9, 30);

    expect(state.shouldShowReminder, isTrue);

    state.lastReminderAt = DateTime(2026, 1, 1, 9, 20);
    expect(state.shouldShowReminder, isFalse);

    state.lastReminderAt = DateTime(2026, 1, 1, 9, 15);
    expect(state.shouldShowReminder, isTrue);
  });
}
