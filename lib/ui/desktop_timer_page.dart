import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../domain/activity.dart';
import '../domain/time_entry.dart';
import '../l10n/app_localizations.dart';
import 'current_status_card_helpers.dart';
import 'timer_progress_ring.dart';
import 'ui_components.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<DateTime>(
      valueListenable: state.clockNotifier,
      builder: (context, now, _) {
        final todayDuration = state.dayEntries.fold<Duration>(
          Duration.zero,
          (total, entry) => total + entry.durationUntil(now),
        );
        final sessions = state.dayEntries.length;
        final duration = runningActivity == null
            ? Duration.zero
            : state.runningDuration(at: now);
        final headerStatus = runningActivity == null
            ? StatusPill(
                label: l10n.notStarted,
                icon: Icons.pause_circle_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : StatusPill(
                label: l10n.recording,
                icon: Icons.play_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: l10n.navTimer,
              subtitle: runningActivity == null
                  ? l10n.selectActivityToStart
                  : l10n.currentActivitySemantics(runningActivity!.name),
              trailing: headerStatus,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final sessionPanel = _DesktopSessionPanel(
                  runningActivity: runningActivity,
                  duration: duration,
                  todayDuration: todayDuration,
                  sessions: sessions,
                  onStop: runningActivity == null ? null : state.stopCurrent,
                  onSwitch: onSwitch,
                );
                final quickPanel = _DesktopQuickPanel(
                  key: quickActivityKey,
                  activities: activities,
                  runningActivity: runningActivity,
                  pendingActivity: pendingActivity,
                  entries: state.dayEntries,
                  now: now,
                  onActivityTap: onActivityTap,
                  onEditActivity: onEditActivity,
                  onOneOffActivity: onOneOffActivity,
                  onAddActivity: onAddActivity,
                );
                if (constraints.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      sessionPanel,
                      const SizedBox(height: 12),
                      quickPanel,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: sessionPanel),
                    const SizedBox(width: 12),
                    Expanded(flex: 7, child: quickPanel),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _DesktopSessionPanel extends StatelessWidget {
  const _DesktopSessionPanel({
    required this.runningActivity,
    required this.duration,
    required this.todayDuration,
    required this.sessions,
    required this.onStop,
    required this.onSwitch,
  });

  final Activity? runningActivity;
  final Duration duration;
  final Duration todayDuration;
  final int sessions;
  final VoidCallback? onStop;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w800,
        );
    final runningColor = runningActivity == null
        ? colorScheme.secondary
        : _effectiveActivityColor(
            Color(runningActivity!.color),
            colorScheme.brightness,
          );
    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            title: l10n.currentSession,
            subtitle: runningActivity == null
                ? l10n.notStartedRecord
                : runningActivity!.name,
            icon: Icons.timer_outlined,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DesktopTimerRing(
                  duration: duration,
                  activityName: runningActivity?.name ?? l10n.notStartedRecord,
                  runningColor: runningColor,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SessionStat(
                      label: l10n.todayTotalTime,
                      value: formatSummaryDuration(todayDuration),
                    ),
                    const SizedBox(height: 12),
                    _SessionStat(
                      label: l10n.sessions,
                      value: sessions.toString(),
                    ),
                    const SizedBox(height: 12),
                    _SessionStat(
                      label: l10n.currentDoing,
                      value: runningActivity?.name ?? l10n.notStarted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: runningActivity == null
                        ? colorScheme.outlineVariant
                        : const Color(0xffef4444),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onStop,
                  child: Text(
                    l10n.stop,
                    style: labelStyle?.copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSwitch,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(
                    l10n.switchActivity,
                    style: labelStyle?.copyWith(color: colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _effectiveActivityColor(Color color, Brightness brightness) {
    if (brightness == Brightness.light) {
      return color;
    }
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + 0.16).clamp(0.0, 1.0)).toColor();
  }
}

class _DesktopTimerRing extends StatelessWidget {
  const _DesktopTimerRing({
    required this.duration,
    required this.activityName,
    required this.runningColor,
  });

  final Duration duration;
  final String activityName;
  final Color runningColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 236,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox.square(
          dimension: 236,
          child: TimerProgressRing(
            duration: duration,
            activityName: activityName,
            runningColor: runningColor,
          ),
        ),
      ),
    );
  }
}

class _SessionStat extends StatelessWidget {
  const _SessionStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopQuickPanel extends StatelessWidget {
  const _DesktopQuickPanel({
    super.key,
    required this.activities,
    required this.runningActivity,
    required this.pendingActivity,
    required this.entries,
    required this.now,
    required this.onActivityTap,
    required this.onEditActivity,
    required this.onOneOffActivity,
    required this.onAddActivity,
  });

  final List<Activity> activities;
  final Activity? runningActivity;
  final Activity? pendingActivity;
  final List<TimeEntry> entries;
  final DateTime now;
  final ValueChanged<Activity> onActivityTap;
  final ValueChanged<Activity> onEditActivity;
  final VoidCallback onOneOffActivity;
  final VoidCallback onAddActivity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final recentEntries = [
      for (final entry in entries)
        if (!entry.isDeleted) entry,
    ]..sort((a, b) => b.startAt.compareTo(a.startAt));
    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            title: l10n.quickActivity,
            subtitle: l10n.quickSwitchHint,
            icon: Icons.grid_view_rounded,
          ),
          const SizedBox(height: 12),
          _DesktopActivityGrid(
            activities: activities,
            runningActivity: runningActivity,
            pendingActivity: pendingActivity,
            onActivityTap: onActivityTap,
            onEditActivity: onEditActivity,
            onOneOffActivity: onOneOffActivity,
            onAddActivity: onAddActivity,
          ),
          const SizedBox(height: 16),
          SectionTitle(
            title: l10n.today,
            subtitle: l10n.todayViewFullTimeline,
            icon: Icons.history,
          ),
          const SizedBox(height: 10),
          if (recentEntries.isEmpty)
            EmptyState(
              icon: Icons.inbox_outlined,
              title: l10n.emptyTimeline,
              message: l10n.selectActivityToStart,
            )
          else
            Column(
              children: [
                for (final entry in recentEntries.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecentEntryRow(entry: entry, now: now),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DesktopActivityGrid extends StatelessWidget {
  const _DesktopActivityGrid({
    required this.activities,
    required this.runningActivity,
    required this.pendingActivity,
    required this.onActivityTap,
    required this.onEditActivity,
    required this.onOneOffActivity,
    required this.onAddActivity,
  });

  final List<Activity> activities;
  final Activity? runningActivity;
  final Activity? pendingActivity;
  final ValueChanged<Activity> onActivityTap;
  final ValueChanged<Activity> onEditActivity;
  final VoidCallback onOneOffActivity;
  final VoidCallback onAddActivity;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final activity in activities)
        _DesktopActivityTile(
          activity: activity,
          selected: runningActivity?.id == activity.id,
          pending: pendingActivity?.id == activity.id &&
              runningActivity?.id != activity.id,
          onTap: () => onActivityTap(activity),
          onEdit: activity.isUnassigned ? null : () => onEditActivity(activity),
        ),
      _DesktopActionTile(
        icon: Icons.flash_on_outlined,
        label: AppLocalizations.of(context)!.oneOffActivity,
        onPressed: onOneOffActivity,
      ),
      _DesktopActionTile(
        icon: Icons.add,
        label: AppLocalizations.of(context)!.newActivity,
        onPressed: onAddActivity,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 620
            ? 4
            : constraints.maxWidth >= 420
                ? 3
                : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.55,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: tiles,
        );
      },
    );
  }
}

class _DesktopActivityTile extends StatelessWidget {
  const _DesktopActivityTile({
    required this.activity,
    required this.selected,
    required this.pending,
    required this.onTap,
    required this.onEdit,
  });

  final Activity activity;
  final bool selected;
  final bool pending;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = _effectiveActivityColor(
      Color(activity.color),
      colorScheme.brightness,
    );
    final backgroundAlpha = selected
        ? colorScheme.brightness == Brightness.dark
            ? 0.30
            : 0.24
        : 0.14;
    final borderAlpha = selected || pending ? 0.72 : 0.24;
    return Material(
      key: ValueKey('desktop-timer-activity-${activity.id}'),
      color: baseColor.withValues(alpha: backgroundAlpha),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: baseColor.withValues(alpha: borderAlpha)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onEdit,
        child: Semantics(
          button: true,
          selected: selected,
          label: activity.name,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_activityIcon(activity), color: baseColor, size: 20),
                const SizedBox(height: 6),
                Text(
                  activity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  pending
                      ? AppLocalizations.of(context)!.confirm
                      : selected
                          ? AppLocalizations.of(context)!.currentDoing
                          : AppLocalizations.of(context)!.switchActivity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _effectiveActivityColor(Color color, Brightness brightness) {
    if (brightness == Brightness.light) {
      return color;
    }
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0)).toColor();
  }

  IconData _activityIcon(Activity activity) {
    final name = activity.name.toLowerCase();
    if (name.contains('work') || name.contains('工作')) {
      return Icons.work_outline;
    }
    if (name.contains('meet') || name.contains('会')) {
      return Icons.groups_2_outlined;
    }
    if (name.contains('learn') ||
        name.contains('study') ||
        name.contains('学')) {
      return Icons.menu_book_outlined;
    }
    return Icons.radio_button_checked;
  }
}

class _DesktopActionTile extends StatelessWidget {
  const _DesktopActionTile({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colorScheme.primary, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentEntryRow extends StatelessWidget {
  const _RecentEntryRow({
    required this.entry,
    required this.now,
  });

  final TimeEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = entry.durationUntil(now);
    final activityName = entry.activityNameSnapshot.trim().isEmpty
        ? AppLocalizations.of(context)!.notStartedRecord
        : entry.activityNameSnapshot.trim();
    final activityColor = Color(entry.activityColorSnapshot ?? 0xff64748b);
    final timeRange = entry.endAt == null
        ? '${TimeOfDay.fromDateTime(entry.startAt).format(context)} - '
            '${AppLocalizations.of(context)!.inProgress}'
        : '${TimeOfDay.fromDateTime(entry.startAt).format(context)} - '
            '${TimeOfDay.fromDateTime(entry.endAt!).format(context)}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 36,
              decoration: BoxDecoration(
                color: activityColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activityName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeRange,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatSummaryDuration(duration),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
