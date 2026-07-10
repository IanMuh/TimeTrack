import '../core/result.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import 'action_log_repository.dart';
import 'activity_repository.dart';
import 'repository_result.dart';
import 'time_entry_repository.dart';

class RepositoryActivityRepository {
  const RepositoryActivityRepository({
    required ActivityRepository activityRepository,
    required TimeEntryRepository timeEntryRepository,
    required ActionLogRepository actionLogRepository,
  })  : _activityRepo = activityRepository,
        _entryRepo = timeEntryRepository,
        _logRepo = actionLogRepository;

  final ActivityRepository _activityRepo;
  final TimeEntryRepository _entryRepo;
  final ActionLogRepository _logRepo;

  Future<List<Activity>> activities({bool includeDeleted = false}) async {
    final result = await _activityRepo.activities(
      includeDeleted: includeDeleted,
    );
    return _unwrap(result);
  }

  Future<List<Activity>> oneOffActivities({
    bool includeDeleted = true,
  }) async {
    final result = await _activityRepo.oneOffActivities(
      includeDeleted: includeDeleted,
    );
    return _unwrap(result);
  }

  Future<Activity> unassignedActivity() async {
    final result = await _activityRepo.unassignedActivity();
    return _unwrap(result);
  }

  Future<void> upsertActivity(Activity activity) async {
    final result = await _activityRepo.upsertActivity(activity);
    _unwrap(result);
  }

  Future<Activity> createActivity({
    required String name,
    required int color,
    String? userId,
    bool isOneOff = false,
  }) async {
    final result = await _activityRepo.createActivity(
      name: name,
      color: color,
      userId: userId,
      isOneOff: isOneOff,
    );
    return _unwrap(result);
  }

  Future<Activity> updateActivity({
    required Activity activity,
    required String name,
    required int color,
  }) async {
    final result = await _activityRepo.updateActivity(
      activity: activity,
      name: name,
      color: color,
    );
    return _unwrap(result);
  }

  Future<Activity> restoreOneOffActivity(Activity activity) async {
    final result = await _activityRepo.restoreOneOffActivity(activity);
    return _unwrap(result);
  }

  Future<void> deleteActivity(Activity activity) async {
    if (activity.isUnassigned) {
      return;
    }
    final now = DateTime.now();
    final runningResult = await _entryRepo.runningEntry();
    final running = runningResult.fold(
      onSuccess: (r) => r,
      onFailure: (_) => null,
    );
    if (running?.activityId == activity.id) {
      final stopResult = await _entryRepo.stopRunning(at: now);
      _unwrap(stopResult);
    }
    final result = await _activityRepo.deleteActivity(activity);
    _unwrap(result);
    final logResult = await _logRepo.addActionLog(
      actionType: ActionType.activityDelete,
      activityId: activity.id,
      entryId: null,
      occurredAt: now,
      message: '删除事项',
    );
    _unwrap(logResult);
  }

  Future<List<Activity>> activitiesSince(DateTime since) async {
    final result = await _activityRepo.activitiesSince(since);
    return _unwrap(result);
  }

  Future<void> replaceActivityIfRemoteNewer(Activity remote) async {
    final result = await _activityRepo.replaceActivityIfRemoteNewer(remote);
    _unwrap(result);
  }

  T _unwrap<T>(AppResult<T> result) {
    return unwrapRepositoryResult(result);
  }
}
