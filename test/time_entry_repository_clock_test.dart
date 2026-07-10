import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timetrack/core/result.dart';
import 'package:timetrack/data/activity_repository.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/repository_interfaces.dart';
import 'package:timetrack/data/time_entry_repository.dart';
import 'package:timetrack/domain/action_log.dart';
import 'package:timetrack/domain/activity.dart';

void main() {
  test('time entry command timestamps use the injected clock', () async {
    var current = DateTime.utc(2026, 1, 2, 8, 30, 12, 345);
    final fixture = await _buildClockFixture(clock: () => current);
    addTearDown(fixture.close);

    final activity = await fixture.createActivity();
    final createdAt = current;
    final manual = _unwrap(
      await fixture.repository.createManualEntry(
        activityId: activity.id,
        startAt: DateTime(2026, 1, 1, 9),
        endAt: DateTime(2026, 1, 1, 11),
        note: '',
      ),
    );

    expect(manual.updatedAt, createdAt);
    expect(
      await fixture.entryUpdatedAt(manual.id),
      _storedDateTime(createdAt),
    );
    expect(
      await fixture.actionLogOccurredAt(manual.id, ActionType.manual),
      _storedDateTime(createdAt),
    );

    current = DateTime.utc(2026, 1, 2, 8, 31, 12, 345);
    final splitAtClock = current;
    final segments = _unwrap(
      await fixture.repository.splitEntry(
        entryId: manual.id,
        splitAt: DateTime(2026, 1, 1, 10),
      ),
    );

    expect(segments.map((entry) => entry.updatedAt).toSet(), {splitAtClock});
    expect(
      await fixture.actionLogOccurredAt(manual.id, ActionType.split),
      _storedDateTime(splitAtClock),
    );

    current = DateTime.utc(2026, 1, 2, 8, 32, 12, 345);
    final deleteAt = current;
    _unwrap(await fixture.repository.deleteEntry(segments.first));

    expect(
      await fixture.entryUpdatedAt(segments.first.id),
      _storedDateTime(deleteAt),
    );
    expect(
      await fixture.actionLogOccurredAt(segments.first.id, ActionType.delete),
      _storedDateTime(deleteAt),
    );

    current = DateTime.utc(2026, 1, 2, 8, 33, 12, 345);
    final previous = _unwrap(
      await fixture.repository.createManualEntry(
        activityId: activity.id,
        startAt: DateTime(2026, 1, 1, 12),
        endAt: DateTime(2026, 1, 1, 13),
        note: '',
      ),
    );
    final next = _unwrap(
      await fixture.repository.createManualEntry(
        activityId: activity.id,
        startAt: DateTime(2026, 1, 1, 13),
        endAt: DateTime(2026, 1, 1, 14),
        note: '',
      ),
    );

    current = DateTime.utc(2026, 1, 2, 8, 34, 12, 345);
    final mergeAt = current;
    final merged = _unwrap(
      await fixture.repository.mergeEntryWithNeighbor(
        entryId: next.id,
        direction: EntryMergeDirection.previous,
        confirmed: true,
      ),
    );

    expect(merged, isNotNull);
    expect(merged!.updatedAt, mergeAt);
    expect(await fixture.entryUpdatedAt(next.id), _storedDateTime(mergeAt));
    expect(await fixture.entryUpdatedAt(previous.id), _storedDateTime(mergeAt));
    expect(
      await fixture.actionLogOccurredAt(next.id, ActionType.merge),
      _storedDateTime(mergeAt),
    );
  });
}

Future<_ClockFixture> _buildClockFixture({
  required TimeEntryClock clock,
}) async {
  sqfliteFfiInit();
  final sqliteDatabase = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await LocalDatabase.createSchema(sqliteDatabase);
  final database = LocalDatabase(database: sqliteDatabase);
  final activityRepository = ActivityRepository(database: database);
  final repository = TimeEntryRepository(
    database: database,
    activityRepository: activityRepository,
    clock: clock,
  );
  return _ClockFixture(
    database: sqliteDatabase,
    activityRepository: activityRepository,
    repository: repository,
  );
}

String _storedDateTime(DateTime value) => value.toUtc().toIso8601String();

T _unwrap<T>(AppResult<T> result) {
  return switch (result) {
    AppSuccess(:final value) => value,
    AppFailure(:final message) => throw StateError(message),
  };
}

class _ClockFixture {
  const _ClockFixture({
    required this.database,
    required this.activityRepository,
    required this.repository,
  });

  final Database database;
  final ActivityRepository activityRepository;
  final TimeEntryRepository repository;

  Future<Activity> createActivity() async {
    return _unwrap(
      await activityRepository.createActivity(
        name: 'Focus',
        color: 0xFF1565C0,
      ),
    );
  }

  Future<String> entryUpdatedAt(String entryId) async {
    final rows = await database.query(
      'time_entries',
      columns: ['updated_at'],
      where: 'id = ?',
      whereArgs: [entryId],
    );
    return rows.single['updated_at']! as String;
  }

  Future<String> actionLogOccurredAt(
    String entryId,
    ActionType actionType,
  ) async {
    final rows = await database.query(
      'action_logs',
      columns: ['occurred_at'],
      where: 'entry_id = ? and action_type = ?',
      whereArgs: [entryId, actionType.storageValue],
      orderBy: 'occurred_at desc',
      limit: 1,
    );
    return rows.single['occurred_at']! as String;
  }

  Future<void> close() => database.close();
}
