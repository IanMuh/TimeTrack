import '../core/app_constants.dart';
import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';

class ReminderState {
  DateTime? lastReminderAt;
  String? ignoredSuspiciousEntryId;

  bool shouldShowReminder({
    required TimeEntry? runningEntry,
    required ProfileSettings settings,
    required DateTime now,
    required bool Function(TimeEntry entry) entryIsUnassigned,
  }) {
    final entry = runningEntry;
    if (entry == null || entryIsUnassigned(entry)) {
      return false;
    }
    final reminderDuration = Duration(minutes: settings.reminderMinutes);
    final reminderStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(minutes: settings.reminderTimeOfDayMinutes));
    final recentlyReminded = lastReminderAt != null &&
        now.difference(lastReminderAt!) <
            Duration(minutes: settings.reminderIntervalMinutes);
    return !now.isBefore(reminderStart) &&
        entry.durationUntil(now) >= reminderDuration &&
        !recentlyReminded;
  }

  bool shouldShowReminderDialog({
    required TimeEntry? runningEntry,
    required ProfileSettings settings,
    required DateTime now,
    required bool Function(TimeEntry entry) entryIsUnassigned,
  }) {
    return shouldShowReminder(
          runningEntry: runningEntry,
          settings: settings,
          now: now,
          entryIsUnassigned: entryIsUnassigned,
        ) &&
        settings.reminderMethod == ReminderMethod.dialog;
  }

  bool shouldShowReminderBanner({
    required TimeEntry? runningEntry,
    required ProfileSettings settings,
    required DateTime now,
    required bool Function(TimeEntry entry) entryIsUnassigned,
  }) {
    return shouldShowReminder(
          runningEntry: runningEntry,
          settings: settings,
          now: now,
          entryIsUnassigned: entryIsUnassigned,
        ) &&
        settings.reminderMethod == ReminderMethod.banner;
  }

  bool hasSuspiciousRunningEntry({
    required TimeEntry? runningEntry,
    required DateTime now,
    required bool Function(TimeEntry entry) entryIsUnassigned,
  }) {
    final entry = runningEntry;
    return entry != null &&
        !entryIsUnassigned(entry) &&
        entry.id != ignoredSuspiciousEntryId &&
        entry.durationUntil(now) >
            const Duration(hours: AppConstants.suspiciousEntryHours);
  }

  void markReminded(DateTime at) {
    lastReminderAt = at;
  }

  void ignoreSuspiciousRunning(TimeEntry? runningEntry) {
    ignoredSuspiciousEntryId = runningEntry?.id;
  }
}
