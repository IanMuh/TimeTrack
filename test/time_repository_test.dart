import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timetrack/app/app_state.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/time_repository.dart';
import 'package:timetrack/domain/profile_settings.dart';
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
  test('seed data includes editable unassigned activity', () async {
    final repository = await buildRepository();

    final unassigned = (await repository.activities())
        .singleWhere((activity) => activity.isUnassigned);

    expect(unassigned.name, '未安排');

    final updated = await repository.updateActivity(
      activity: unassigned,
      name: '空档',
      color: 0xff475569,
    );
    await repository.ensureSeedData();

    final activities = await repository.activities();
    expect(updated.isUnassigned, isTrue);
    expect(
      activities.singleWhere((activity) => activity.isUnassigned).name,
      '空档',
    );
  });

  test('seed data upgrades legacy unassigned activity by name', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await LocalDatabase.createSchema(db);
    await db.insert('activities', {
      'id': 'legacy',
      'user_id': null,
      'name': '未安排',
      'color': 0xff111111,
      'is_favorite': 1,
      'updated_at': DateTime(2026, 1, 1).toIso8601String(),
      'is_deleted': 0,
      'is_unassigned': 0,
    });
    final repository = TimeRepository(database: LocalDatabase(database: db));

    await repository.ensureSeedData();

    final unassigned = (await repository.activities())
        .where((activity) => activity.isUnassigned);
    expect(unassigned, hasLength(1));
    expect(unassigned.single.id, 'legacy');
    expect(unassigned.single.isFavorite, isFalse);
  });

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

  test('overlap detection reports conflicting entries without deleting them',
      () async {
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

  test('entriesForRange returns entries overlapping the selected range',
      () async {
    final repository = await buildRepository();
    final activity = (await repository.activities()).first;
    final entry = await repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 23, 30),
      endAt: DateTime(2026, 1, 2, 0, 30),
      note: 'cross day',
    );

    final entries = await repository.entriesForRange(
      DateTime(2026, 1, 2),
      DateTime(2026, 1, 3),
    );

    expect(entries.map((item) => item.id), contains(entry.id));
  });

  test('TimeRangeStats clips cross-day entries to the requested range', () {
    final entry = TimeEntry(
      id: 'entry-1',
      userId: null,
      activityId: 'work',
      startAt: DateTime(2026, 1, 1, 23, 30),
      endAt: DateTime(2026, 1, 2, 1, 15),
      note: '',
      deviceId: 'test',
      updatedAt: DateTime(2026, 1, 1),
      isDeleted: false,
    );

    final stats = TimeRangeStats.fromEntries(
      entries: [entry],
      start: DateTime(2026, 1, 2),
      end: DateTime(2026, 1, 3),
      effectiveNow: DateTime(2026, 1, 2, 12),
    );

    expect(stats.totalDuration, const Duration(hours: 1, minutes: 15));
    expect(stats.longestBlock, const Duration(hours: 1, minutes: 15));
    expect(
        stats.totalsByActivity['work'], const Duration(hours: 1, minutes: 15));
    expect(
      stats.totalsByDay[DateTime(2026, 1, 2)],
      const Duration(hours: 1, minutes: 15),
    );
  });

  test('TimeRangeStats uses effectiveNow for running entries', () {
    final entry = TimeEntry(
      id: 'entry-1',
      userId: null,
      activityId: 'work',
      startAt: DateTime(2026, 1, 2, 9),
      endAt: null,
      note: '',
      deviceId: 'test',
      updatedAt: DateTime(2026, 1, 2, 9),
      isDeleted: false,
    );

    final stats = TimeRangeStats.fromEntries(
      entries: [entry],
      start: DateTime(2026, 1, 2),
      end: DateTime(2026, 1, 3),
      effectiveNow: DateTime(2026, 1, 2, 10, 30),
    );

    expect(stats.totalDuration, const Duration(hours: 1, minutes: 30));
  });

  test('profile settings store reminder cadence and delivery method', () async {
    final settings = ProfileSettings.defaults().copyWith(
      reminderMinutes: 30,
      reminderIntervalMinutes: 12,
      reminderMethod: ReminderMethod.dialog,
      reminderTimeOfDayMinutes: 9 * 60,
      updatedAt: DateTime(2026, 1, 1, 8),
    );

    expect(settings.toLocalMap()['reminder_interval_minutes'], 12);
    expect(settings.toLocalMap()['reminder_method'], 'dialog');
    expect(settings.toLocalMap()['reminder_time_of_day_minutes'], 540);
  });

  test('profile settings migration fills reminder defaults', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute('''
      create table profile_settings (
        id integer primary key check (id = 1),
        user_id text,
        reminder_minutes integer not null default 45,
        timezone text not null,
        updated_at text not null
      )
    ''');
    await db.insert('profile_settings', {
      'id': 1,
      'user_id': null,
      'reminder_minutes': 50,
      'timezone': 'UTC',
      'updated_at': DateTime(2026, 1, 1).toIso8601String(),
    });
    await LocalDatabase.migrateProfileSettingsReminderSchema(db);
    final database = LocalDatabase(database: db);
    final repository = TimeRepository(database: database);

    final settings = await repository.settings();

    expect(settings.reminderMinutes, 50);
    expect(settings.reminderIntervalMinutes, 10);
    expect(settings.reminderMethod, ReminderMethod.dialog);
    expect(settings.reminderTimeOfDayMinutes, 9 * 60);
  });
}
