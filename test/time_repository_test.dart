import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/time_repository.dart';
import 'package:timetrack/domain/time_entry.dart';

Future<TimeRepository> buildRepository() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await LocalDatabase.createSchema(db);
  final repository = TimeRepository(database: LocalDatabase(database: db));
  await repository.ensureSeedData();
  return repository;
}

void main() {
  test('switching activities closes previous running entry', () async {
    final repository = await buildRepository();
    final activities = await repository.activities();
    final firstStart = DateTime(2026, 1, 1, 9);
    final secondStart = DateTime(2026, 1, 1, 10, 15);

    final first = await repository.switchToActivity(
      activities[0].id,
      at: firstStart,
    );
    final second = await repository.switchToActivity(
      activities[1].id,
      at: secondStart,
    );

    final entries = await repository.entriesForDay(firstStart);
    final closed = entries.firstWhere((entry) => entry.id == first.id);
    final logs = await repository.actionLogsForDay(firstStart);

    expect(second.activityId, activities[1].id);
    expect(closed.endAt, secondStart);
    expect(await repository.runningEntry(), isNotNull);
    expect(logs.map((log) => log.actionType), ['switch', 'switch']);
  });

  test('overlap detection reports conflicting entries without deleting them', () async {
    final repository = await buildRepository();
    final activity = (await repository.activities()).first;
    final day = DateTime(2026, 1, 1);

    final existing = await repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 10),
      note: 'existing',
    );
    final candidate = TimeEntry(
      id: 'candidate',
      userId: null,
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 9, 30),
      endAt: DateTime(2026, 1, 1, 10, 30),
      note: '',
      deviceId: 'test',
      updatedAt: DateTime.now(),
      isDeleted: false,
    );

    final overlaps = await repository.overlappingEntries(candidate);
    final entries = await repository.entriesForDay(day);
    final logs = await repository.actionLogsSince(DateTime(2020));

    expect(overlaps.map((entry) => entry.id), contains(existing.id));
    expect(entries.map((entry) => entry.id), contains(existing.id));
    expect(logs.map((log) => log.actionType), contains('manual'));
  });

  test('entries crossing midnight appear on both days', () async {
    final repository = await buildRepository();
    final activity = (await repository.activities()).first;

    await repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 23, 30),
      endAt: DateTime(2026, 1, 2, 0, 30),
      note: 'cross day',
    );

    expect(await repository.entriesForDay(DateTime(2026, 1, 1)), hasLength(1));
    expect(await repository.entriesForDay(DateTime(2026, 1, 2)), hasLength(1));
  });
}
