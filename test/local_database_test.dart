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

  test('file database startup config does not fail on wal setup', () async {
    final directory = await Directory.systemTemp.createTemp(
      'timetrack_local_database_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final database = LocalDatabase(
      databasePath: p.join(directory.path, 'timetrack.sqlite'),
    );
    final db = await database.db;
    addTearDown(db.close);

    final tables = await _tableNames(db);
    final foreignKeys = await db.rawQuery('PRAGMA foreign_keys');

    expect(
      tables,
      containsAll(<String>{
        'activities',
        'time_entries',
        'profile_settings',
        'action_logs',
        'sync_peers',
        'app_metadata',
      }),
    );
    expect((foreignKeys.single['foreign_keys'] as num).toInt(), 1);
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

    expect(tables, containsAll(<String>{'action_logs', 'sync_peers'}));
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
