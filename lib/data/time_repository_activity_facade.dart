part of 'time_repository.dart';

mixin TimeRepositoryActivityFacade {
  RepositoryActivityRepository get _activityFacade;

  Future<List<Activity>> activities({bool includeDeleted = false}) async {
    return _activityFacade.activities(includeDeleted: includeDeleted);
  }

  Future<List<Activity>> oneOffActivities({
    bool includeDeleted = true,
  }) async {
    return _activityFacade.oneOffActivities(
      includeDeleted: includeDeleted,
    );
  }

  Future<Activity> unassignedActivity() async {
    return _activityFacade.unassignedActivity();
  }

  Future<void> upsertActivity(Activity activity) async {
    await _activityFacade.upsertActivity(activity);
  }

  Future<Activity> createActivity({
    required String name,
    required int color,
    String? userId,
    bool isOneOff = false,
  }) async {
    return _activityFacade.createActivity(
      name: name,
      color: color,
      userId: userId,
      isOneOff: isOneOff,
    );
  }

  Future<Activity> updateActivity({
    required Activity activity,
    required String name,
    required int color,
  }) async {
    return _activityFacade.updateActivity(
      activity: activity,
      name: name,
      color: color,
    );
  }

  Future<Activity> restoreOneOffActivity(Activity activity) async {
    return _activityFacade.restoreOneOffActivity(activity);
  }

  Future<void> deleteActivity(Activity activity) async {
    await _activityFacade.deleteActivity(activity);
  }

  Future<List<Activity>> activitiesSince(DateTime since) async {
    return _activityFacade.activitiesSince(since);
  }

  Future<void> replaceActivityIfRemoteNewer(Activity remote) async {
    await _activityFacade.replaceActivityIfRemoteNewer(remote);
  }
}
