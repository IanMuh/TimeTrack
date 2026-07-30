import 'package:flutter/material.dart';

import '../domain/activity.dart';
import '../domain/time_entry.dart';
import 'current_status_card_content.dart';

class CurrentStatusCard extends StatelessWidget {
  const CurrentStatusCard({
    required this.runningActivity,
    required this.clockNotifier,
    required this.runningDurationAt,
    required this.onStop,
    this.onSwitch,
    this.entries = const [],
    super.key,
  });

  final Activity? runningActivity;
  final ValueNotifier<DateTime> clockNotifier;
  final Duration Function(DateTime at) runningDurationAt;
  final VoidCallback? onStop;
  final VoidCallback? onSwitch;
  final List<TimeEntry> entries;

  @override
  Widget build(BuildContext context) {
    return CurrentStatusCardContent(
      runningActivity: runningActivity,
      clockNotifier: clockNotifier,
      runningDurationAt: runningDurationAt,
      onStop: onStop,
      onSwitch: onSwitch,
      entries: entries,
    );
  }
}
