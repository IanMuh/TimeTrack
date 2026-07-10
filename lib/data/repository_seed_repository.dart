import 'package:sqflite/sqflite.dart';

import '../domain/profile_settings.dart';
import 'activity_repository.dart';
import 'local_database.dart';
import 'settings_repository.dart';
import 'time_entry_repository.dart';

class RepositorySeedRepository {
  const RepositorySeedRepository({
    required LocalDatabase database,
    required ActivityRepository activityRepository,
    required SettingsRepository settingsRepository,
    required TimeEntryRepository timeEntryRepository,
  })  : _database = database,
        _activityRepo = activityRepository,
        _settingsRepo = settingsRepository,
        _entryRepo = timeEntryRepository;

  final LocalDatabase _database;
  final ActivityRepository _activityRepo;
  final SettingsRepository _settingsRepo;
  final TimeEntryRepository _entryRepo;

  Future<void> ensureSeedData() async {
    final db = await _database.db;
    final unassigned = await _activityRepo.ensureUnassignedActivity();
    await _entryRepo.mergeAdjacentUnassignedEntries(unassigned.id);
    await _entryRepo.normalizeStoredCrossDayEntries();
    await _entryRepo.rolloverRunningEntriesIfNeeded();
    await _entryRepo.backfillMissingEntrySnapshots();

    final seeded = Sqflite.firstIntValue(
      await db.rawQuery(
        "select count(*) from app_metadata where key = 'seeded' and value = '1'",
      ),
    );
    if (seeded == 1) {
      return;
    }

    await _activityRepo.seedActivities();

    final settingsCount = Sqflite.firstIntValue(
      await db.rawQuery('select count(*) from profile_settings'),
    );
    if (settingsCount == 0) {
      await _settingsRepo.saveSettingsRaw(ProfileSettings.defaults());
    }

    await db.insert(
      'app_metadata',
      {'key': 'seeded', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
