import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../domain/activity.dart';
import '../l10n/app_localizations.dart';
import 'activity_editor_dialog.dart';
import 'adaptive_layout.dart';
import 'one_off_activity_dialog.dart';
import 'timer_quick_activity_grid.dart';
import 'timer_session_card.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({required this.state, super.key});

  final AppState state;

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  String? _pendingActivityId;
  final _quickActivityKey = GlobalKey();

  Future<void> _confirmOrSwitch(Activity activity) async {
    if (_pendingActivityId != activity.id) {
      setState(() => _pendingActivityId = activity.id);
      return;
    }
    await widget.state.switchTo(activity);
    if (mounted) {
      setState(() => _pendingActivityId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final runningActivity = state.runningActivity;
        final pendingActivity = _pendingActivityId == null
            ? null
            : state.activityById(_pendingActivityId!);
        return AdaptivePage(
          pageKey: const PageStorageKey('timer-page'),
          maxWidth: 430,
          onRefresh: state.refresh,
          children: [
            Text(
              AppLocalizations.of(context)!.navTimer,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 18),
            TimerSessionCard(
              runningActivity: runningActivity,
              clockNotifier: state.clockNotifier,
              runningDurationAt: (now) => state.runningDuration(at: now),
              entries: state.dayEntries,
              onStop: runningActivity == null ? null : state.stopCurrent,
              onSwitch: _scrollToQuickActivity,
            ),
            const SizedBox(height: 22),
            TimerQuickActivityGrid(
              key: _quickActivityKey,
              activities: _switchableActivities(state),
              runningActivity: runningActivity,
              pendingActivity: pendingActivity,
              onActivityTap: _confirmOrSwitch,
              onEditActivity: (activity) => showActivityEditorDialog(
                context,
                state,
                activity: activity,
              ),
              onOneOffActivity: () => showOneOffActivityDialog(context, state),
              onAddActivity: () => showActivityEditorDialog(context, state),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 18),
              Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        );
      },
    );
  }

  List<Activity> _switchableActivities(AppState state) {
    return [
      for (final activity in state.activities)
        if (!activity.isUnassigned && !activity.isOneOff) activity,
    ];
  }

  void _scrollToQuickActivity() {
    final context = _quickActivityKey.currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: 0,
    );
  }
}
