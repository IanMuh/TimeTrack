import 'package:flutter/material.dart';

import '../domain/activity.dart';
import '../l10n/app_localizations.dart';
import 'quick_activity_action_tile.dart';

class TimerQuickActivityGrid extends StatelessWidget {
  const TimerQuickActivityGrid({
    required this.activities,
    required this.runningActivity,
    required this.pendingActivity,
    required this.onActivityTap,
    required this.onEditActivity,
    required this.onOneOffActivity,
    required this.onAddActivity,
    super.key,
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
        _TimerActivityTile(
          activity: activity,
          selected: runningActivity?.id == activity.id,
          pending: pendingActivity?.id == activity.id &&
              runningActivity?.id != activity.id,
          onTap: () => onActivityTap(activity),
          onEdit: activity.isUnassigned ? null : () => onEditActivity(activity),
        ),
      OneOffActivityTile(onPressed: onOneOffActivity, compact: true),
      AddActivityTile(onPressed: onAddActivity, compact: true),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context)!.quickActivity,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.62,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: tiles,
        ),
      ],
    );
  }
}

class _TimerActivityTile extends StatelessWidget {
  const _TimerActivityTile({
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
        : 0.18;
    final borderAlpha = selected || pending ? 0.72 : 0.28;
    return Material(
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_activityIcon(activity), color: baseColor, size: 18),
                const SizedBox(height: 4),
                Text(
                  activity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
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
