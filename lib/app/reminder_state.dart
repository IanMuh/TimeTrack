import 'package:flutter/foundation.dart';

import '../core/app_constants.dart';
import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';

class ReminderState extends ChangeNotifier {
  DateTime? lastReminderAt;
  String? ignoredSuspiciousEntryId;

  // Context fields set by AppState — updated whenever the source fields change.
  TimeEntry? runningEntry;
  DateTime now = DateTime.now();
  ProfileSettings settings = ProfileSettings.defaults();
  bool Function(String activityId)? isActivityUnassigned;

  bool get shouldShowReminder {
    final entry = runningEntry;
    final isUnassigned = isActivityUnassigned;
    if (entry == null || isUnassigned == null || isUnassigned(entry.activityId)) {
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

  bool get shouldShowReminderDialog {
    return shouldShowReminder &&
        settings.reminderMethod == ReminderMethod.dialog;
  }

  bool get shouldShowReminderBanner {
    return shouldShowReminder &&
        settings.reminderMethod == ReminderMethod.banner;
  }

  bool get hasSuspiciousRunningEntry {
    final entry = runningEntry;
    final isUnassigned = isActivityUnassigned;
    return entry != null &&
        isUnassigned != null &&
        !isUnassigned(entry.activityId) &&
        entry.id != ignoredSuspiciousEntryId &&
        entry.durationUntil(now) >
            const Duration(hours: AppConstants.suspiciousEntryHours);
  }

  Future<void> continueCurrent() async {
    lastReminderAt = DateTime.now();
    notifyListeners();
  }

  Future<void> snoozeReminder() async {
    lastReminderAt = DateTime.now();
    notifyListeners();
  }

  Future<void> ignoreSuspiciousRunning() async {
    ignoredSuspiciousEntryId = runningEntry?.id;
    await continueCurrent();
  }
}
