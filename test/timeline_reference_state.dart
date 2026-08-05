import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/time_entry.dart';

import 'app_shell_test_support.dart';

void seedTimelineReferenceState(ShellTestState state) {
  final now = DateTime(2024, 5, 15, 17, 0, 17);
  state.now = now;
  state.clockNotifier.value = now;
  state.selectedDay = DateTime(2024, 5, 15);
  state.activities = _timelineReferenceActivities(now);
  state.runningEntry = TimeEntry(
    id: 'timeline-running-entry',
    userId: null,
    activityId: 'work',
    activityNameSnapshot: 'Deep Work',
    activityColorSnapshot: 0xff14b8a6,
    startAt: now.subtract(const Duration(hours: 1, minutes: 24, seconds: 17)),
    endAt: null,
    note: '',
    deviceId: 'phase3-visual',
    updatedAt: now,
    isDeleted: false,
  );
  state.dayEntries = [
    _entry(
      id: 'timeline-deep-work-a',
      activityId: 'work',
      activityName: 'Deep Work',
      color: 0xff14b8a6,
      start: DateTime(2024, 5, 15, 9),
      duration: const Duration(hours: 2, minutes: 15),
      note: 'Project Phoenix',
      updatedAt: now,
    ),
    _entry(
      id: 'timeline-break-walk',
      activityId: 'break',
      activityName: 'Break',
      color: 0xff22c55e,
      start: DateTime(2024, 5, 15, 11, 15),
      duration: const Duration(minutes: 30),
      note: 'Walk',
      updatedAt: now,
    ),
    _entry(
      id: 'timeline-meetings',
      activityId: 'meetings',
      activityName: 'Meetings',
      color: 0xff3b82f6,
      start: DateTime(2024, 5, 15, 11, 45),
      duration: const Duration(hours: 1),
      note: 'Team Standup',
      updatedAt: now,
    ),
    _entry(
      id: 'timeline-learning',
      activityId: 'learning',
      activityName: 'Learning',
      color: 0xff8b5cf6,
      start: DateTime(2024, 5, 15, 12, 45),
      duration: const Duration(minutes: 45),
      note: 'UX Course',
      updatedAt: now,
    ),
    _entry(
      id: 'timeline-break-lunch',
      activityId: 'break',
      activityName: 'Break',
      color: 0xff22c55e,
      start: DateTime(2024, 5, 15, 13, 30),
      duration: const Duration(minutes: 30),
      note: 'Lunch',
      updatedAt: now,
    ),
    _entry(
      id: 'timeline-deep-work-b',
      activityId: 'work',
      activityName: 'Deep Work',
      color: 0xff14b8a6,
      start: DateTime(2024, 5, 15, 14),
      duration: const Duration(hours: 1, minutes: 15),
      note: 'Project Phoenix',
      updatedAt: now,
    ),
    _entry(
      id: 'timeline-admin',
      activityId: 'admin',
      activityName: 'Admin',
      color: 0xff64748b,
      start: DateTime(2024, 5, 15, 15, 15),
      duration: const Duration(minutes: 45),
      note: 'Emails & Planning',
      updatedAt: now,
    ),
  ];
  state.notifyListeners();
}

List<Activity> _timelineReferenceActivities(DateTime now) {
  return [
    Activity(
      id: 'work',
      userId: null,
      name: 'Deep Work',
      color: 0xff14b8a6,
      isFavorite: true,
      updatedAt: now,
      isDeleted: false,
    ),
    Activity(
      id: 'break',
      userId: null,
      name: 'Break',
      color: 0xff22c55e,
      isFavorite: false,
      updatedAt: now,
      isDeleted: false,
    ),
    Activity(
      id: 'meetings',
      userId: null,
      name: 'Meetings',
      color: 0xff3b82f6,
      isFavorite: true,
      updatedAt: now,
      isDeleted: false,
    ),
    Activity(
      id: 'learning',
      userId: null,
      name: 'Learning',
      color: 0xff8b5cf6,
      isFavorite: false,
      updatedAt: now,
      isDeleted: false,
    ),
    Activity(
      id: 'admin',
      userId: null,
      name: 'Admin',
      color: 0xff64748b,
      isFavorite: false,
      updatedAt: now,
      isDeleted: false,
    ),
  ];
}

TimeEntry _entry({
  required String id,
  required String activityId,
  required String activityName,
  required int color,
  required DateTime start,
  required Duration duration,
  required String note,
  required DateTime updatedAt,
}) {
  return TimeEntry(
    id: id,
    userId: null,
    activityId: activityId,
    activityNameSnapshot: activityName,
    activityColorSnapshot: color,
    startAt: start,
    endAt: start.add(duration),
    note: note,
    deviceId: 'phase3-visual',
    updatedAt: updatedAt,
    isDeleted: false,
  );
}
