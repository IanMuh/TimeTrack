import 'package:flutter/material.dart';

import '../domain/activity.dart';
import '../l10n/app_localizations.dart';
import 'activity_sort_controls.dart';
import 'activity_switch_button.dart';
import 'adaptive_layout.dart';
import 'quick_activity_action_tile.dart';
import 'sort_controls.dart';
import 'ui_components.dart';

class HomeQuickSwitchPanel extends StatelessWidget {
  const HomeQuickSwitchPanel({
    required this.activities,
    required this.runningActivity,
    required this.pendingActivity,
    required this.metric,
    required this.order,
    required this.showSortInline,
    required this.showCompactSortControls,
    required this.onMetricChanged,
    required this.onOrderChanged,
    required this.onToggleCompactSort,
    required this.onSync,
    required this.onActivityTap,
    required this.onEditActivity,
    required this.onOneOffActivity,
    required this.onAddActivity,
    super.key,
  });

  final List<Activity> activities;
  final Activity? runningActivity;
  final Activity? pendingActivity;
  final ActivitySortMetric metric;
  final SortOrder order;
  final bool showSortInline;
  final bool showCompactSortControls;
  final ValueChanged<ActivitySortMetric> onMetricChanged;
  final ValueChanged<SortOrder> onOrderChanged;
  final VoidCallback onToggleCompactSort;
  final VoidCallback? onSync;
  final ValueChanged<Activity> onActivityTap;
  final ValueChanged<Activity> onEditActivity;
  final VoidCallback onOneOffActivity;
  final VoidCallback onAddActivity;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final denseDesktop = showSortInline || !compact;
        final sortControls = ActivitySortControls(
          metric: metric,
          order: order,
          onMetricChanged: onMetricChanged,
          onOrderChanged: onOrderChanged,
        );
        final tools = <Widget>[
          if (!showSortInline && compact)
            IconButton.outlined(
              tooltip: AppLocalizations.of(context)!.sortBy,
              onPressed: onToggleCompactSort,
              icon: Icon(
                showCompactSortControls ? Icons.expand_less : Icons.sort,
              ),
            ),
          if (onSync != null)
            IconButton.outlined(
              tooltip: AppLocalizations.of(context)!.sync,
              onPressed: onSync,
              icon: const Icon(Icons.sync),
            ),
        ];

        final title = AppLocalizations.of(context)!.quickSwitch;
        final hasPendingSwitch = pendingActivity != null &&
            pendingActivity!.id != runningActivity?.id;
        final subtitle = pendingActivity == null ||
                pendingActivity!.id == runningActivity?.id
            ? AppLocalizations.of(context)!.quickSwitchHint
            : AppLocalizations.of(context)!
                .quickSwitchSelected(pendingActivity!.name);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact && !showSortInline)
              _CompactQuickSwitchHeader(
                title: title,
                subtitle: hasPendingSwitch ? subtitle : null,
                trailing:
                    tools.isEmpty ? null : Wrap(spacing: 8, children: tools),
              )
            else
              PageHeader(
                title: title,
                subtitle: subtitle,
                trailing:
                    tools.isEmpty ? null : Wrap(spacing: 8, children: tools),
              ),
            if (showSortInline || !compact || showCompactSortControls) ...[
              const SizedBox(height: 10),
              sortControls,
            ],
            const SizedBox(height: 8),
            _ActivityGrid(
              compact: !denseDesktop,
              activities: activities,
              runningActivity: runningActivity,
              pendingActivity: pendingActivity,
              onActivityTap: onActivityTap,
              onEditActivity: onEditActivity,
              onOneOffActivity: onOneOffActivity,
              onAddActivity: onAddActivity,
            ),
          ],
        );
      },
    );
  }
}

class _CompactQuickSwitchHeader extends StatelessWidget {
  const _CompactQuickSwitchHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class _ActivityGrid extends StatelessWidget {
  const _ActivityGrid({
    required this.compact,
    required this.activities,
    required this.runningActivity,
    required this.pendingActivity,
    required this.onActivityTap,
    required this.onEditActivity,
    required this.onOneOffActivity,
    required this.onAddActivity,
  });

  final bool compact;
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
        ActivitySwitchButton(
          activity: activity,
          selected: runningActivity?.id == activity.id,
          pending: pendingActivity?.id == activity.id &&
              runningActivity?.id != activity.id,
          onTap: () => onActivityTap(activity),
          onDoubleTap: () => onActivityTap(activity),
          onEdit: activity.isUnassigned ? null : () => onEditActivity(activity),
        ),
      OneOffActivityTile(onPressed: onOneOffActivity, compact: compact),
      AddActivityTile(onPressed: onAddActivity, compact: compact),
    ];
    if (compact) {
      return GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: tiles,
      );
    }
    return GridView.extent(
      maxCrossAxisExtent: 250.0,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 4.1,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: tiles,
    );
  }
}
