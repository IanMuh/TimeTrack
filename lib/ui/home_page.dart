import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../domain/activity.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'activity_editor_dialog.dart';
import 'activity_sort_controls.dart';
import 'app_shell_dialogs.dart';
import 'current_status_card.dart';
import 'home_quick_switch_panel.dart';
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
  final _quickSwitchKey = GlobalKey();

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
        HomeQuickSwitchPanel quickSwitchPanel({required bool showSortInline}) {
          return HomeQuickSwitchPanel(
            key: _quickSwitchKey,
            activities: switchableActivities,
            runningActivity: runningActivity,
            pendingActivity: pendingActivity,
            metric: _activitySortMetric,
            order: _activitySortOrder,
            showSortInline: showSortInline,
            showCompactSortControls: _showCompactSortControls,
            onMetricChanged: (value) {
              setState(() => _activitySortMetric = value);
            },
            onOrderChanged: (value) {
              setState(() => _activitySortOrder = value);
            },
            onToggleCompactSort: () {
              setState(() {
                _showCompactSortControls = !_showCompactSortControls;
              });
            },
            onSync: state.hasSyncTarget ? state.sync : null,
            onActivityTap: _confirmOrSwitch,
            onEditActivity: (activity) => showActivityEditorDialog(
              context,
              state,
              activity: activity,
            ),
            onOneOffActivity: () => showOneOffActivityDialog(context, state),
            onAddActivity: () => showActivityEditorDialog(context, state),
          );
        }

        return AdaptivePage(
          pageKey: const PageStorageKey('home-page'),
          onRefresh: state.refresh,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < compactBreakpoint;
                return PageHeader(
                  title: compact ? l10n.navCurrent : l10n.appTitle,
                  subtitle: compact ? null : l10n.appSubtitle,
                  trailing: compact
                      ? null
                      : StatusPill(
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
                );
              },
            ),
            const SectionGap(),
            LayoutBuilder(
              builder: (context, constraints) {
                final sizeClass = adaptiveSizeClassFor(constraints.maxWidth);
                final compact = sizeClass == AdaptiveSizeClass.compact;
                final statusCard = CurrentStatusCard(
                  runningActivity: runningActivity,
                  clockNotifier: state.clockNotifier,
                  runningDurationAt: (now) => state.runningDuration(at: now),
                  entries: state.dayEntries,
                  onStop: runningActivity == null ? null : state.stopCurrent,
                  onSwitch: _scrollToQuickSwitch,
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [statusCard],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    statusCard,
                    const SizedBox(height: 12),
                    quickSwitchPanel(showSortInline: true),
                  ],
                );
              },
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < compactBreakpoint;
                if (!compact) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      quickSwitchPanel(showSortInline: false),
                      const SizedBox(height: 18),
                      LoginBanner(state: state),
                    ],
                  ),
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

  void _scrollToQuickSwitch() {
    final context = _quickSwitchKey.currentContext;
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
