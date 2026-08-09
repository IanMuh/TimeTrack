import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../domain/activity.dart';
import '../l10n/app_localizations.dart';
import 'timer_quick_activity_grid.dart';
import 'timer_session_card.dart';

class DesktopTimerPage extends StatelessWidget {
  const DesktopTimerPage({
    required this.state,
    required this.runningActivity,
    required this.pendingActivity,
    required this.activities,
    required this.quickActivityKey,
    required this.onActivityTap,
    required this.onEditActivity,
    required this.onOneOffActivity,
    required this.onAddActivity,
    required this.onSwitch,
    super.key,
  });

  final AppState state;
  final Activity? runningActivity;
  final Activity? pendingActivity;
  final List<Activity> activities;
  final GlobalKey quickActivityKey;
  final ValueChanged<Activity> onActivityTap;
  final ValueChanged<Activity> onEditActivity;
  final VoidCallback onOneOffActivity;
  final VoidCallback onAddActivity;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final timerSessionCard = TimerSessionCard(
      runningActivity: runningActivity,
      clockNotifier: state.clockNotifier,
      runningDurationAt: (at) => state.runningDuration(at: at),
      entries: state.dayEntries,
      onStop: runningActivity == null ? null : state.stopCurrent,
      onSwitch: onSwitch,
    );
    final quickActivityGrid = TimerQuickActivityGrid(
      key: quickActivityKey,
      activities: activities,
      runningActivity: runningActivity,
      pendingActivity: pendingActivity,
      onActivityTap: onActivityTap,
      onEditActivity: onEditActivity,
      onOneOffActivity: onOneOffActivity,
      onAddActivity: onAddActivity,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context)!.navTimer,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  timerSessionCard,
                  const SizedBox(height: 12),
                  quickActivityGrid,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: timerSessionCard),
                const SizedBox(width: 12),
                Expanded(flex: 7, child: quickActivityGrid),
              ],
            );
          },
        ),
      ],
    );
  }
}
