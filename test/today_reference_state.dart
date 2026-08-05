import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/time_entry.dart';

import 'app_shell_test_support.dart';

void seedTodayReferenceState(ShellTestState state) {
  final now = DateTime(2024, 5, 15, 17, 0, 17);
  state.now = now;
  state.clockNotifier.value = now;
  state.selectedDay = DateTime(2024, 5, 15);
  state.activities = _todayReferenceActivities(now);
  state.runningEntry = TimeEntry(
    id: 'deep-running-entry',
    userId: null,
    activityId: 'work',
    activityNameSnapshot: 'Deep Work',
    activityColorSnapshot: 0xff14b8a6,
    startAt: now.subtract(const Duration(hours: 1, minutes: 24, seconds: 17)),
    endAt: null,
    note: '',
    deviceId: 'phase2-visual',
    updatedAt: now,
    isDeleted: false,
  );
  state.dayEntries = [
    state.runningEntry!,
    _entry(
      id: 'deep-earlier-entry',
      activityId: 'work',
      activityName: 'Deep Work',
      color: 0xff14b8a6,
      start: DateTime(2024, 5, 15, 9),
      duration: const Duration(hours: 1, minutes: 20, seconds: 43),
      note: 'Project Phoenix',
      updatedAt: now,
    ),
    _entry(
      id: 'meetings-entry-a',
      activityId: 'meetings',
      activityName: 'Meetings',
      color: 0xff3b82f6,
      start: DateTime(2024, 5, 15, 11, 45),
      duration: const Duration(minutes: 45),
      note: 'Team Standup',
      updatedAt: now,
    ),
    _entry(
      id: 'learning-entry',
      activityId: 'learning',
      activityName: 'Learning',
      color: 0xff8b5cf6,
      start: DateTime(2024, 5, 15, 12, 45),
      duration: const Duration(hours: 1, minutes: 5),
      note: 'UX Course',
      updatedAt: now,
    ),
    _entry(
      id: 'admin-entry',
      activityId: 'admin',
      activityName: 'Admin',
      color: 0xff64748b,
      start: DateTime(2024, 5, 15, 11, 15),
      duration: const Duration(minutes: 45),
      note: 'Walk',
      updatedAt: now,
    ),
    _entry(
      id: 'personal-entry',
      activityId: 'personal',
      activityName: 'Personal',
      color: 0xfff59e0b,
      start: DateTime(2024, 5, 15, 13, 30),
      duration: const Duration(minutes: 33),
      note: 'Lunch',
      updatedAt: now,
    ),
    _entry(
      id: 'meetings-entry-b',
      activityId: 'meetings',
      activityName: 'Meetings',
      color: 0xff3b82f6,
      start: DateTime(2024, 5, 15, 14, 15),
      duration: const Duration(minutes: 45),
      note: 'Planning',
      updatedAt: now,
    ),
  ];
  state.notifyListeners();
}

List<Activity> _todayReferenceActivities(DateTime now) {
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
    Activity(
      id: 'personal',
      userId: null,
      name: 'Personal',
      color: 0xfff59e0b,
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
  String note = '',
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
    deviceId: 'phase2-visual',
    updatedAt: updatedAt,
    isDeleted: false,
  );
}
