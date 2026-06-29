import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalDatabase {
  LocalDatabase({
    Database? database,
    String? databasePath,
  })  : assert(database == null || databasePath == null),
        _database = database,
        _databasePath = databasePath;

  Database? _database;
  final String? _databasePath;

  Future<Database> get db async {
    if (_database != null) {
      return _database!;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = _databasePath ?? await _defaultDatabasePath();
    final db = await openDatabase(
      dbPath,
      version: 9,
      onConfigure: _configure,
      onCreate: _create,
      onUpgrade: _upgrade,
      onOpen: _open,
    );
    _database = db;
    return db;
  }

  Future<String> _defaultDatabasePath() async {
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'timetrack.sqlite');
  }

  Future<void> _configure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await _tryEnableWal(db);
    await _tryApplyPerformancePragmas(db);
  }

  Future<void> _open(Database db) async {
    await ensureSchema(db);
  }

  Future<void> _create(Database db, int version) async {
    await createSchema(db);
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await createActionLogsSchema(db);
    }
    if (oldVersion < 3) {
      await createSyncPeerSchema(db);
    }
    if (oldVersion < 4) {
      await createAppMetadataSchema(db);
    }
    if (oldVersion < 5) {
      await migrateProfileSettingsReminderSchema(db);
    }
    if (oldVersion < 6) {
      await migrateUnassignedActivitySchema(db);
    }
    if (oldVersion < 7) {
      await migrateEntrySnapshotsAndOneOffSchema(db);
    }
    if (oldVersion < 8) {
      await createActivityCategorySchema(db);
    }
    if (oldVersion < 9) {
      await createActionLogsSchema(db);
      await createActivityCategorySchema(db);
      await createPerformanceIndexes(db);
    }
  }

  static Future<void> ensureSchema(Database db) async {
    await createSchema(db);
    await migrateProfileSettingsReminderSchema(db);
    await migrateUnassignedActivitySchema(db);
    await migrateEntrySnapshotsAndOneOffSchema(db);
    await createActivityCategorySchema(db);
    await createPerformanceIndexes(db);
  }

  static Future<void> createSchema(Database db) async {
    await db.execute('''
      create table if not exists activities (
        id text primary key,
        user_id text,
        name text not null,
        color integer not null,
        is_favorite integer not null default 1,
        updated_at text not null,
        is_deleted integer not null default 0,
        is_unassigned integer not null default 0,
        is_one_off integer not null default 0
      )
    ''');

    await db.execute('''
      create table if not exists time_entries (
        id text primary key,
        user_id text,
        activity_id text not null,
        activity_name text not null default '',
        activity_color integer,
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
      create table if not exists profile_settings (
        id integer primary key check (id = 1),
        user_id text,
        reminder_minutes integer not null default 45,
        reminder_interval_minutes integer not null default 10,
        reminder_method text not null default 'dialog',
        reminder_time_of_day_minutes integer not null default 540,
        merge_neighbor_threshold_minutes integer not null default 1,
        timezone text not null,
        updated_at text not null
      )
    ''');

    await db.execute(
      'create index if not exists idx_time_entries_start_at on time_entries(start_at)',
    );
    await db.execute(
      'create index if not exists idx_time_entries_updated_at on time_entries(updated_at)',
    );
    await db.execute(
      'create index if not exists idx_activities_updated_at on activities(updated_at)',
    );
    await db.execute(
      'create index if not exists idx_time_entries_activity_id on time_entries(activity_id)',
    );

    await createActionLogsSchema(db);
    await createSyncPeerSchema(db);
    await createAppMetadataSchema(db);
    await createActivityCategorySchema(db);
    await createPerformanceIndexes(db);
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

  static Future<void> createPerformanceIndexes(Database db) async {
    await db.execute(
      'create index if not exists idx_time_entries_active_start '
      'on time_entries(is_deleted, start_at)',
    );
    await db.execute(
      'create index if not exists idx_time_entries_active_end '
      'on time_entries(is_deleted, end_at)',
    );
    await db.execute(
      'create index if not exists idx_time_entries_running_active '
      'on time_entries(start_at) '
      'where end_at is null and is_deleted = 0',
    );
    await db.execute(
      'create index if not exists idx_action_logs_active_occurred_at '
      'on action_logs(is_deleted, occurred_at)',
    );
    await db.execute(
      'create index if not exists idx_activities_active_sort '
      'on activities(is_deleted, is_favorite, name)',
    );
    await db.execute(
      'create index if not exists idx_activity_category_links_active_sort '
      'on activity_category_links(activity_id, is_deleted, is_primary, sort_order)',
    );
  }

  static Future<void> createSyncPeerSchema(Database db) async {
    await db.execute('''
      create table if not exists sync_peers (
        id text primary key,
        kind text not null,
        display_name text not null,
        base_url text,
        token text not null,
        updated_at text not null
      )
    ''');

    await db.execute(
      'create index if not exists idx_sync_peers_kind on sync_peers(kind)',
    );
  }

  static Future<void> createAppMetadataSchema(Database db) async {
    await db.execute('''
      create table if not exists app_metadata (
        key text primary key,
        value text not null
      )
    ''');
  }

  static Future<void> createActivityCategorySchema(Database db) async {
    await db.execute('''
      create table if not exists activity_categories (
        id text primary key,
        user_id text,
        name text not null,
        color integer not null,
        updated_at text not null,
        is_deleted integer not null default 0
      )
    ''');

    await db.execute('''
      create table if not exists activity_category_links (
        id text primary key,
        user_id text,
        activity_id text not null,
        category_id text not null,
        is_primary integer not null default 0,
        sort_order integer not null default 0,
        updated_at text not null,
        is_deleted integer not null default 0,
        foreign key (activity_id) references activities(id),
        foreign key (category_id) references activity_categories(id)
      )
    ''');

    await db.execute(
      'create index if not exists idx_activity_categories_updated_at '
      'on activity_categories(updated_at)',
    );
    await db.execute(
      'create index if not exists idx_activity_category_links_activity_id '
      'on activity_category_links(activity_id)',
    );
    await db.execute(
      'create index if not exists idx_activity_category_links_category_id '
      'on activity_category_links(category_id)',
    );
    await db.execute(
      'create index if not exists idx_activity_category_links_updated_at '
      'on activity_category_links(updated_at)',
    );
  }

  static Future<void> migrateProfileSettingsReminderSchema(Database db) async {
    await _addColumnIfMissing(
      db,
      table: 'profile_settings',
      column: 'reminder_interval_minutes',
      definition: 'integer not null default 10',
    );
    await _addColumnIfMissing(
      db,
      table: 'profile_settings',
      column: 'reminder_method',
      definition: "text not null default 'dialog'",
    );
    await _addColumnIfMissing(
      db,
      table: 'profile_settings',
      column: 'reminder_time_of_day_minutes',
      definition: 'integer not null default 540',
    );
  }

  static Future<void> migrateUnassignedActivitySchema(Database db) async {
    await _addColumnIfMissing(
      db,
      table: 'activities',
      column: 'is_unassigned',
      definition: 'integer not null default 0',
    );
  }

  static Future<void> migrateEntrySnapshotsAndOneOffSchema(Database db) async {
    await _addColumnIfMissing(
      db,
      table: 'activities',
      column: 'is_one_off',
      definition: 'integer not null default 0',
    );
    await _addColumnIfMissing(
      db,
      table: 'time_entries',
      column: 'activity_name',
      definition: "text not null default ''",
    );
    await _addColumnIfMissing(
      db,
      table: 'time_entries',
      column: 'activity_color',
      definition: 'integer',
    );
    await _addColumnIfMissing(
      db,
      table: 'profile_settings',
      column: 'merge_neighbor_threshold_minutes',
      definition: 'integer not null default 1',
    );
  }

  static Future<void> _addColumnIfMissing(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('pragma table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('alter table $table add column $column $definition');
    }
  }

  static Future<void> _tryEnableWal(Database db) async {
    try {
      await db.rawQuery('PRAGMA journal_mode = WAL');
    } on DatabaseException {
      // WAL is an optimization. Keep local startup available when a platform
      // SQLite build or transient lock cannot switch journal mode.
    }
  }

  static Future<void> _tryApplyPerformancePragmas(Database db) async {
    try {
      await db.execute('PRAGMA synchronous = NORMAL');
      await db.execute('PRAGMA cache_size = -10000');
      await db.execute('PRAGMA temp_store = MEMORY');
    } on DatabaseException {
      // These pragmas only tune local performance. Keep startup available on
      // SQLite builds that reject one of them.
    }
  }
}
