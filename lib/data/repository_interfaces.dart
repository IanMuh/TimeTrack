import '../core/result.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/activity_category.dart';
import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';

abstract class IActivityCatalogRepository {
  Future<AppResult<List<Activity>>> activities({
    bool includeDeleted = false,
  });

  Future<AppResult<List<Activity>>> oneOffActivities({
    bool includeDeleted = true,
  });

  Future<AppResult<Activity>> unassignedActivity();
}

abstract class IActivityCommandRepository {
  Future<AppResult<Activity>> createActivity({
    required String name,
    required int color,
    String? userId,
    bool isOneOff = false,
  });

  Future<AppResult<Activity>> updateActivity({
    required Activity activity,
    required String name,
    required int color,
  });

  Future<AppResult<Activity>> restoreOneOffActivity(Activity activity);

  Future<AppResult<void>> deleteActivity(Activity activity);
}

abstract class IActivitySyncRepository {
  Future<AppResult<void>> upsertActivity(Activity activity);

  Future<AppResult<void>> replaceActivityIfRemoteNewer(Activity remote);

  Future<AppResult<List<Activity>>> activitiesSince(DateTime since);
}

abstract class IActivityRepository
    implements
        IActivityCatalogRepository,
        IActivityCommandRepository,
        IActivitySyncRepository {}

abstract class ISettingsReadRepository {
  Future<AppResult<ProfileSettings>> settings();
}

abstract class ISettingsWriteRepository {
  Future<AppResult<void>> saveSettings(ProfileSettings settings);
}

abstract class ISettingsSyncRepository implements ISettingsReadRepository {
  Future<AppResult<void>> replaceSettingsIfRemoteNewer(ProfileSettings remote);
}

abstract class ISettingsRepository
    implements
        ISettingsReadRepository,
        ISettingsWriteRepository,
        ISettingsSyncRepository {}

abstract class IActivityCategoryCatalogRepository {
  Future<AppResult<List<ActivityCategory>>> categories({
    bool includeDeleted = false,
  });

  Future<AppResult<List<ActivityCategoryLink>>> activityCategoryLinks({
    bool includeDeleted = false,
  });

  Future<AppResult<List<ActivityCategoryLink>>> linksForActivity(
    String activityId, {
    bool includeDeleted = false,
  });
}

abstract class IActivityCategoryCommandRepository {
  Future<AppResult<ActivityCategory>> createCategory({
    required String name,
    required int color,
    String? userId,
  });

  Future<AppResult<ActivityCategory>> updateCategory({
    required ActivityCategory category,
    required String name,
    required int color,
  });

  Future<AppResult<void>> deleteCategory(ActivityCategory category);

  Future<AppResult<List<ActivityCategoryLink>>> setActivityCategories({
    required String activityId,
    required String? primaryCategoryId,
    required List<String> secondaryCategoryIds,
    String? userId,
  });
}

abstract class IActivityCategorySyncRepository {
  Future<AppResult<List<ActivityCategory>>> categoriesSince(DateTime since);

  Future<AppResult<List<ActivityCategoryLink>>> categoryLinksSince(
    DateTime since,
  );

  Future<AppResult<void>> replaceCategoryIfRemoteNewer(
    ActivityCategory remote,
  );

  Future<AppResult<void>> replaceCategoryLinkIfRemoteNewer(
    ActivityCategoryLink remote,
  );
}

abstract class IActivityCategoryRepository
    implements
        IActivityCategoryCatalogRepository,
        IActivityCategoryCommandRepository,
        IActivityCategorySyncRepository {}

abstract class IDeviceIdStore {
  Future<String> currentDeviceId();
}

// ---------------------------------------------------------------------------
// Entry merge types (extracted from TimeRepository)
// ---------------------------------------------------------------------------

enum EntryMergeDirection { previous, next }

class EntryMergeCandidate {
  const EntryMergeCandidate({
    required this.current,
    required this.neighbor,
    required this.direction,
    required this.neighborDuration,
    required this.threshold,
  });

  final TimeEntry current;
  final TimeEntry neighbor;
  final EntryMergeDirection direction;
  final Duration neighborDuration;
  final Duration threshold;

  bool get requiresConfirmation => neighborDuration > threshold;
}

// ---------------------------------------------------------------------------
// ITimeEntryRepository
// ---------------------------------------------------------------------------

abstract class ITimeEntryQueryRepository {
  Future<AppResult<TimeEntry?>> runningEntry();

  Future<AppResult<List<TimeEntry>>> entriesForDay(DateTime day);

  Future<AppResult<List<TimeEntry>>> entriesForRange(
    DateTime start,
    DateTime end,
  );

  Future<AppResult<List<TimeEntry>>> allEntries();

  Future<AppResult<EntryMergeCandidate?>> mergeCandidateForEntry(
    String entryId,
    EntryMergeDirection direction,
  );

  Future<AppResult<List<TimeEntry>>> overlappingEntries(TimeEntry entry);
}

abstract class ITimeEntryCommandRepository {
  Future<AppResult<TimeEntry>> switchToActivity(
    String activityId, {
    DateTime? at,
  });

  Future<AppResult<void>> stopRunning({DateTime? at});

  Future<AppResult<List<TimeEntry>>> saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  });

  Future<AppResult<List<TimeEntry>>> splitEntry({
    required String entryId,
    required DateTime splitAt,
  });

  Future<AppResult<TimeEntry>> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
    String? userId,
  });

  Future<AppResult<void>> deleteEntry(TimeEntry entry);

  Future<AppResult<TimeEntry?>> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  });
}

abstract class ITimeEntrySyncRepository {
  Future<AppResult<List<TimeEntry>>> entriesSince(DateTime since);
  Future<AppResult<void>> replaceEntryIfRemoteNewer(TimeEntry remote);
}

abstract class ITimeEntryRepository
    implements
        ITimeEntryQueryRepository,
        ITimeEntryCommandRepository,
        ITimeEntrySyncRepository {}

// ---------------------------------------------------------------------------
// IActionLogRepository
// ---------------------------------------------------------------------------

abstract class IActionLogQueryRepository {
  Future<AppResult<List<ActionLog>>> actionLogsForDay(DateTime day);

  Future<AppResult<List<ActionLog>>> actionLogsForRange(
    DateTime start,
    DateTime end,
  );

  Future<AppResult<List<ActionLog>>> allActionLogs();
}

abstract class IActionLogCommandRepository {
  Future<AppResult<void>> addActionLog({
    required ActionType actionType,
    required String? activityId,
    required String? entryId,
    required DateTime occurredAt,
    required String message,
  });
}

abstract class IActionLogSyncRepository {
  Future<AppResult<List<ActionLog>>> actionLogsSince(DateTime since);
  Future<AppResult<void>> replaceActionLogIfRemoteNewer(ActionLog remote);
}

abstract class IActionLogRepository
    implements
        IActionLogQueryRepository,
        IActionLogCommandRepository,
        IActionLogSyncRepository {}
