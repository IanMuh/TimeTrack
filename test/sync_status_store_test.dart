import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/sync_status_store.dart';

void main() {
  test('sync status persists success and clears previous failure', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(db.close);
    await LocalDatabase.createSchema(db);
    final database = LocalDatabase(database: db);
    final store = SyncStatusStore(database: database);

    await store.markFailure(error: 'network down', target: 'lan');
    final firstFailure = await store.load();
    expect(firstFailure.lastError, 'network down');
    expect(firstFailure.lastTarget, 'lan');

    final successAt = DateTime.utc(2026, 6, 24, 8, 30);
    await store.markSuccess(at: successAt, target: 'cloud_lan');
    final reloaded = await SyncStatusStore(database: database).load();

    expect(reloaded.lastSuccessfulSyncAt?.toUtc(), successAt);
    expect(reloaded.lastError, isNull);
    expect(reloaded.lastTarget, 'cloud_lan');
  });

  test('sync failure keeps the previous successful timestamp', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(db.close);
    await LocalDatabase.createSchema(db);
    final database = LocalDatabase(database: db);
    final store = SyncStatusStore(database: database);
    final successAt = DateTime.utc(2026, 6, 24, 8, 30);

    await store.markSuccess(at: successAt, target: 'cloud');
    await store.markFailure(error: 'timeout', target: 'cloud');
    final reloaded = await store.load();

    expect(reloaded.lastSuccessfulSyncAt?.toUtc(), successAt);
    expect(reloaded.lastError, 'timeout');
    expect(reloaded.lastTarget, 'cloud');
  });
}
