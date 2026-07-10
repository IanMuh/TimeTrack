import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/activity_state.dart';
import 'package:timetrack/core/app_constants.dart';
import 'package:timetrack/core/result.dart';
import 'package:timetrack/data/repository_interfaces.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/time_entry.dart';

void main() {
  test('refresh keeps the activity catalog and unassigned lookup local',
      () async {
    final work = _activity(id: 'work', name: 'Work', color: 0xff2563eb);
    final unassigned = _activity(
      id: 'unassigned',
      name: 'Unassigned',
      isUnassigned: true,
    );
    final harness = _Harness(catalogActivities: [work, unassigned]);
    var notifications = 0;
    harness.state.addListener(() => notifications += 1);

    await harness.state.refresh();

    expect(notifications, 1);
    expect(harness.state.activities, [work, unassigned]);
    expect(harness.state.activityById('work'), work);
    expect(harness.state.unassignedActivity, unassigned);
    expect(harness.state.entryIsUnassigned(_entry(activityId: unassigned.id)),
        isTrue);
    expect(harness.state.activityNameForEntry(_entry(activityId: work.id)),
        'Work');
    expect(harness.state.activityColorForEntry(_entry(activityId: work.id)),
        0xff2563eb);
  });

  test('entry snapshots are used when the activity is not in memory', () {
    final harness = _Harness();
    final entry = _entry(
      activityId: 'missing',
      activityNameSnapshot: 'Snapshot',
      activityColorSnapshot: 0xff14b8a6,
    );

    expect(harness.state.activityNameForEntry(entry), 'Snapshot');
    expect(harness.state.activityColorForEntry(entry), 0xff14b8a6);
    expect(
      harness.state.activityColorForEntry(
        _entry(activityId: 'missing', activityColorSnapshot: null),
      ),
      AppConstants.defaultActivityColor,
    );
  });

  test('switch stop and create delegate to focused repositories', () async {
    final activity = _activity(id: 'focus', name: 'Focus');
    final created = _activity(id: 'created', name: 'Created');
    final harness = _Harness(
      catalogActivities: [created],
      createdActivity: created,
    );

    final result = await harness.state.createActivity('Created', 0xff0f172a);
    await harness.state.switchTo(activity);
    await harness.state.stopCurrent();

    expect(result, created);
    expect(harness.activityCommands.createCalls, [('Created', 0xff0f172a)]);
    expect(harness.entryCommands.switchCalls, ['focus']);
    expect(harness.entryCommands.stopCount, 1);
    expect(harness.fullRefreshCount, 1);
    expect(harness.entryRefreshCount, 2);
    expect(harness.activityCatalog.activitiesCalls, 1);
  });

  test('deleting the running activity stops it before deleting', () async {
    final activity = _activity(id: 'activity');
    final harness = _Harness(
      runningEntry: _entry(activityId: activity.id, isRunning: true),
    );

    await harness.state.deleteActivity(activity);

    expect(harness.entryCommands.stopCount, 1);
    expect(harness.activityCommands.deletedActivities, [activity]);
    expect(harness.fullRefreshCount, 1);
  });
}

class _Harness {
  _Harness({
    List<Activity> catalogActivities = const [],
    Activity? createdActivity,
    TimeEntry? runningEntry,
  })  : activityCatalog = _ActivityCatalog(catalogActivities),
        activityCommands = _ActivityCommands(createdActivity),
        entryQueries = _EntryQueries(runningEntry),
        entryCommands = _EntryCommands() {
    state = ActivityState(
      activityCatalog: activityCatalog,
      activityCommands: activityCommands,
      entryQueries: entryQueries,
      entryCommands: entryCommands,
      onFullRefresh: () async => fullRefreshCount += 1,
      onEntryRefresh: () async => entryRefreshCount += 1,
    );
  }

  final _ActivityCatalog activityCatalog;
  final _ActivityCommands activityCommands;
  final _EntryQueries entryQueries;
  final _EntryCommands entryCommands;
  late final ActivityState state;

  int fullRefreshCount = 0;
  int entryRefreshCount = 0;
}

class _ActivityCatalog implements IActivityCatalogRepository {
  _ActivityCatalog(this.catalogActivities);

