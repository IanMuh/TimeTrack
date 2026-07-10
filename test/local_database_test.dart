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
        'activity_categories',
        'activity_category_links',
        'time_entries',
        'profile_settings',
        'action_logs',
        'sync_peers',
        'app_metadata',
      }),
    );
    expect((foreignKeys.single['foreign_keys'] as num).toInt(), 1);
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
