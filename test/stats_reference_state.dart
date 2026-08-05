import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/time_entry.dart';

import 'test_fixtures.dart';

Future<void> seedStatsReferenceFixture(TestAppFixture fixture) async {
  final now = DateTime(2024, 5, 19, 17, 0, 17);
  final activities = _statsReferenceActivities(now);
  fixture.state.now = now;
  fixture.state.clockNotifier.value = now;
  fixture.state.selectedDay = DateTime(2024, 5, 19);

  for (final activity in activities) {
    await fixture.repository.upsertActivity(activity);
  }

  await _createEntry(
    fixture,
    activityId: 'work',
    start: DateTime(2024, 5, 13, 9),
    duration: const Duration(hours: 3),
  );
  await _createEntry(
    fixture,
    activityId: 'meetings',
    start: DateTime(2024, 5, 14, 9),
    duration: const Duration(hours: 4),
  );
  await _createEntry(
    fixture,
    activityId: 'learning',
    start: DateTime(2024, 5, 15, 9),
    duration: const Duration(hours: 3, minutes: 30),
  );
  await _createEntry(
    fixture,
    activityId: 'work',
    start: DateTime(2024, 5, 16, 9),
    duration: const Duration(hours: 4, minutes: 30),
  );
  await _createEntry(
    fixture,
    activityId: 'admin',
    start: DateTime(2024, 5, 17, 9),
    duration: const Duration(hours: 3, minutes: 23),
  );
  await _createEntry(
    fixture,
    activityId: 'learning',
    start: DateTime(2024, 5, 17, 13),
    duration: const Duration(hours: 1, minutes: 1),
  );
  await _createEntry(
    fixture,
    activityId: 'meetings',
    start: DateTime(2024, 5, 18, 9),
    duration: const Duration(hours: 2, minutes: 47),
  );
  await _createEntry(
    fixture,
    activityId: 'personal',
    start: DateTime(2024, 5, 18, 13),
    duration: const Duration(minutes: 47),
  );
  await _createEntry(
    fixture,
    activityId: 'work',
    start: DateTime(2024, 5, 19, 8),
    duration: const Duration(hours: 3, minutes: 48),
  );
  await _createEntry(
    fixture,
    activityId: 'personal',
    start: DateTime(2024, 5, 19, 13),
    duration: const Duration(hours: 1, minutes: 28),
  );

  await _createEntry(
    fixture,
    activityId: 'work',
    start: DateTime(2024, 5, 6, 9),
    duration: const Duration(hours: 24, minutes: 33),
  );

  await fixture.state.refresh();
  fixture.state.now = now;
  fixture.state.clockNotifier.value = now;
  fixture.state.selectedDay = DateTime(2024, 5, 19);
  fixture.state.activities = activities;
  fixture.state.runningEntry = TimeEntry(
    id: 'stats-running-entry',
    userId: null,
    activityId: 'work',
    activityNameSnapshot: 'Deep Work',
    activityColorSnapshot: 0xff14b8a6,
    startAt: now.subtract(const Duration(hours: 1, minutes: 24, seconds: 17)),
    endAt: null,
    note: '',
    deviceId: 'phase4-visual',
    updatedAt: now,
    isDeleted: false,
  );
  fixture.state.notifyListeners();
}

List<Activity> _statsReferenceActivities(DateTime now) {
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

Future<void> _createEntry(
  TestAppFixture fixture, {
  required String activityId,
  required DateTime start,
  required Duration duration,
}) async {
  await fixture.repository.createManualEntry(
    activityId: activityId,
    startAt: start,
    endAt: start.add(duration),
    note: '',
  );
}
