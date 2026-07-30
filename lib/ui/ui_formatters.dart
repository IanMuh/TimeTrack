import 'package:flutter/widgets.dart';

import '../app/app_state.dart';
import '../domain/activity.dart';
import '../domain/time_entry.dart';
import '../l10n/app_localizations.dart';

String formatDurationForDisplay(BuildContext context, Duration duration) {
  final l10n = AppLocalizations.of(context)!;
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) {
    return l10n.minutesFormat(minutes);
  }
  return l10n.hoursMinutesFormat(hours, minutes);
}

String activityNameForDisplay(BuildContext context, Activity activity) {
  if (activity.isUnassigned) {
    return AppLocalizations.of(context)!.activityUnassigned;
  }
  return activity.name;
}

String activityNameForEntryDisplay(
  BuildContext context,
  AppState state,
  TimeEntry entry,
) {
  final activity = state.activityById(entry.activityId);
  if (activity != null) {
    return activityNameForDisplay(context, activity);
  }
  return state.activityNameForEntry(entry);
}
