import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timetrack/app/app_state.dart';
import 'package:timetrack/data/file_interop_service.dart';
import 'package:timetrack/data/lan_sync.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/sync_peer_store.dart';
import 'package:timetrack/data/sync_service.dart';
import 'package:timetrack/data/time_repository.dart';

Future<({AppState state, TimeRepository repository, Database db})>
    _buildState() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await LocalDatabase.createSchema(db);
  final database = LocalDatabase(database: db);
  final repository = TimeRepository(database: database);
  await repository.ensureSeedData();
  final peerStore = SyncPeerStore(database: database);
  final state = AppState(
    repository: repository,
    syncService: SyncService(repository: repository, client: null),
    lanSyncServer: LanSyncServer(
      repository: repository,
      peerStore: peerStore,
      portCandidates: const [0],
    ),
    lanSyncClient: LanSyncClient(repository: repository, peerStore: peerStore),
    fileInteropService: FileInteropService(repository: repository),
  )
    ..isLoading = false
    ..now = DateTime(2026, 1, 1, 12)
    ..selectedDay = DateTime(2026, 1, 1);
  await state.refresh();
  return (state: state, repository: repository, db: db);
}

void main() {
  test('manual entry undo restores an overlapped entry and redo reapplies cut',
      () async {
    final fixture = await _buildState();
    addTearDown(fixture.state.dispose);
    addTearDown(fixture.db.close);
    final activities = fixture.state.activities
        .where((activity) => !activity.isUnassigned)
        .toList();
    final existing = await fixture.repository.createManualEntry(
      activityId: activities[0].id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 12),
      note: 'existing',
    );
    await fixture.state.refresh();

    await fixture.state.createManualEntry(
      activityId: activities[1].id,
      startAt: DateTime(2026, 1, 1, 10),
      endAt: DateTime(2026, 1, 1, 11),
      note: 'inserted',
    );

    expect(fixture.state.canUndo, isTrue);
    expect(fixture.state.canRedo, isFalse);
    expect(fixture.state.undoLabel, '补记时间段');
    expect(fixture.state.dayEntries, hasLength(3));

    await fixture.state.undo();

    expect(fixture.state.canRedo, isTrue);
    expect(fixture.state.dayEntries, hasLength(1));
    expect(fixture.state.dayEntries.single.id, existing.id);
    expect(fixture.state.dayEntries.single.startAt, DateTime(2026, 1, 1, 9));
    expect(fixture.state.dayEntries.single.endAt, DateTime(2026, 1, 1, 12));

    await fixture.state.redo();

    expect(fixture.state.canUndo, isTrue);
    expect(fixture.state.canRedo, isFalse);
    expect(fixture.state.dayEntries, hasLength(3));
    expect(
      fixture.state.dayEntries.map((entry) => entry.activityId),
      contains(activities[1].id),
    );
  });

  test('switch and stop can be undone and redone', () async {
    final fixture = await _buildState();
    addTearDown(fixture.state.dispose);
    addTearDown(fixture.db.close);
    final activities = fixture.state.activities
        .where((activity) => !activity.isUnassigned)
        .toList();

    fixture.state.now = DateTime(2026, 1, 1, 9);
    await fixture.state.switchTo(activities[0]);
    fixture.state.now = DateTime(2026, 1, 1, 10);
    await fixture.state.switchTo(activities[1]);

    expect(fixture.state.runningActivity?.id, activities[1].id);
    var storedEntries = await fixture.repository.allEntries();
    expect(
      storedEntries.where(
        (entry) => !entry.isDeleted && entry.activityId == activities[0].id,
      ),
      isNotEmpty,
    );

    await fixture.state.undo();

    expect(fixture.state.runningActivity?.id, activities[0].id);
    storedEntries = await fixture.repository.allEntries();
    expect(
      storedEntries.where(
        (entry) =>
            !entry.isDeleted &&
            entry.activityId == activities[0].id &&
            entry.endAt == null,
      ),
      hasLength(1),
    );

    await fixture.state.redo();

    expect(fixture.state.runningActivity?.id, activities[1].id);
    storedEntries = await fixture.repository.allEntries();
    expect(
      storedEntries.where(
        (entry) =>
            !entry.isDeleted &&
            entry.activityId == activities[0].id &&
            entry.endAt != null,
      ),
      isNotEmpty,
    );

    await fixture.state.stopCurrent();
    expect(fixture.state.runningActivity, isNull);
    expect(
      fixture.state.runningEntry?.activityId,
      fixture.state.unassignedActivity?.id,
    );

    await fixture.state.undo();

    expect(fixture.state.runningActivity?.id, activities[1].id);
  });

  test('entry edits, split, merge, delete, extend, and activity edits undo',
      () async {
    final fixture = await _buildState();
    addTearDown(fixture.state.dispose);
    addTearDown(fixture.db.close);
    final activities = fixture.state.activities
        .where((activity) => !activity.isUnassigned)
        .toList();
    await fixture.state.createManualEntry(
      activityId: activities[0].id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 11),
      note: 'original',
    );
    final entry = fixture.state.dayEntries.single;

    await fixture.state.saveEntry(entry.copyWith(note: 'edited'));
    expect(fixture.state.dayEntries.single.note, 'edited');
    await fixture.state.undo();
    expect(fixture.state.dayEntries.single.note, 'original');

    await fixture.state.splitEntry(
      entryId: fixture.state.dayEntries.single.id,
      splitAt: DateTime(2026, 1, 1, 10),
    );
    expect(fixture.state.dayEntries, hasLength(2));
    await fixture.state.undo();
    expect(fixture.state.dayEntries, hasLength(1));

    await fixture.state.splitEntry(
      entryId: fixture.state.dayEntries.single.id,
      splitAt: DateTime(2026, 1, 1, 10),
    );
    await fixture.state.mergeEntryWithNeighbor(
      entryId: fixture.state.dayEntries.last.id,
      direction: EntryMergeDirection.previous,
      confirmed: true,
    );
    expect(fixture.state.dayEntries, hasLength(1));
    await fixture.state.undo();
    expect(fixture.state.dayEntries, hasLength(2));

    await fixture.state.deleteEntry(fixture.state.dayEntries.first);
    expect(fixture.state.dayEntries, hasLength(1));
    await fixture.state.undo();
    expect(fixture.state.dayEntries, hasLength(2));

    final extended = fixture.state.dayEntries.first;
    fixture.state.now = DateTime(2026, 1, 1, 12);
    await fixture.state.extendEntryToNow(extended);
    expect(fixture.state.runningEntry?.id, extended.id);
    await fixture.state.undo();
    expect(fixture.state.runningEntry?.id, isNot(extended.id));

    final created = await fixture.state.createActivity('新事项', 0xff123456);
    expect(
        fixture.state.activities.any((activity) => activity.id == created.id),
        isTrue);
    await fixture.state.undo();
    expect(
        fixture.state.activities.any((activity) => activity.id == created.id),
        isFalse);

    final updated = await fixture.state.updateActivity(
      activities[0],
      name: '工作更新',
      color: 0xff654321,
    );
    expect(updated.name, '工作更新');
    await fixture.state.undo();
    expect(
        fixture.state.activityById(activities[0].id)?.name, activities[0].name);

    await fixture.state.deleteActivity(activities[0]);
    expect(fixture.state.activityById(activities[0].id), isNull);
    await fixture.state.undo();
    expect(fixture.state.activityById(activities[0].id)?.isDeleted, isFalse);
  });

  test('new operation clears redo stack', () async {
    final fixture = await _buildState();
    addTearDown(fixture.state.dispose);
    addTearDown(fixture.db.close);
    final activities = fixture.state.activities
        .where((activity) => !activity.isUnassigned)
        .toList();

    await fixture.state.createManualEntry(
      activityId: activities[0].id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 10),
      note: '',
    );
    await fixture.state.undo();
    expect(fixture.state.canRedo, isTrue);

    await fixture.state.createManualEntry(
      activityId: activities[1].id,
      startAt: DateTime(2026, 1, 1, 10),
      endAt: DateTime(2026, 1, 1, 11),
      note: '',
    );

    expect(fixture.state.canRedo, isFalse);
  });
}
