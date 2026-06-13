import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalDatabase {
  LocalDatabase({Database? database}) : _database = database;

  Database? _database;

  Future<Database> get db async {
    if (_database != null) {
      return _database!;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final appDir = await getApplicationSupportDirectory();
    final dbPath = p.join(appDir.path, 'timetrack.sqlite');
    _database = await openDatabase(
      dbPath,
      version: 2,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _database!;
  }

  Future<void> _create(Database db, int version) async {
    await createSchema(db);
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await createActionLogsSchema(db);
    }
  }

  static Future<void> createSchema(Database db) async {
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
        is_deleted integer not null default 0,
        foreign key (activity_id) references activities(id)
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

    await db.execute(
      'create index idx_time_entries_start_at on time_entries(start_at)',
    );
    await db.execute(
      'create index idx_time_entries_updated_at on time_entries(updated_at)',
    );

    await createActionLogsSchema(db);
  }

  static Future<void> createActionLogsSchema(Database db) async {
    await db.execute('''
      create table if not exists action_logs (
        id text primary key,
        user_id text,
        action_type text not null,
        activity_id text,
        entry_id text,
        message text not null,
        occurred_at text not null,
        device_id text not null,
        updated_at text not null,
        is_deleted integer not null default 0
      )
    ''');

    await db.execute(
      'create index if not exists idx_action_logs_occurred_at on action_logs(occurred_at)',
    );
    await db.execute(
      'create index if not exists idx_action_logs_updated_at on action_logs(updated_at)',
    );
  }
}
