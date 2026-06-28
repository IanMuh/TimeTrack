import '../core/result.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/activity_category.dart';
import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';

abstract class IActivityRepository {
  Future<AppResult<List<Activity>>> activities({
    bool includeDeleted = false,
  });

  Future<AppResult<List<Activity>>> oneOffActivities({
    bool includeDeleted = true,
  });

  Future<AppResult<Activity>> unassignedActivity();

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

  Future<AppResult<void>> upsertActivity(Activity activity);

  Future<AppResult<void>> replaceActivityIfRemoteNewer(Activity remote);

  Future<AppResult<List<Activity>>> activitiesSince(DateTime since);
}

abstract class ISettingsRepository {
  Future<AppResult<ProfileSettings>> settings();

  Future<AppResult<void>> saveSettings(ProfileSettings settings);

  Future<AppResult<void>> replaceSettingsIfRemoteNewer(ProfileSettings remote);
}

abstract class IActivityCategoryRepository {
  Future<AppResult<List<ActivityCategory>>> categories({
    bool includeDeleted = false,
  });

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

  Future<AppResult<List<ActivityCategoryLink>>> activityCategoryLinks({
    bool includeDeleted = false,
  });

  Future<AppResult<List<ActivityCategoryLink>>> linksForActivity(
    String activityId, {
    bool includeDeleted = false,
  });

  Future<AppResult<List<ActivityCategoryLink>>> setActivityCategories({
    required String activityId,
    required String? primaryCategoryId,
    required List<String> secondaryCategoryIds,
    String? userId,
  });

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

abstract class ITimeEntryRepository {
  Future<AppResult<TimeEntry?>> runningEntry();

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

  Future<AppResult<List<TimeEntry>>> entriesForDay(DateTime day);

  Future<AppResult<List<TimeEntry>>> entriesForRange(
    DateTime start,
    DateTime end,
  );

  Future<AppResult<List<TimeEntry>>> entriesSince(DateTime since);

  Future<AppResult<List<TimeEntry>>> allEntries();

  Future<AppResult<EntryMergeCandidate?>> mergeCandidateForEntry(
    String entryId,
    EntryMergeDirection direction,
  );

  Future<AppResult<TimeEntry?>> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  });

  Future<AppResult<List<TimeEntry>>> overlappingEntries(TimeEntry entry);

  Future<AppResult<void>> replaceEntryIfRemoteNewer(TimeEntry remote);
}

// ---------------------------------------------------------------------------
// IActionLogRepository
// ---------------------------------------------------------------------------

abstract class IActionLogRepository {
  Future<AppResult<List<ActionLog>>> actionLogsForDay(DateTime day);

  Future<AppResult<List<ActionLog>>> actionLogsForRange(
    DateTime start,
    DateTime end,
  );

  Future<AppResult<List<ActionLog>>> actionLogsSince(DateTime since);

  Future<AppResult<List<ActionLog>>> allActionLogs();

  Future<AppResult<void>> addActionLog({
    required ActionType actionType,
    required String? activityId,
    required String? entryId,
    required DateTime occurredAt,
    required String message,
  });

  Future<AppResult<void>> replaceActionLogIfRemoteNewer(ActionLog remote);
}
