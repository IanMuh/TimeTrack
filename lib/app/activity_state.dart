import 'package:flutter/foundation.dart';

import '../core/app_constants.dart';
import '../data/repository_interfaces.dart';
import '../domain/activity.dart';
import '../domain/time_entry.dart';

class ActivityState extends ChangeNotifier {
  ActivityState({
    required IActivityRepository activityRepository,
    required ITimeEntryRepository entryRepository,
    required Future<void> Function() onFullRefresh,
    required Future<void> Function() onEntryRefresh,
  })  : _activityRepo = activityRepository,
        _entryRepo = entryRepository,
        _onFullRefresh = onFullRefresh,
        _onEntryRefresh = onEntryRefresh;

  final IActivityRepository _activityRepo;
  final ITimeEntryRepository _entryRepo;
  final Future<void> Function() _onFullRefresh;
  final Future<void> Function() _onEntryRefresh;

  List<Activity> _activities = const [];
  Map<String, Activity> _activitiesById = const {};
  Activity? _unassignedActivity;
  String? errorMessage;

  List<Activity> get activities => _activities;

  set activities(List<Activity> value) {
    _setActivities(value);
  }

  Future<void> refresh({bool notify = true}) async {
    final result = await _activityRepo.activities();
    _setActivities(result.fold(
      onSuccess: (list) => list,
      onFailure: (msg) {
        errorMessage = msg;
        return _activities;
      },
    ));
    if (notify) {
      notifyListeners();
    }
  }

  Activity? activityById(String id) {
    return _activitiesById[id];
  }

  Activity? get unassignedActivity {
    return _unassignedActivity;
  }

  void _setActivities(List<Activity> value) {
    _activities = value;
    _activitiesById = {
      for (final activity in value) activity.id: activity,
    };
    for (final activity in value) {
      if (activity.isUnassigned) {
        _unassignedActivity = activity;
        return;
      }
    }
    _unassignedActivity = null;
  }

  bool entryIsUnassigned(TimeEntry entry) {
    return activityById(entry.activityId)?.isUnassigned ?? false;
  }

  String activityNameForEntry(TimeEntry entry) {
    final activity = activityById(entry.activityId);
    if (activity != null) {
      return activity.name;
    }
    final snapshot = entry.activityNameSnapshot.trim();
    return snapshot.isEmpty ? '未知事项' : snapshot;
  }

  int activityColorForEntry(TimeEntry entry) {
    return activityById(entry.activityId)?.color ??
        entry.activityColorSnapshot ??
        AppConstants.defaultActivityColor;
  }

  Future<void> switchTo(Activity activity) async {
    final result = await _entryRepo.switchToActivity(activity.id);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
    await _onEntryRefresh();
  }

  Future<void> stopCurrent() async {
    final result = await _entryRepo.stopRunning();
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
    await _onEntryRefresh();
  }

  Future<Activity> createActivity(String name, int color) async {
    final result =
        await _activityRepo.createActivity(name: name, color: color);
    final activity = result.fold(
      onSuccess: (a) => a,
      onFailure: (msg) => throw StateError(msg),
    );
    await refresh(notify: false);
    await _onFullRefresh();
    return activity;
  }

  Future<List<Activity>> oneOffActivitySuggestions() async {
    try {
      final result = await _activityRepo.oneOffActivities();
      return result.fold(
        onSuccess: (list) => list,
        onFailure: (_) => [],
      );
    } catch (_) {
      return const [];
    }
  }

  Future<Activity> createOneOffActivity(
    String name,
    int color, {
    Activity? reuseActivity,
  }) async {
    final activityResult = reuseActivity == null
        ? await _activityRepo.createActivity(
            name: name,
            color: color,
            isOneOff: true,
          )
        : await _activityRepo.restoreOneOffActivity(reuseActivity);
    final activity = activityResult.fold(
      onSuccess: (a) => a,
      onFailure: (msg) => throw StateError(msg),
    );
    final switchResult = await _entryRepo.switchToActivity(activity.id);
    switchResult.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
    await refresh(notify: false);
    await _onEntryRefresh();
    return activity;
  }

  Future<Activity> createEntryActivity(
    String name,
    int color, {
    required bool isOneOff,
    Activity? reuseActivity,
  }) async {
    final activityResult = reuseActivity == null
        ? await _activityRepo.createActivity(
            name: name,
            color: color,
            isOneOff: isOneOff,
          )
        : await _activityRepo.restoreOneOffActivity(reuseActivity);
    final activity = activityResult.fold(
      onSuccess: (a) => a,
      onFailure: (msg) => throw StateError(msg),
    );
    await refresh(notify: false);
    await _onFullRefresh();
    return activity;
  }

  Future<Activity> updateActivity(
    Activity activity, {
    required String name,
    required int color,
  }) async {
    if (activity.isUnassigned) {
      return unassignedActivity ?? activity;
    }
    final result = await _activityRepo.updateActivity(
      activity: activity,
      name: name,
      color: color,
    );
    final updated = result.fold(
      onSuccess: (a) => a,
      onFailure: (msg) => throw StateError(msg),
    );
    await refresh(notify: false);
    await _onFullRefresh();
    return updated;
  }

  Future<void> deleteActivity(Activity activity) async {
    if (activity.isUnassigned) {
      return;
    }
    final runningResult = await _entryRepo.runningEntry();
    final running = runningResult.fold(
      onSuccess: (r) => r,
      onFailure: (_) => null,
    );
    if (running?.activityId == activity.id) {
      final stopResult = await _entryRepo.stopRunning();
      stopResult.fold(
        onSuccess: (_) {},
        onFailure: (msg) => throw StateError(msg),
      );
    }
    final result = await _activityRepo.deleteActivity(activity);
    result.fold(
      onSuccess: (_) {},
      onFailure: (msg) => throw StateError(msg),
    );
    await refresh(notify: false);
    await _onFullRefresh();
  }

  Future<List<Activity>> entryActivityChoices() async {
    final choices = <String, Activity>{};
    for (final activity in activities) {
      if (!activity.isUnassigned && !activity.isOneOff) {
        choices[activity.id] = activity;
      }
    }
    return choices.values.toList();
  }
}
