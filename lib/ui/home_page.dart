import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../domain/activity.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'activity_editor_dialog.dart';
import 'activity_sort_controls.dart';
import 'activity_switch_button.dart';
import 'app_shell.dart';
import 'current_status_card.dart';
import 'one_off_activity_dialog.dart';
import 'sort_controls.dart';
import 'ui_components.dart';

export 'activity_sort_controls.dart' show ActivitySortMetric;
export 'activity_switch_button.dart' show ActivitySwitchButton;
export 'current_status_card.dart' show CurrentStatusCard;

class HomePage extends StatefulWidget {
  const HomePage({required this.state, super.key});

  final AppState state;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _pendingActivityId;
  ActivitySortMetric _activitySortMetric = ActivitySortMetric.name;
  SortOrder _activitySortOrder = SortOrder.ascending;
  bool _showCompactSortControls = false;

  Future<void> _confirmOrSwitch(Activity activity) async {
    if (_pendingActivityId != activity.id) {
      setState(() => _pendingActivityId = activity.id);
      return;
    }
    setState(() => _pendingActivityId = activity.id);
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
        final l10n = AppLocalizations.of(context)!;
        final runningActivity = state.runningActivity;
        final switchableActivities = _sortedSwitchableActivities(state);
        final pendingActivity = _pendingActivityId == null
            ? null
            : state.activityById(_pendingActivityId!);
        return AdaptivePage(
          pageKey: const PageStorageKey('home-page'),
          children: [
            PageHeader(
              title: l10n.appTitle,
              subtitle: l10n.appSubtitle,
              trailing: StatusPill(
                label: state.hasSyncTarget
                    ? l10n.syncStatusCloud
                    : l10n.syncStatusLocal,
                icon: state.hasSyncTarget
                    ? Icons.cloud_done_outlined
                    : Icons.offline_bolt_outlined,
                color: state.hasSyncTarget
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SectionGap(),
            LayoutBuilder(
              builder: (context, constraints) {
                final sizeClass = adaptiveSizeClassFor(constraints.maxWidth);
                final statusCard = CurrentStatusCard(
                  runningActivity: runningActivity,
                  clockNotifier: state.clockNotifier,
                  runningDurationAt: (now) => state.runningDuration(at: now),
                  onStop: runningActivity == null ? null : state.stopCurrent,
                );
                if (sizeClass == AdaptiveSizeClass.compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      statusCard,
                      const SizedBox(height: 10),
                      LoginBanner(state: state),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: statusCard),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: LoginBanner(state: state)),
                  ],
                );
              },
            ),
            const SectionGap(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < compactBreakpoint;
                final sortControls = ActivitySortControls(
                  metric: _activitySortMetric,
                  order: _activitySortOrder,
                  onMetricChanged: (value) {
                    setState(() => _activitySortMetric = value);
                  },
                  onOrderChanged: (value) {
                    setState(() => _activitySortOrder = value);
                  },
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeader(
                      title: l10n.quickSwitch,
                      subtitle: pendingActivity == null ||
                              pendingActivity.id == runningActivity?.id
                          ? l10n.quickSwitchHint
                          : l10n.quickSwitchSelected(pendingActivity.name),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          if (compact)
                            IconButton.filledTonal(
                              tooltip: l10n.sortBy,
                              onPressed: () {
                                setState(() {
                                  _showCompactSortControls =
                                      !_showCompactSortControls;
                                });
                              },
                              icon: Icon(_showCompactSortControls
                                  ? Icons.expand_less
                                  : Icons.sort),
                            ),
                          IconButton.filledTonal(
                            tooltip: l10n.sync,
                            onPressed: state.hasSyncTarget ? state.sync : null,
                            icon: const Icon(Icons.sync),
                          ),
                        ],
                      ),
                    ),
                    if (!compact || _showCompactSortControls) ...[
                      const SizedBox(height: 10),
                      sortControls,
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < compactBreakpoint;
                final tileExtent = compact ? 170.0 : 250.0;
                return GridView.extent(
                  maxCrossAxisExtent: tileExtent,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: compact ? 2.35 : 3.15,
                  crossAxisSpacing: compact ? 10 : 12,
                  mainAxisSpacing: compact ? 10 : 12,
                  children: [
                    for (final activity in switchableActivities)
                      ActivitySwitchButton(
                        activity: activity,
                        selected: runningActivity?.id == activity.id,
                        pending: _pendingActivityId == activity.id &&
                            runningActivity?.id != activity.id,
                        onTap: () => _confirmOrSwitch(activity),
                        onDoubleTap: () => _confirmOrSwitch(activity),
                        onEdit: activity.isUnassigned
                            ? null
                            : () => showActivityEditorDialog(
                                  context,
                                  state,
                                  activity: activity,
                                ),
                      ),
                    OneOffActivityTile(
                      onPressed: () => showOneOffActivityDialog(context, state),
                    ),
                    AddActivityTile(
                      onPressed: () => showActivityEditorDialog(context, state),
                    ),
                  ],
                );
              },
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

  List<Activity> _sortedSwitchableActivities(AppState state) {
    final activities = [
      for (final activity in state.activities)
        if (!activity.isUnassigned && !activity.isOneOff) activity,
    ];
    activities.sort((a, b) {
      final compare = switch (_activitySortMetric) {
        ActivitySortMetric.name => a.name.compareTo(b.name),
        ActivitySortMetric.color => a.color.compareTo(b.color),
        ActivitySortMetric.primaryCategory =>
          _categoryName(state, a).compareTo(_categoryName(state, b)),
        ActivitySortMetric.updatedAt => a.updatedAt.compareTo(b.updatedAt),
      };
      final directed =
          _activitySortOrder == SortOrder.ascending ? compare : -compare;
      if (directed != 0) return directed;
      return a.name.compareTo(b.name);
    });
    return activities;
  }

  String _categoryName(AppState state, Activity activity) {
    return state.primaryCategoryForActivity(activity.id)?.name ?? '';
  }
}
