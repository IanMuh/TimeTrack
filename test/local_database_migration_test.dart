import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timetrack/data/local_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('opening version 7 drifted database repairs schema without data loss',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'timetrack_drifted_database_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final dbPath = p.join(directory.path, 'timetrack.sqlite');

    final legacyDb = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await _createVersionSevenDriftedSchema(legacyDb);
    await legacyDb.close();

    final database = LocalDatabase(databasePath: dbPath);
    final db = await database.db;
    addTearDown(db.close);

    final tables = await _tableNames(db);
    final activityColumns = await _columnNames(db, 'activities');
    final entryColumns = await _columnNames(db, 'time_entries');
    final settingsColumns = await _columnNames(db, 'profile_settings');
    final activityRows = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: const ['legacy-activity'],
    );

    expect(
      tables,
      containsAll(<String>{
        'action_logs',
        'activity_categories',
        'activity_category_links',
        'sync_peers',
      }),
    );
    expect(tables, contains('app_metadata'));
    expect(
        activityColumns, containsAll(<String>['is_unassigned', 'is_one_off']));
    expect(
        entryColumns, containsAll(<String>['activity_name', 'activity_color']));
    expect(
      settingsColumns,
      containsAll(<String>[
        'reminder_interval_minutes',
        'reminder_method',
        'reminder_time_of_day_minutes',
        'merge_neighbor_threshold_minutes',
      ]),
    );
    expect(activityRows.single['name'], 'Legacy');
  });

  test('opening version 8 database adds performance indexes without data loss',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'timetrack_v8_database_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final dbPath = p.join(directory.path, 'timetrack.sqlite');

    final legacyDb = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await LocalDatabase.createSchema(legacyDb);
    for (final index in _performanceIndexes) {
      await legacyDb.execute('drop index if exists $index');
    }
    await legacyDb.insert('activities', {
      'id': 'v8-activity',
      'user_id': null,
      'name': 'Version 8',
      'color': 0xff22c55e,
      'is_favorite': 1,
      'updated_at': DateTime(2026, 2, 1).toIso8601String(),
      'is_deleted': 0,
      'is_unassigned': 0,
      'is_one_off': 0,
    });
    await legacyDb.execute('PRAGMA user_version = 8');
    await legacyDb.close();

    final database = LocalDatabase(databasePath: dbPath);
    final db = await database.db;
    addTearDown(db.close);

    final indexes = await _indexNames(db);
    final activityRows = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: const ['v8-activity'],
    );

    expect(indexes, containsAll(_performanceIndexes));
    expect(activityRows.single['name'], 'Version 8');
  });

  test(
      'opening version 9 drifted database repairs schema during v10 upgrade '
      'without data loss', () async {
    final directory = await Directory.systemTemp.createTemp(
      'timetrack_v9_database_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final dbPath = p.join(directory.path, 'timetrack.sqlite');

    final legacyDb = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await LocalDatabase.createSchema(legacyDb);
    for (final index in _performanceIndexes) {
      await legacyDb.execute('drop index if exists $index');
    }
    await legacyDb.insert('activities', {
      'id': 'v9-activity',
      'user_id': null,
      'name': 'Version 9',
      'color': 0xff22c55e,
      'is_favorite': 1,
      'updated_at': DateTime(2026, 3, 1).toIso8601String(),
      'is_deleted': 0,
      'is_unassigned': 0,
      'is_one_off': 0,
    });
    await legacyDb.execute('PRAGMA user_version = 9');
    await legacyDb.close();

    final database = LocalDatabase(databasePath: dbPath);
    final db = await database.db;
    addTearDown(db.close);

    final indexes = await _indexNames(db);
    final activityRows = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: const ['v9-activity'],
    );

    expect(indexes, containsAll(_performanceIndexes));
    expect(activityRows.single['name'], 'Version 9');
  });

  test('versioned upgrades guard legacy drift repair behind schema detection',
      () {
    final source = File('lib/data/local_database.dart').readAsStringSync();
    final upgradeBody = _methodBody(source, '_upgrade');
    final ensureBody = _methodBody(source, 'ensureSchema');

    expect(source, contains('version: 10,'));
    expect(
      source,
      contains('Future<bool> _repairLegacySchemaDriftIfNeeded('),
    );
    expect(upgradeBody, contains('if (oldVersion < 10)'));
    expect(
      upgradeBody,
      contains('if (oldVersion < 9 && !repairedLegacyDrift)'),
    );
    expect(upgradeBody, contains('await createPerformanceIndexes(db);'));
    expect(
      upgradeBody,
      contains('await _repairLegacySchemaDriftIfNeeded(db);'),
    );
    expect(
      ensureBody,
      isNot(contains('await _repairLegacySchemaDriftIfNeeded(db);')),
    );
    expect(upgradeBody, isNot(contains('await repairLegacySchemaDrift(db);')));
    expect(ensureBody, isNot(contains('await repairLegacySchemaDrift(db);')));
  });
}

Future<Set<String>> _tableNames(Database db) async {
  final rows = await db.rawQuery(
    "select name from sqlite_master where type = 'table'",
  );
  return {
    for (final row in rows)
      if (row['name'] case final String name) name,
  };
}

Future<List<String>> _columnNames(Database db, String table) async {
  final rows = await db.rawQuery('pragma table_info($table)');
  return [
    for (final row in rows)
      if (row['name'] case final String name) name,
  ];
}

Future<Set<String>> _indexNames(Database db) async {
  final rows = await db.rawQuery(
    "select name from sqlite_master where type = 'index'",
  );
  return {
    for (final row in rows)
      if (row['name'] case final String name) name,
  };
}

const _performanceIndexes = <String>{
  'idx_time_entries_active_start',
  'idx_time_entries_active_end',
  'idx_time_entries_running_active',
  'idx_action_logs_active_occurred_at',
  'idx_activities_active_sort',
  'idx_activity_category_links_active_sort',
};

String _methodBody(String source, String methodName) {
  final signatureIndex = source.indexOf('$methodName(');
  expect(signatureIndex, isNonNegative);
  final openBrace = source.indexOf('{', signatureIndex);
  expect(openBrace, isNonNegative);

  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
    }
    if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(openBrace + 1, index);
      }
    }
  }
  fail('Could not parse $methodName body');
}

Future<void> _createVersionSevenDriftedSchema(Database db) async {
  await db.execute('''
    create table activities (
      id text primary key,
      user_id text,
      name text not null,
      color integer not null,
      is_favorite integer not null default 1,
      updated_at text not null,
      is_deleted integer not null default 0
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
      timezone text not null,
      updated_at text not null
    )
  ''');
  await db.insert('activities', {
    'id': 'legacy-activity',
    'user_id': null,
    'name': 'Legacy',
    'color': 0xff2563eb,
    'is_favorite': 1,
    'updated_at': DateTime(2026, 1, 1).toIso8601String(),
    'is_deleted': 0,
  });
  await db.execute('PRAGMA user_version = 7');
}
