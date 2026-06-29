import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timetrack/app/app_state.dart';
import 'package:timetrack/data/activity_repository.dart';
import 'package:timetrack/data/device_id_store.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/settings_repository.dart';
import 'package:timetrack/data/time_repository.dart';
import 'package:timetrack/domain/action_log.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/activity_category.dart';
import 'package:timetrack/domain/profile_settings.dart';
import 'package:timetrack/domain/time_entry.dart';
import 'test_fixtures.dart';

class RepositoryFixture {
  const RepositoryFixture({required this.repository, required this.database});

  final TimeRepository repository;
  final Database database;
}

Future<RepositoryFixture> buildRepositoryFixture() async {
  final fixture = await buildTestRepositoryFixture();
  addTearDown(fixture.close);
  return RepositoryFixture(
    repository: fixture.repository,
    database: fixture.sqliteDatabase,
  );
}

Future<TimeRepository> buildRepository() async {
  return (await buildRepositoryFixture()).repository;
}

String _planText(List<Map<String, Object?>> rows) {
  return rows.map((row) => row.values.join(' ')).join('\n');
}

void main() {
  test('seed data includes immutable unassigned activity', () async {
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
    expect(updated.name, '未安排');
    expect(updated.color, unassigned.color);
    expect(
      activities.singleWhere((activity) => activity.isUnassigned).name,
      '未安排',
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
    final database = LocalDatabase(database: db);
    final activityRepository = ActivityRepository(database: database);
    final settingsRepository = SettingsRepository(database: database);
    final deviceIdStore = DeviceIdStore(database: database);
    final timeEntryRepository = TimeEntryRepository(
      database: database,
      activityRepository: activityRepository,
    );
    final actionLogRepository = ActionLogRepository(database: database);
    final repository = TimeRepository(
      database: database,
      activityRepository: activityRepository,
      settingsRepository: settingsRepository,
      deviceIdStore: deviceIdStore,
      timeEntryRepository: timeEntryRepository,
      actionLogRepository: actionLogRepository,
    );

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
    expect(logs.map((log) => log.actionType),
        [ActionType.switch_, ActionType.switch_]);
  });

  test('common range queries use performance indexes', () async {
    final fixture = await buildRepositoryFixture();
    final db = fixture.database;
    final activity = (await fixture.repository.activities())
        .firstWhere((item) => !item.isUnassigned);
    final base = DateTime(2025, 1, 1);
    final batch = db.batch();

    for (var i = 0; i < 1500; i += 1) {
      final start = base.add(Duration(hours: i));
      final end = start.add(const Duration(minutes: 30));
      batch.insert('time_entries', {
        'id': 'bulk-entry-$i',
        'user_id': null,
        'activity_id': activity.id,
        'activity_name': activity.name,
        'activity_color': activity.color,
        'start_at': start.toUtc().toIso8601String(),
        'end_at': end.toUtc().toIso8601String(),
        'note': '',
        'device_id': 'test-device',
        'updated_at': end.toUtc().toIso8601String(),
        'is_deleted': 0,
      });
      batch.insert('action_logs', {
        'id': 'bulk-log-$i',
        'user_id': null,
        'action_type': 'switch',
        'activity_id': activity.id,
        'entry_id': 'bulk-entry-$i',
        'message': 'bulk',
        'occurred_at': start.toUtc().toIso8601String(),
        'device_id': 'test-device',
        'updated_at': start.toUtc().toIso8601String(),
        'is_deleted': 0,
      });
    }
    await batch.commit(noResult: true);

    final rangeStart = DateTime(2025, 1, 10).toUtc().toIso8601String();
    final rangeEnd = DateTime(2025, 1, 11).toUtc().toIso8601String();
    final entryPlan = _planText(await db.rawQuery(
      'explain query plan select * from time_entries '
      'where is_deleted = 0 and start_at < ? and '
      '(end_at is null or end_at > ?) '
      'order by is_deleted asc, start_at asc',
      [rangeEnd, rangeStart],
    ));
    final logPlan = _planText(await db.rawQuery(
      'explain query plan select * from action_logs '
      'where is_deleted = 0 and occurred_at >= ? and occurred_at < ? '
      'order by is_deleted asc, occurred_at asc',
      [rangeStart, rangeEnd],
    ));

    expect(entryPlan, contains('idx_time_entries_active_start'));
    expect(logPlan, contains('idx_action_logs_active_occurred_at'));
  });

  test('stopping while already unassigned does not split it', () async {
    final repository = await buildRepository();
    final activities = await repository.activities();
    final activity =
        activities.firstWhere((activity) => !activity.isUnassigned);
    final unassigned =
        activities.singleWhere((activity) => activity.isUnassigned);

    await repository.switchToActivity(activity.id, at: DateTime(2026, 1, 1, 9));
    await repository.stopRunning(at: DateTime(2026, 1, 1, 10));
    final runningBefore = await repository.runningEntry();

    await repository.stopRunning(at: DateTime(2026, 1, 1, 11));

    final runningAfter = await repository.runningEntry();
    final activeUnassigned = (await repository.allEntries())
        .where(
          (entry) =>
              entry.activityId == unassigned.id &&
              !entry.isDeleted &&
              entry.endAt == null,
        )
        .toList();
    final logs = await repository.actionLogsForDay(DateTime(2026, 1, 1));

    expect(runningBefore, isNotNull);
    expect(runningAfter?.id, runningBefore?.id);
    expect(activeUnassigned, hasLength(1));
    expect(activeUnassigned.single.startAt, DateTime(2026, 1, 1, 10));
    expect(logs.map((log) => log.actionType),
        [ActionType.switch_, ActionType.stop, ActionType.switch_]);
  });

  test('switching to running unassigned does not split it', () async {
    final repository = await buildRepository();
    final activities = await repository.activities();
    final activity =
        activities.firstWhere((activity) => !activity.isUnassigned);
    final unassigned =
        activities.singleWhere((activity) => activity.isUnassigned);

    await repository.switchToActivity(activity.id, at: DateTime(2026, 1, 1, 9));
    await repository.stopRunning(at: DateTime(2026, 1, 1, 10));
    final runningBefore = await repository.runningEntry();

    final returned = await repository.switchToActivity(
      unassigned.id,
      at: DateTime(2026, 1, 1, 11),
    );

    final runningAfter = await repository.runningEntry();
    final activeUnassigned = (await repository.allEntries())
        .where(
          (entry) =>
              entry.activityId == unassigned.id &&
              !entry.isDeleted &&
              entry.endAt == null,
        )
        .toList();

    expect(returned.id, runningBefore?.id);
    expect(runningAfter?.id, runningBefore?.id);
    expect(activeUnassigned, hasLength(1));
    expect(activeUnassigned.single.startAt, DateTime(2026, 1, 1, 10));
  });

  test('seed data merges adjacent unassigned entries', () async {
    final fixture = await buildRepositoryFixture();
    final repository = fixture.repository;
    final unassigned = (await repository.activities())
        .singleWhere((activity) => activity.isUnassigned);
    final firstStart = DateTime(2026, 1, 1, 9);
    final firstEnd = DateTime(2026, 1, 1, 10);
    final secondEnd = DateTime(2026, 1, 1, 11);

    await fixture.database.insert('time_entries', {
      'id': 'unassigned-1',
      'user_id': null,
      'activity_id': unassigned.id,
      'start_at': firstStart.toIso8601String(),
      'end_at': firstEnd.toIso8601String(),
      'note': '',
      'device_id': 'test-device',
      'updated_at': DateTime(2026, 1, 1, 9).toIso8601String(),
      'is_deleted': 0,
    });
    await fixture.database.insert('time_entries', {
      'id': 'unassigned-2',
      'user_id': null,
      'activity_id': unassigned.id,
      'start_at': firstEnd.toIso8601String(),
      'end_at': secondEnd.toIso8601String(),
      'note': '',
      'device_id': 'test-device',
      'updated_at': DateTime(2026, 1, 1, 10).toIso8601String(),
      'is_deleted': 0,
    });

    await repository.ensureSeedData();

    final entries = await repository.allEntries();
    final activeUnassigned = entries
        .where(
          (entry) => entry.activityId == unassigned.id && !entry.isDeleted,
        )
        .toList();
    final deletedUnassigned = entries
        .where(
          (entry) => entry.activityId == unassigned.id && entry.isDeleted,
        )
        .toList();

    expect(activeUnassigned, hasLength(1));
    expect(activeUnassigned.single.startAt, firstStart);
    expect(activeUnassigned.single.endAt, secondEnd);
    expect(deletedUnassigned.map((entry) => entry.id), ['unassigned-2']);
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
    expect(logs.map((log) => log.actionType), contains(ActionType.manual));
  });

  test('manual entry cuts an overlapping existing entry into edge segments',
      () async {
    final repository = await buildRepository();
    final activities = (await repository.activities())
        .where((activity) => !activity.isUnassigned)
        .toList();
    final day = DateTime(2026, 1, 1);

    final existing = await repository.createManualEntry(
      activityId: activities[0].id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 12),
      note: 'existing',
    );
    final inserted = await repository.createManualEntry(
      activityId: activities[1].id,
      startAt: DateTime(2026, 1, 1, 10),
      endAt: DateTime(2026, 1, 1, 11),
      note: 'inserted',
    );

    final entries = await repository.entriesForDay(day);

    expect(entries, hasLength(3));
    expect(entries[0].id, existing.id);
    expect(entries[0].activityId, activities[0].id);
    expect(entries[0].startAt, DateTime(2026, 1, 1, 9));
    expect(entries[0].endAt, DateTime(2026, 1, 1, 10));
    expect(entries[0].note, 'existing');
    expect(entries[1].id, inserted.id);
    expect(entries[1].activityId, activities[1].id);
    expect(entries[1].startAt, DateTime(2026, 1, 1, 10));
    expect(entries[1].endAt, DateTime(2026, 1, 1, 11));
    expect(entries[1].note, 'inserted');
    expect(entries[2].id, isNot(existing.id));
    expect(entries[2].activityId, activities[0].id);
    expect(entries[2].startAt, DateTime(2026, 1, 1, 11));
    expect(entries[2].endAt, DateTime(2026, 1, 1, 12));
    expect(entries[2].note, 'existing');
  });

  test('manual entry soft-deletes existing entries it fully covers', () async {
    final repository = await buildRepository();
    final activities = (await repository.activities())
        .where((activity) => !activity.isUnassigned)
        .toList();
    final day = DateTime(2026, 1, 1);

    final first = await repository.createManualEntry(
      activityId: activities[0].id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 10),
      note: 'first',
    );
    final second = await repository.createManualEntry(
      activityId: activities[0].id,
      startAt: DateTime(2026, 1, 1, 10),
      endAt: DateTime(2026, 1, 1, 11),
      note: 'second',
    );
    final inserted = await repository.createManualEntry(
      activityId: activities[1].id,
      startAt: DateTime(2026, 1, 1, 8),
      endAt: DateTime(2026, 1, 1, 12),
      note: 'inserted',
    );

    final dayEntries = await repository.entriesForDay(day);
    final allEntries = await repository.allEntries();
    final deletedIds = allEntries
        .where((entry) => entry.isDeleted)
        .map((entry) => entry.id)
        .toSet();

    expect(dayEntries, hasLength(1));
    expect(dayEntries.single.id, inserted.id);
    expect(dayEntries.single.startAt, DateTime(2026, 1, 1, 8));
    expect(dayEntries.single.endAt, DateTime(2026, 1, 1, 12));
    expect(deletedIds, containsAll([first.id, second.id]));
  });

  test('cross-day manual entry cuts overlaps on both local days', () async {
    final repository = await buildRepository();
    final activities = (await repository.activities())
        .where((activity) => !activity.isUnassigned)
        .toList();

    final existing = await repository.createManualEntry(
      activityId: activities[0].id,
      startAt: DateTime(2026, 1, 1, 23),
      endAt: DateTime(2026, 1, 2, 2),
      note: 'existing',
    );
    final inserted = await repository.createManualEntry(
      activityId: activities[1].id,
      startAt: DateTime(2026, 1, 1, 23, 30),
      endAt: DateTime(2026, 1, 2, 0, 30),
      note: 'inserted',
    );

    final firstDay = await repository.entriesForDay(DateTime(2026, 1, 1));
    final secondDay = await repository.entriesForDay(DateTime(2026, 1, 2));

    expect(firstDay, hasLength(2));
    expect(firstDay[0].id, existing.id);
    expect(firstDay[0].activityId, activities[0].id);
    expect(firstDay[0].startAt, DateTime(2026, 1, 1, 23));
    expect(firstDay[0].endAt, DateTime(2026, 1, 1, 23, 30));
    expect(firstDay[1].id, inserted.id);
    expect(firstDay[1].activityId, activities[1].id);
    expect(firstDay[1].startAt, DateTime(2026, 1, 1, 23, 30));
    expect(firstDay[1].endAt, DateTime(2026, 1, 2));

    expect(secondDay, hasLength(2));
    expect(secondDay[0].activityId, activities[1].id);
    expect(secondDay[0].startAt, DateTime(2026, 1, 2));
    expect(secondDay[0].endAt, DateTime(2026, 1, 2, 0, 30));
    expect(secondDay[1].activityId, activities[0].id);
    expect(secondDay[1].startAt, DateTime(2026, 1, 2, 0, 30));
    expect(secondDay[1].endAt, DateTime(2026, 1, 2, 2));
    expect(secondDay[1].note, 'existing');
  });

  test('manual entry cuts an overlapping running entry and resumes it',
      () async {
    final repository = await buildRepository();
    final activities = (await repository.activities())
        .where((activity) => !activity.isUnassigned)
        .toList();
    final day = DateTime(2026, 1, 1);

    final running = await repository.switchToActivity(
      activities[0].id,
      at: DateTime(2026, 1, 1, 9),
    );
    final inserted = await repository.createManualEntry(
      activityId: activities[1].id,
      startAt: DateTime(2026, 1, 1, 10),
      endAt: DateTime(2026, 1, 1, 11),
      note: 'inserted',
    );

    final entries = await repository.entriesForDay(day);
    final runningAfter = await repository.runningEntry();

    expect(entries, hasLength(3));
    expect(entries[0].id, running.id);
    expect(entries[0].activityId, activities[0].id);
    expect(entries[0].startAt, DateTime(2026, 1, 1, 9));
    expect(entries[0].endAt, DateTime(2026, 1, 1, 10));
    expect(entries[1].id, inserted.id);
    expect(entries[1].activityId, activities[1].id);
    expect(entries[1].startAt, DateTime(2026, 1, 1, 10));
    expect(entries[1].endAt, DateTime(2026, 1, 1, 11));
    expect(runningAfter, isNotNull);
    expect(runningAfter?.id, isNot(running.id));
    expect(runningAfter?.activityId, activities[0].id);
    expect(runningAfter?.startAt, DateTime(2026, 1, 1, 11));
    expect(runningAfter?.endAt, isNull);
    expect(entries[2].id, runningAfter?.id);
  });

  test('running replacement deletes later covered entries', () async {
    final repository = await buildRepository();
    final activities = (await repository.activities())
        .where((activity) => !activity.isUnassigned)
        .toList();
    final day = DateTime(2026, 1, 1);

    final extended = await repository.createManualEntry(
      activityId: activities[0].id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 10),
      note: '',
    );
    final covered = await repository.createManualEntry(
      activityId: activities[1].id,
      startAt: DateTime(2026, 1, 1, 10),
      endAt: DateTime(2026, 1, 1, 11),
      note: '',
    );
    final laterCovered = await repository.createManualEntry(
      activityId: activities[0].id,
      startAt: DateTime(2026, 1, 1, 11),
      endAt: DateTime(2026, 1, 1, 12),
      note: '',
    );

    await repository.saveEntry(
      extended.copyWith(clearEndAt: true, updatedAt: DateTime.now()),
      cutOverlaps: true,
    );

    final entries = await repository.entriesForDay(day);
    final running = await repository.runningEntry();
    final allEntries = await repository.allEntries();
    final coveredAfter =
        allEntries.singleWhere((entry) => entry.id == covered.id);
    final laterCoveredAfter =
        allEntries.singleWhere((entry) => entry.id == laterCovered.id);

    expect(entries, hasLength(1));
    expect(entries.single.id, extended.id);
    expect(entries.single.startAt, DateTime(2026, 1, 1, 9));
    expect(entries.single.endAt, isNull);
    expect(running?.id, extended.id);
    expect(coveredAfter.isDeleted, isTrue);
    expect(laterCoveredAfter.isDeleted, isTrue);
  });

  test('splitEntry divides a closed entry at the selected time', () async {
    final repository = await buildRepository();
    final activity = (await repository.activities())
        .firstWhere((activity) => !activity.isUnassigned);
    final day = DateTime(2026, 1, 1);

    final entry = await repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 11),
      note: 'deep work',
    );

    await repository.splitEntry(
      entryId: entry.id,
      splitAt: DateTime(2026, 1, 1, 10),
    );

    final entries = await repository.entriesForDay(day);
    final logs = await repository.allActionLogs();

    expect(entries, hasLength(2));
    expect(entries[0].id, entry.id);
    expect(entries[0].startAt, DateTime(2026, 1, 1, 9));
    expect(entries[0].endAt, DateTime(2026, 1, 1, 10));
    expect(entries[0].note, 'deep work');
    expect(entries[1].id, isNot(entry.id));
    expect(entries[1].startAt, DateTime(2026, 1, 1, 10));
    expect(entries[1].endAt, DateTime(2026, 1, 1, 11));
    expect(entries[1].note, 'deep work');
    expect(logs.map((log) => log.actionType), contains(ActionType.split));
  });

  test('entries crossing midnight are split into day-local rows', () async {
    final repository = await buildRepository();
    final activity = (await repository.activities()).first;

    final firstSegment = await repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 23, 30),
      endAt: DateTime(2026, 1, 2, 0, 30),
      note: 'cross day',
    );

    final firstDay = await repository.entriesForDay(DateTime(2026, 1, 1));
    final secondDay = await repository.entriesForDay(DateTime(2026, 1, 2));

    expect(firstDay, hasLength(1));
    expect(secondDay, hasLength(1));
    expect(firstDay.single.id, firstSegment.id);
    expect(firstDay.single.startAt, DateTime(2026, 1, 1, 23, 30));
    expect(firstDay.single.endAt, DateTime(2026, 1, 2));
    expect(secondDay.single.id, isNot(firstSegment.id));
    expect(secondDay.single.startAt, DateTime(2026, 1, 2));
    expect(secondDay.single.endAt, DateTime(2026, 1, 2, 0, 30));
  });

  test('entriesForRange returns split segments overlapping the selected range',
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

    expect(entries, hasLength(1));
    expect(entries.single.id, isNot(entry.id));
    expect(entries.single.startAt, DateTime(2026, 1, 2));
    expect(entries.single.endAt, DateTime(2026, 1, 2, 0, 30));
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

  test('TimeRangeStats groups by primary category and filters by any tag', () {
    final now = DateTime(2026, 1, 2, 12);
    final work = Activity(
      id: 'work',
      userId: null,
      name: '深度工作',
      color: 0xff2563eb,
      isFavorite: true,
      updatedAt: now,
      isDeleted: false,
    );
    final study = Activity(
      id: 'study',
      userId: null,
      name: '阅读',
      color: 0xff059669,
      isFavorite: true,
      updatedAt: now,
      isDeleted: false,
    );
    final workCategory = ActivityCategory(
      id: 'cat-work',
      userId: null,
      name: '工作',
      color: 0xff0f766e,
      updatedAt: now,
      isDeleted: false,
    );
    final focusCategory = ActivityCategory(
      id: 'cat-focus',
      userId: null,
      name: '专注',
      color: 0xff7c3aed,
      updatedAt: now,
      isDeleted: false,
    );
    final stats = TimeRangeStats.fromEntries(
      entries: [
        TimeEntry(
          id: 'entry-work',
          userId: null,
          activityId: work.id,
          startAt: DateTime(2026, 1, 2, 9),
          endAt: DateTime(2026, 1, 2, 9, 45),
          note: '',
          deviceId: 'test',
          updatedAt: now,
          isDeleted: false,
        ),
        TimeEntry(
          id: 'entry-study',
          userId: null,
          activityId: study.id,
          startAt: DateTime(2026, 1, 2, 10),
          endAt: DateTime(2026, 1, 2, 11),
          note: '',
          deviceId: 'test',
          updatedAt: now,
          isDeleted: false,
        ),
      ],
      start: DateTime(2026, 1, 2),
      end: DateTime(2026, 1, 3),
      effectiveNow: now,
      activities: [work, study],
      categories: [workCategory, focusCategory],
      categoryLinks: [
        ActivityCategoryLink(
          id: 'link-work-primary',
          userId: null,
          activityId: work.id,
          categoryId: workCategory.id,
          isPrimary: true,
          sortOrder: 0,
          updatedAt: now,
          isDeleted: false,
        ),
        ActivityCategoryLink(
          id: 'link-work-focus',
          userId: null,
          activityId: work.id,
          categoryId: focusCategory.id,
          isPrimary: false,
          sortOrder: 1,
          updatedAt: now,
          isDeleted: false,
        ),
      ],
    );

    final rows = stats.groupRows(
      dimension: StatsDimension.primaryCategory,
      selectedCategoryIds: {focusCategory.id},
    );

    expect(rows, hasLength(1));
    expect(rows.single.label, '工作');
    expect(rows.single.count, 1);
    expect(rows.single.totalDuration, const Duration(minutes: 45));
  });

  test('TimeRangeStats supports duration buckets and mixed dimensions', () {
    final now = DateTime(2026, 1, 2, 12);
    final work = Activity(
      id: 'work',
      userId: null,
      name: '深度工作',
      color: 0xff2563eb,
      isFavorite: true,
      updatedAt: now,
      isDeleted: false,
    );
    final admin = Activity(
      id: 'admin',
      userId: null,
      name: '行政',
      color: 0xffd97706,
      isFavorite: true,
      updatedAt: now,
      isDeleted: false,
    );
    final category = ActivityCategory(
      id: 'cat-work',
      userId: null,
      name: '工作',
      color: 0xff0f766e,
      updatedAt: now,
      isDeleted: false,
    );
    final stats = TimeRangeStats.fromEntries(
      entries: [
        TimeEntry(
          id: 'short',
          userId: null,
          activityId: admin.id,
          startAt: DateTime(2026, 1, 2, 8),
          endAt: DateTime(2026, 1, 2, 8, 20),
          note: '',
          deviceId: 'test',
          updatedAt: now,
          isDeleted: false,
        ),
        TimeEntry(
          id: 'medium',
          userId: null,
          activityId: work.id,
          startAt: DateTime(2026, 1, 2, 9),
          endAt: DateTime(2026, 1, 2, 9, 45),
          note: '',
          deviceId: 'test',
          updatedAt: now,
          isDeleted: false,
        ),
      ],
      start: DateTime(2026, 1, 2),
      end: DateTime(2026, 1, 3),
      effectiveNow: now,
      activities: [work, admin],
      categories: [category],
      categoryLinks: [
        ActivityCategoryLink(
          id: 'link-work-primary',
          userId: null,
          activityId: work.id,
          categoryId: category.id,
          isPrimary: true,
          sortOrder: 0,
          updatedAt: now,
          isDeleted: false,
        ),
      ],
    );

    final bucketRows = stats.groupRows(
      dimension: StatsDimension.durationBucket,
    );
    expect(bucketRows.map((row) => row.label), ['30m-1h', '<30m']);

    final mixedRows = stats.groupRows(
      dimension: StatsDimension.primaryCategoryAndDurationBucket,
    );
    expect(mixedRows.map((row) => row.label), contains('工作 / 30m-1h'));
    expect(mixedRows.map((row) => row.label), contains('未分类 / <30m'));
  });

  test('entries keep activity snapshot after activity is deleted', () async {
    final repository = await buildRepository();
    final activity = await repository.createActivity(
      name: '临时项目',
      color: 0xff0f766e,
    );

    await repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 10),
      note: '',
    );
    await repository.deleteActivity(activity);

    final entry = (await repository.entriesForDay(DateTime(2026, 1, 1))).single;
    final visibleActivities = await repository.activities();

    expect(visibleActivities.where((item) => item.id == activity.id), isEmpty);
    expect(entry.activityNameSnapshot, '临时项目');
    expect(entry.activityColorSnapshot, 0xff0f766e);
  });

  test('one-off activity is soft-deleted after stopping it', () async {
    final repository = await buildRepository();
    final activity = await repository.createActivity(
      name: '临时电话',
      color: 0xffdb2777,
      isOneOff: true,
    );

    await repository.switchToActivity(activity.id, at: DateTime(2026, 1, 1, 9));
    await repository.stopRunning(at: DateTime(2026, 1, 1, 9, 20));

    final hidden = await repository.activities();
    final allActivities = await repository.activities(includeDeleted: true);
    final oneOff = allActivities.singleWhere((item) => item.id == activity.id);
    final entry =
        (await repository.entriesForDay(DateTime(2026, 1, 1))).firstWhere(
      (item) => item.activityId == activity.id,
    );

    expect(hidden.where((item) => item.id == activity.id), isEmpty);
    expect(oneOff.isOneOff, isTrue);
    expect(oneOff.isDeleted, isTrue);
    expect(entry.activityNameSnapshot, '临时电话');
  });

  test('soft-deleted one-off activities can be suggested and restored',
      () async {
    final repository = await buildRepository();
    final activity = await repository.createActivity(
      name: '临时电话',
      color: 0xffdb2777,
      isOneOff: true,
    );

    await repository.switchToActivity(activity.id, at: DateTime(2026, 1, 1, 9));
    await repository.stopRunning(at: DateTime(2026, 1, 1, 9, 20));

    final suggestions = await repository.oneOffActivities();
    final restored = await repository.restoreOneOffActivity(
      suggestions.singleWhere((item) => item.id == activity.id),
    );
    final visibleActivities = await repository.activities();

    expect(suggestions.map((item) => item.id), contains(activity.id));
    expect(restored.isOneOff, isTrue);
    expect(restored.isDeleted, isFalse);
    expect(visibleActivities.map((item) => item.id), contains(activity.id));
  });

  test('running entry is rolled over at local midnight', () async {
    final repository = await buildRepository();
    final activity = (await repository.activities())
        .firstWhere((activity) => !activity.isUnassigned);

    final first = await repository.switchToActivity(
      activity.id,
      at: DateTime(2026, 1, 1, 23),
    );
    await repository.rolloverRunningEntriesIfNeeded(
      at: DateTime(2026, 1, 2, 1),
    );

    final firstDay = await repository.entriesForDay(DateTime(2026, 1, 1));
    final secondDay = await repository.entriesForDay(DateTime(2026, 1, 2));
    final running = await repository.runningEntry();

    expect(firstDay.single.id, first.id);
    expect(firstDay.single.endAt, DateTime(2026, 1, 2));
    expect(secondDay.single.id, running?.id);
    expect(running?.startAt, DateTime(2026, 1, 2));
    expect(running?.endAt, isNull);
  });

  test('merge candidate uses neighbor duration threshold', () async {
    final repository = await buildRepository();
    final activity = (await repository.activities())
        .firstWhere((activity) => !activity.isUnassigned);
    final previous = await repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 9, 59),
      endAt: DateTime(2026, 1, 1, 10),
      note: 'prev',
    );
    final current = await repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 10),
      endAt: DateTime(2026, 1, 1, 11),
      note: 'current',
    );

    final candidate = await repository.mergeCandidateForEntry(
      current.id,
      EntryMergeDirection.previous,
    );
    final merged = await repository.mergeEntryWithNeighbor(
      entryId: current.id,
      direction: EntryMergeDirection.previous,
      confirmed: false,
    );
    final allEntries = await repository.allEntries();
    final deletedPrevious =
        allEntries.singleWhere((entry) => entry.id == previous.id);

    expect(candidate?.neighborDuration, const Duration(minutes: 1));
    expect(candidate?.requiresConfirmation, isFalse);
    expect(merged?.startAt, DateTime(2026, 1, 1, 9, 59));
    expect(merged?.endAt, DateTime(2026, 1, 1, 11));
    expect(merged?.note, 'current\nprev');
    expect(deletedPrevious.isDeleted, isTrue);
  });

  test('merge requires confirmation when neighbor exceeds threshold', () async {
    final repository = await buildRepository();
    final activity = (await repository.activities())
        .firstWhere((activity) => !activity.isUnassigned);
    final current = await repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 10),
      endAt: DateTime(2026, 1, 1, 11),
      note: '',
    );
    await repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 11),
      endAt: DateTime(2026, 1, 1, 11, 2),
      note: '',
    );

    final candidate = await repository.mergeCandidateForEntry(
      current.id,
      EntryMergeDirection.next,
    );

    expect(candidate?.neighborDuration, const Duration(minutes: 2));
    expect(candidate?.requiresConfirmation, isTrue);
    await expectLater(
      repository.mergeEntryWithNeighbor(
        entryId: current.id,
        direction: EntryMergeDirection.next,
        confirmed: false,
      ),
      throwsStateError,
    );

    final merged = await repository.mergeEntryWithNeighbor(
      entryId: current.id,
      direction: EntryMergeDirection.next,
      confirmed: true,
    );
    expect(merged?.startAt, DateTime(2026, 1, 1, 10));
    expect(merged?.endAt, DateTime(2026, 1, 1, 11, 2));
  });

  test('profile settings store reminder cadence and delivery method', () async {
    final settings = ProfileSettings.defaults().copyWith(
      reminderMinutes: 30,
      reminderIntervalMinutes: 12,
      reminderMethod: ReminderMethod.dialog,
      reminderTimeOfDayMinutes: 9 * 60,
      mergeNeighborThresholdMinutes: 7,
      updatedAt: DateTime(2026, 1, 1, 8),
    );

    expect(settings.toLocalMap()['reminder_interval_minutes'], 12);
    expect(settings.toLocalMap()['reminder_method'], 'dialog');
    expect(settings.toLocalMap()['reminder_time_of_day_minutes'], 540);
    expect(settings.toLocalMap()['merge_neighbor_threshold_minutes'], 7);
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
    final activityRepository = ActivityRepository(database: database);
    final settingsRepository = SettingsRepository(database: database);
    final deviceIdStore = DeviceIdStore(database: database);
    final timeEntryRepository = TimeEntryRepository(
      database: database,
      activityRepository: activityRepository,
    );
    final actionLogRepository = ActionLogRepository(database: database);
    final repository = TimeRepository(
      database: database,
      activityRepository: activityRepository,
      settingsRepository: settingsRepository,
      deviceIdStore: deviceIdStore,
      timeEntryRepository: timeEntryRepository,
      actionLogRepository: actionLogRepository,
    );

    final settings = await repository.settings();

    expect(settings.reminderMinutes, 50);
    expect(settings.reminderIntervalMinutes, 10);
    expect(settings.reminderMethod, ReminderMethod.dialog);
    expect(settings.reminderTimeOfDayMinutes, 9 * 60);
    expect(settings.mergeNeighborThresholdMinutes, 1);
  });

  test('entry snapshot and one-off migration fills new columns', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute('''
      create table activities (
        id text primary key,
        user_id text,
        name text not null,
        color integer not null,
        is_favorite integer not null default 1,
        updated_at text not null,
        is_deleted integer not null default 0,
        is_unassigned integer not null default 0
      )
    ''');
    await db.execute('''
      create table time_entries (
        id text primary key,
        user_id text,
        activity_id text not null,
        start_at text not null,
        end_at text,
        note text not null default '',
        device_id text not null,
        updated_at text not null,
        is_deleted integer not null default 0
      )
    ''');
    await db.execute('''
      create table profile_settings (
        id integer primary key check (id = 1),
        user_id text,
        reminder_minutes integer not null default 45,
        reminder_interval_minutes integer not null default 10,
        reminder_method text not null default 'dialog',
        reminder_time_of_day_minutes integer not null default 540,
        timezone text not null,
        updated_at text not null
      )
    ''');

    await LocalDatabase.migrateEntrySnapshotsAndOneOffSchema(db);
    final activityColumns = await db.rawQuery('pragma table_info(activities)');
    final entryColumns = await db.rawQuery('pragma table_info(time_entries)');
    final settingsColumns =
        await db.rawQuery('pragma table_info(profile_settings)');

    expect(activityColumns.map((row) => row['name']), contains('is_one_off'));
    expect(entryColumns.map((row) => row['name']), contains('activity_name'));
    expect(entryColumns.map((row) => row['name']), contains('activity_color'));
    expect(
      settingsColumns.map((row) => row['name']),
      contains('merge_neighbor_threshold_minutes'),
    );
  });
}
