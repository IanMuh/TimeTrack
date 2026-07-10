import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/reminder_coordinator_state.dart';
import 'package:timetrack/app/reminder_state.dart';
import 'package:timetrack/domain/profile_settings.dart';
import 'package:timetrack/domain/time_entry.dart';

void main() {
  test('reminder getters combine current settings entry and clock', () {
    final harness = _Harness(
      runningEntry: _entry(startAt: DateTime(2026, 1, 1, 9)),
      now: DateTime(2026, 1, 1, 9, 45),
      settings: ProfileSettings.defaults().copyWith(
        reminderMinutes: 30,
        reminderMethod: ReminderMethod.dialog,
        reminderTimeOfDayMinutes: 9 * 60,
      ),
    );

    expect(harness.state.shouldShowReminder, isTrue);
    expect(harness.state.shouldShowReminderDialog, isTrue);
    expect(harness.state.shouldShowReminderBanner, isFalse);

    harness.isUnassigned = true;

    expect(harness.state.shouldShowReminder, isFalse);
    expect(harness.state.shouldShowReminderDialog, isFalse);
  });

  test('suspicious getter respects ignored running entry id', () {
    final entry = _entry(startAt: DateTime(2026, 1, 1, 8));
    final harness = _Harness(
      runningEntry: entry,
      now: DateTime(2026, 1, 1, 21),
    );

    expect(harness.state.hasSuspiciousRunningEntry, isTrue);

    harness.state.ignoredSuspiciousEntryId = entry.id;

    expect(harness.state.hasSuspiciousRunningEntry, isFalse);
  });

  test('continue and snooze mark reminder time and notify listeners', () async {
    final harness = _Harness(
      actionNow: DateTime(2026, 1, 1, 10),
    );

    await harness.state.continueCurrent();
    harness.actionNow = DateTime(2026, 1, 1, 10, 5);
    await harness.state.snoozeReminder();

    expect(harness.state.lastReminderAt, DateTime(2026, 1, 1, 10, 5));
    expect(harness.notifyCount, 2);
  });

  test('ignoreSuspiciousRunning stores running entry id and marks reminded',
      () async {
    final entry = _entry(startAt: DateTime(2026, 1, 1, 8));
    final actionNow = DateTime(2026, 1, 1, 10);
    final harness = _Harness(
      runningEntry: entry,
      actionNow: actionNow,
    );

    await harness.state.ignoreSuspiciousRunning();

    expect(harness.state.ignoredSuspiciousEntryId, entry.id);
    expect(harness.state.lastReminderAt, actionNow);
    expect(harness.notifyCount, 1);
  });
}

class _Harness {
  _Harness({
    this.runningEntry,
    DateTime? now,
    DateTime? actionNow,
    ProfileSettings? settings,
  })  : now = now ?? DateTime(2026, 1, 1, 10),
        actionNow = actionNow ?? DateTime(2026, 1, 1, 10),
        settings = settings ?? ProfileSettings.defaults() {
    state = ReminderCoordinatorState(
      reminderState: ReminderState(),
      now: () => this.now,
      actionNow: () => this.actionNow,
      settings: () => this.settings,
      runningEntry: () => runningEntry,
      entryIsUnassigned: (_) => isUnassigned,
      notifyListeners: notifyListeners,
    );
  }

  TimeEntry? runningEntry;
  DateTime now;
  DateTime actionNow;
  ProfileSettings settings;
  bool isUnassigned = false;
  late final ReminderCoordinatorState state;
  int notifyCount = 0;

  void notifyListeners() {
    notifyCount += 1;
  }
}

TimeEntry _entry({required DateTime startAt}) {
  return TimeEntry(
    id: 'entry',
    userId: null,
    activityId: 'activity',
    startAt: startAt,
    endAt: null,
    note: '',
    deviceId: 'test-device',
    updatedAt: startAt,
    isDeleted: false,
  );
}