  final List<Activity> catalogActivities;
  int activitiesCalls = 0;

  @override
  Future<AppResult<List<Activity>>> activities({
    bool includeDeleted = false,
  }) async {
    activitiesCalls += 1;
    return AppSuccess(catalogActivities);
  }

  @override
  Future<AppResult<List<Activity>>> oneOffActivities({
    bool includeDeleted = true,
  }) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<Activity>> unassignedActivity() async {
    return AppSuccess(_activity(id: 'unassigned', isUnassigned: true));
  }
}

class _ActivityCommands implements IActivityCommandRepository {
  _ActivityCommands(Activity? createdActivity)
      : createdActivity = createdActivity ?? _activity(id: 'created');

  final Activity createdActivity;
  final createCalls = <(String, int)>[];
  final deletedActivities = <Activity>[];

  @override
  Future<AppResult<Activity>> createActivity({
    required String name,
    required int color,
    String? userId,
    bool isOneOff = false,
  }) async {
    createCalls.add((name, color));
    return AppSuccess(createdActivity);
  }

  @override
  Future<AppResult<void>> deleteActivity(Activity activity) async {
    deletedActivities.add(activity);
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<Activity>> restoreOneOffActivity(Activity activity) async {
    return AppSuccess(activity);
  }

  @override
  Future<AppResult<Activity>> updateActivity({
    required Activity activity,
    required String name,
    required int color,
  }) async {
    return AppSuccess(activity.copyWith(name: name, color: color));
  }
}

class _EntryQueries implements ITimeEntryQueryRepository {
  const _EntryQueries(this.running);

  final TimeEntry? running;

  @override
  Future<AppResult<TimeEntry?>> runningEntry() async {
    return AppSuccess(running);
  }

  @override
  Future<AppResult<List<TimeEntry>>> allEntries() async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<List<TimeEntry>>> entriesForDay(DateTime day) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<List<TimeEntry>>> entriesForRange(
    DateTime start,
    DateTime end,
  ) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<EntryMergeCandidate?>> mergeCandidateForEntry(
    String entryId,
    EntryMergeDirection direction,
  ) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<List<TimeEntry>>> overlappingEntries(TimeEntry entry) async {
    return const AppSuccess([]);
  }
}

class _EntryCommands implements ITimeEntryCommandRepository {
  final switchCalls = <String>[];
  int stopCount = 0;

  @override
  Future<AppResult<TimeEntry>> switchToActivity(
    String activityId, {
    DateTime? at,
  }) async {
    switchCalls.add(activityId);
    return AppSuccess(_entry(activityId: activityId, isRunning: true));
  }

  @override
  Future<AppResult<void>> stopRunning({DateTime? at}) async {
    stopCount += 1;
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<TimeEntry>> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
    String? userId,
  }) async {
    return AppSuccess(_entry(activityId: activityId));
  }

  @override
  Future<AppResult<void>> deleteEntry(TimeEntry entry) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<TimeEntry?>> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<List<TimeEntry>>> saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  }) async {
    return AppSuccess([entry]);
  }

  @override
  Future<AppResult<List<TimeEntry>>> splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) async {
    return const AppSuccess([]);
  }
}

Activity _activity({
  required String id,
  String name = 'Activity',
  int color = 0xff2563eb,
  bool isUnassigned = false,
}) {
  return Activity(
    id: id,
    userId: null,
    name: name,
    color: color,
    isFavorite: false,
    updatedAt: DateTime(2026, 1, 2),
    isDeleted: false,
    isUnassigned: isUnassigned,
  );
}

TimeEntry _entry({
  required String activityId,
  String activityNameSnapshot = 'Snapshot',
  int? activityColorSnapshot = 0xff0f172a,
  bool isRunning = false,
}) {
  return TimeEntry(
    id: 'entry',
    userId: null,
    activityId: activityId,
    activityNameSnapshot: activityNameSnapshot,
    activityColorSnapshot: activityColorSnapshot,
    startAt: DateTime(2026, 1, 2, 9),
    endAt: isRunning ? null : DateTime(2026, 1, 2, 10),
    note: '',
    deviceId: 'test-device',
    updatedAt: DateTime(2026, 1, 2, 9),
    isDeleted: false,
  );
}
