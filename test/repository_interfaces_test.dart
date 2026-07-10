import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/core/result.dart';
import 'package:timetrack/data/repository_interfaces.dart';
import 'package:timetrack/data/sync_service.dart';
import 'package:timetrack/domain/action_log.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/activity_category.dart';
import 'package:timetrack/domain/profile_settings.dart';
import 'package:timetrack/domain/time_entry.dart';

import 'test_fixtures.dart';

void main() {
  test('SyncService depends on sync-only repository capabilities', () {
    final activityRepository = _ActivitySyncOnly();
    final categoryRepository = _CategorySyncOnly();
    final settingsRepository = _SettingsSyncOnly();
    final entryRepository = _EntrySyncOnly();
    final actionLogRepository = _ActionLogSyncOnly();

    final service = SyncService(
      activityRepository: activityRepository,
      activityCategoryRepository: categoryRepository,
      settingsRepository: settingsRepository,
      timeEntryRepository: entryRepository,
      actionLogRepository: actionLogRepository,
      client: null,
    );

    expect(service.isCloudEnabled, isFalse);
    expect(service.isEnabled, isFalse);
    expect(activityRepository, isNot(isA<IActivityRepository>()));
    expect(categoryRepository, isNot(isA<IActivityCategoryRepository>()));
    expect(settingsRepository, isNot(isA<ISettingsRepository>()));
    expect(entryRepository, isNot(isA<ITimeEntryRepository>()));
    expect(actionLogRepository, isNot(isA<IActionLogRepository>()));
  });

  test('concrete repositories expose focused capabilities, not aggregate ones',
      () async {
    final fixture = await buildTestRepositoryFixture(seedData: false);
    addTearDown(fixture.close);

    expect(fixture.activityRepository, isA<IActivityCatalogRepository>());
    expect(fixture.activityRepository, isA<IActivityCommandRepository>());
    expect(fixture.activityRepository, isA<IActivitySyncRepository>());
    expect(fixture.activityRepository, isNot(isA<IActivityRepository>()));

    expect(
      fixture.activityCategoryRepository,
      isA<IActivityCategoryCatalogRepository>(),
    );
    expect(
      fixture.activityCategoryRepository,
      isA<IActivityCategoryCommandRepository>(),
    );
    expect(
      fixture.activityCategoryRepository,
      isA<IActivityCategorySyncRepository>(),
    );
    expect(
      fixture.activityCategoryRepository,
      isNot(isA<IActivityCategoryRepository>()),
    );

    expect(fixture.settingsRepository, isA<ISettingsReadRepository>());
    expect(fixture.settingsRepository, isA<ISettingsWriteRepository>());
    expect(fixture.settingsRepository, isA<ISettingsSyncRepository>());
    expect(fixture.settingsRepository, isNot(isA<ISettingsRepository>()));

    expect(fixture.timeEntryRepository, isA<ITimeEntryQueryRepository>());
    expect(fixture.timeEntryRepository, isA<ITimeEntryCommandRepository>());
    expect(fixture.timeEntryRepository, isA<ITimeEntrySyncRepository>());
    expect(fixture.timeEntryRepository, isNot(isA<ITimeEntryRepository>()));

    expect(fixture.actionLogRepository, isA<IActionLogQueryRepository>());
    expect(fixture.actionLogRepository, isA<IActionLogCommandRepository>());
    expect(fixture.actionLogRepository, isA<IActionLogSyncRepository>());
    expect(fixture.actionLogRepository, isNot(isA<IActionLogRepository>()));
  });
}

class _ActivitySyncOnly implements IActivitySyncRepository {
  @override
  Future<AppResult<List<Activity>>> activitiesSince(DateTime since) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<void>> replaceActivityIfRemoteNewer(Activity remote) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<void>> upsertActivity(Activity activity) async {
    return const AppSuccess(null);
  }
}

class _CategorySyncOnly implements IActivityCategorySyncRepository {
  @override
  Future<AppResult<List<ActivityCategory>>> categoriesSince(
    DateTime since,
  ) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<List<ActivityCategoryLink>>> categoryLinksSince(
    DateTime since,
  ) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<void>> replaceCategoryIfRemoteNewer(
    ActivityCategory remote,
  ) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<void>> replaceCategoryLinkIfRemoteNewer(
    ActivityCategoryLink remote,
  ) async {
    return const AppSuccess(null);
  }
}

class _SettingsSyncOnly implements ISettingsSyncRepository {
  @override
  Future<AppResult<ProfileSettings>> settings() async {
    return AppSuccess(ProfileSettings.defaults());
  }

  @override
  Future<AppResult<void>> replaceSettingsIfRemoteNewer(
    ProfileSettings remote,
  ) async {
    return const AppSuccess(null);
  }
}

class _EntrySyncOnly implements ITimeEntrySyncRepository {
  @override
  Future<AppResult<List<TimeEntry>>> entriesSince(DateTime since) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<void>> replaceEntryIfRemoteNewer(TimeEntry remote) async {
    return const AppSuccess(null);
  }
}

class _ActionLogSyncOnly implements IActionLogSyncRepository {
  @override
  Future<AppResult<List<ActionLog>>> actionLogsSince(DateTime since) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<void>> replaceActionLogIfRemoteNewer(
      ActionLog remote) async {
    return const AppSuccess(null);
  }
}
