import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/reminder_state.dart';
import 'package:timetrack/domain/profile_settings.dart';
import 'package:timetrack/domain/time_entry.dart';

void main() {
  test('reminder respects start time duration and interval', () {
    final state = ReminderState();
    final entry = _entry(startAt: DateTime(2026, 1, 1, 9));
    final settings = ProfileSettings.defaults().copyWith(
      reminderMinutes: 30,
      reminderIntervalMinutes: 15,
      reminderTimeOfDayMinutes: 9 * 60,
    );

    expect(
      state.shouldShowReminder(
        runningEntry: entry,
        settings: settings,
        now: DateTime(2026, 1, 1, 9, 20),
        entryIsUnassigned: (_) => false,
      ),
      isFalse,
    );
    expect(
      state.shouldShowReminder(
        runningEntry: entry,
        settings: settings,
        now: DateTime(2026, 1, 1, 9, 30),
        entryIsUnassigned: (_) => false,
      ),
      isTrue,
    );

    state.markReminded(DateTime(2026, 1, 1, 9, 20));

    expect(
      state.shouldShowReminder(
        runningEntry: entry,
        settings: settings,
        now: DateTime(2026, 1, 1, 9, 30),
        entryIsUnassigned: (_) => false,
      ),
      isFalse,
    );
    expect(
      state.shouldShowReminder(
        runningEntry: entry,
        settings: settings,
        now: DateTime(2026, 1, 1, 9, 35),
        entryIsUnassigned: (_) => false,
      ),
      isTrue,
    );
  });

  test('reminder exposes dialog and banner modes', () {
    final state = ReminderState();
    final entry = _entry(startAt: DateTime(2026, 1, 1, 9));
    final dialogSettings = ProfileSettings.defaults().copyWith(
      reminderMinutes: 30,
      reminderMethod: ReminderMethod.dialog,
    );
    final bannerSettings = dialogSettings.copyWith(
      reminderMethod: ReminderMethod.banner,
    );
    final now = DateTime(2026, 1, 1, 9, 45);

    expect(
      state.shouldShowReminderDialog(
        runningEntry: entry,
        settings: dialogSettings,
        now: now,
        entryIsUnassigned: (_) => false,
      ),
      isTrue,
    );
    expect(
      state.shouldShowReminderBanner(
        runningEntry: entry,
        settings: bannerSettings,
        now: now,
        entryIsUnassigned: (_) => false,
      ),
      isTrue,
    );
  });

  test('unassigned and ignored entries are hidden from prompts', () {
    final state = ReminderState();
    final entry = _entry(startAt: DateTime(2026, 1, 1, 8));
    final settings = ProfileSettings.defaults().copyWith(
      reminderMinutes: 30,
    );
    final now = DateTime(2026, 1, 1, 21);

    expect(
      state.shouldShowReminder(
        runningEntry: entry,
        settings: settings,
        now: now,
        entryIsUnassigned: (_) => true,
      ),
      isFalse,
    );
    expect(
      state.hasSuspiciousRunningEntry(
        runningEntry: entry,
        now: now,
        entryIsUnassigned: (_) => false,
      ),
      isTrue,
    );

    state.ignoreSuspiciousRunning(entry);

    expect(
      state.hasSuspiciousRunningEntry(
        runningEntry: entry,
        now: now,
        entryIsUnassigned: (_) => false,
      ),
      isFalse,
    );
  });
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
