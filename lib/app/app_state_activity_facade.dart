part of 'app_state.dart';

mixin AppStateActivityFacade on ChangeNotifier {
  ActivityState get _activityState;

  TimeEntry? get runningEntry;
  DateTime get now;

  List<Activity> get activities => _activityState.activities;

  set activities(List<Activity> value) => _activityState.activities = value;

  Activity? activityById(String id) => _activityState.activityById(id);

  Activity? get unassignedActivity => _activityState.unassignedActivity;

  String activityNameForEntry(TimeEntry entry) {
    return _activityState.activityNameForEntry(entry);
  }

  int activityColorForEntry(TimeEntry entry) {
    return _activityState.activityColorForEntry(entry);
  }

  bool _entryIsUnassigned(TimeEntry entry) {
    return _activityState.entryIsUnassigned(entry);
  }

  Activity? get runningActivity {
    final entry = runningEntry;
    if (entry == null) {
      return null;
    }
    final activity = activityById(entry.activityId);
    if (activity == null || activity.isUnassigned) {
      return null;
    }
    return activity;
  }

  Duration runningDuration({DateTime? at}) {
    final entry = runningEntry;
    if (entry == null || _entryIsUnassigned(entry)) {
      return Duration.zero;
    }
    return entry.durationUntil(at ?? now);
  }
}
