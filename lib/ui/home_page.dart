import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../core/date_time_ext.dart';
import '../domain/activity.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'activity_colors.dart';
import 'app_shell.dart';
import 'sort_controls.dart';
import 'ui_components.dart';

enum ActivitySortMetric { name, color, primaryCategory, updatedAt }

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
                final sortControls = _ActivitySortControls(
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
                    _OneOffActivityTile(
                      onPressed: () => showOneOffActivityDialog(context, state),
                    ),
                    _AddActivityTile(
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

class _ActivitySortControls extends StatelessWidget {
  const _ActivitySortControls({
    required this.metric,
    required this.order,
    required this.onMetricChanged,
    required this.onOrderChanged,
  });

  final ActivitySortMetric metric;
  final SortOrder order;
  final ValueChanged<ActivitySortMetric> onMetricChanged;
  final ValueChanged<SortOrder> onOrderChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: compact ? double.infinity : 180,
              child: DropdownButtonFormField<ActivitySortMetric>(
                initialValue: metric,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.sortBy,
                  prefixIcon: const Icon(Icons.sort),
                ),
                items: [
                  for (final value in ActivitySortMetric.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_activitySortMetricLabel(context, value)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onMetricChanged(value);
                },
              ),
            ),
            SortOrderSegmentedButton(
              value: order,
              onChanged: onOrderChanged,
            ),
          ],
        );
      },
    );
  }

  String _activitySortMetricLabel(
      BuildContext context, ActivitySortMetric value) {
    final l10n = AppLocalizations.of(context)!;
    return switch (value) {
      ActivitySortMetric.name => l10n.name,
      ActivitySortMetric.color => l10n.color,
      ActivitySortMetric.primaryCategory => l10n.primaryCategoryDimension,
      ActivitySortMetric.updatedAt => l10n.recentlyUpdated,
    };
  }
}

class CurrentStatusCard extends StatelessWidget {
  const CurrentStatusCard({
    required this.runningActivity,
    required this.clockNotifier,
    required this.runningDurationAt,
    required this.onStop,
    super.key,
  });

  final Activity? runningActivity;
  final ValueNotifier<DateTime> clockNotifier;
  final Duration Function(DateTime at) runningDurationAt;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final runningColor = runningActivity == null
        ? colorScheme.primary
        : Color(runningActivity!.color);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        return QuietPanel(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(
                      icon: runningActivity == null
                          ? Icons.timer_outlined
                          : Icons.play_arrow_rounded,
                      color: runningColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.currentDoing,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    StatusPill(
                      label: runningActivity == null
                          ? AppLocalizations.of(context)!.notStarted
                          : AppLocalizations.of(context)!.recording,
                      icon: runningActivity == null
                          ? Icons.pause_circle_outline
                          : Icons.radio_button_checked,
                      color: runningColor,
                    ),
                  ],
                ),
                SizedBox(height: compact ? 8 : 12),
                Text(
                  runningActivity?.name ??
                      AppLocalizations.of(context)!.notStartedRecord,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: (compact
                          ? Theme.of(context).textTheme.headlineSmall
                          : Theme.of(context).textTheme.displaySmall)
                      ?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: compact ? 4 : 8),
                if (runningActivity == null)
                  Text(
                    AppLocalizations.of(context)!.selectActivityToStart,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  )
                else
                  ValueListenableBuilder<DateTime>(
                    valueListenable: clockNotifier,
                    builder: (context, now, _) {
                      final duration = runningDurationAt(now);
                      return Text(
                        AppLocalizations.of(context)!
                            .elapsedDuration(formatDurationCompact(duration)),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                      );
                    },
                  ),
                SizedBox(height: compact ? 12 : 18),
                FilledButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label:
                      Text(AppLocalizations.of(context)!.stopCurrentActivity),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ActivitySwitchButton extends StatelessWidget {
  const ActivitySwitchButton({
    required this.activity,
    required this.selected,
    required this.pending,
    required this.onTap,
    required this.onDoubleTap,
    required this.onEdit,
    super.key,
  });

  final Activity activity;
  final bool selected;
  final bool pending;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final color = Color(activity.color);
    final active = selected || pending;
    final foreground = selected ? Colors.white : color;
    return Material(
      color: selected ? color : color.withValues(alpha: pending ? 0.16 : 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active
              ? color.withValues(alpha: selected ? 0.0 : 0.42)
              : color.withValues(alpha: 0.18),
          width: pending ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          child: Semantics(
            button: true,
            selected: selected,
            label: pending
                ? AppLocalizations.of(context)!
                    .confirmSwitchSemantics(activity.name)
                : selected
                    ? AppLocalizations.of(context)!
                        .currentActivitySemantics(activity.name)
                    : AppLocalizations.of(context)!
                        .switchToSemantics(activity.name),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : pending
                            ? Icons.touch_app_outlined
                            : Icons.circle,
                    color: foreground,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      activity.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (pending)
                    Icon(
                      Icons.keyboard_double_arrow_right,
                      color: foreground,
                      size: 18,
                    ),
                  if (activity.isUnassigned)
                    SizedBox.square(
                      dimension: 40,
                      child: Tooltip(
                        message: AppLocalizations.of(context)!
                            .systemActivityCannotEdit,
                        child: Icon(
                          Icons.lock_outline,
                          color: foreground.withValues(alpha: 0.72),
                          size: 18,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.editActivity,
                      visualDensity: VisualDensity.compact,
                      onPressed: onEdit,
                      icon: Icon(
                        Icons.edit_outlined,
                        color: foreground,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OneOffActivityTile extends StatelessWidget {
  const _OneOffActivityTile({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.flash_on_outlined),
      label: Text(AppLocalizations.of(context)!.oneOffActivity),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _AddActivityTile extends StatelessWidget {
  const _AddActivityTile({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(AppLocalizations.of(context)!.newActivity),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

Future<Activity?> showActivityEditorDialog(
  BuildContext context,
  AppState state, {
  Activity? activity,
}) async {
  if (activity?.isUnassigned ?? false) {
    return activity;
  }
  final controller = TextEditingController(text: activity?.name ?? '');
  var selectedColor = activity?.color ??
      nextActivityColor(state.activities.map((activity) => activity.color));
  var primaryCategoryId = activity == null
      ? null
      : state.primaryCategoryForActivity(activity.id)?.id;
  final secondaryCategoryIds = activity == null
      ? <String>{}
      : {
          for (final category
              in state.secondaryCategoriesForActivity(activity.id))
            category.id,
        };
  Activity? saved;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(activity == null
                ? AppLocalizations.of(context)!.newActivity
                : AppLocalizations.of(context)!.editActivityTitle),
            content: SizedBox(
              width: dialogContentWidth(context, maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.name,
                        prefixIcon: const Icon(Icons.label_outline),
                      ),
                      autofocus: true,
                    ),
                    if (state.activityCategories.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String?>(
                        initialValue: primaryCategoryId,
                        decoration: const InputDecoration(
                          labelText: '主分类',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('未分类'),
                          ),
                          for (final category in state.activityCategories)
                            DropdownMenuItem<String?>(
                              value: category.id,
                              child: Text(category.name),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            primaryCategoryId = value;
                            secondaryCategoryIds.remove(value);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in state.activityCategories)
                            FilterChip(
                              label: Text(category.name),
                              avatar: CircleAvatar(
                                radius: 6,
                                backgroundColor: Color(category.color),
                              ),
                              selected:
                                  secondaryCategoryIds.contains(category.id),
                              onSelected: category.id == primaryCategoryId
                                  ? null
                                  : (selected) {
                                      setState(() {
                                        if (selected) {
                                          secondaryCategoryIds.add(category.id);
                                        } else {
                                          secondaryCategoryIds
                                              .remove(category.id);
                                        }
                                      });
                                    },
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    ActivityColorPicker(
                      selectedColor: selectedColor,
                      onColorChanged: (color) =>
                          setState(() => selectedColor = color),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (activity != null && !activity.isUnassigned)
                TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                            AppLocalizations.of(context)!.deleteActivityTitle),
                        content: Text(
                          AppLocalizations.of(context)!
                              .confirmDeleteActivity(activity.name),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(AppLocalizations.of(context)!.cancel),
                          ),
                          FilledButton.icon(
                            onPressed: () => Navigator.pop(context, true),
                            icon: const Icon(Icons.delete_outline),
                            label: Text(AppLocalizations.of(context)!.delete),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) {
                      return;
                    }
                    await state.deleteActivity(activity);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: Text(AppLocalizations.of(context)!.delete),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    return;
                  }
                  saved = activity == null
                      ? await state.createActivity(
                          name,
                          selectedColor,
                          primaryCategoryId: primaryCategoryId,
                          secondaryCategoryIds:
                              secondaryCategoryIds.toList(growable: false),
                        )
                      : await state.updateActivity(
                          activity,
                          name: name,
                          color: selectedColor,
                          updateCategories: true,
                          primaryCategoryId: primaryCategoryId,
                          secondaryCategoryIds:
                              secondaryCategoryIds.toList(growable: false),
                        );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: Icon(activity == null ? Icons.add : Icons.save_outlined),
                label: Text(activity == null
                    ? AppLocalizations.of(context)!.create
                    : AppLocalizations.of(context)!.save),
              ),
            ],
          );
        },
      );
    },
  );
  return saved;
}

Future<Activity?> showOneOffActivityDialog(
  BuildContext context,
  AppState state,
) async {
  final suggestions = await state.oneOffActivitySuggestions();
  if (!context.mounted) {
    return null;
  }
  final controller = TextEditingController();
  var selectedColor =
      nextActivityColor(state.activities.map((activity) => activity.color));
  Activity? selectedSuggestion;
  Activity? saved;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final query = controller.text.trim().toLowerCase();
          final filteredSuggestions = query.isEmpty
              ? <Activity>[]
              : [
                  for (final activity in suggestions)
                    if (activity.name.toLowerCase().contains(query)) activity,
                ];
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.oneOffActivity),
            content: SizedBox(
              width: dialogContentWidth(context, maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.name,
                        prefixIcon: const Icon(Icons.bolt_outlined),
                      ),
                      onChanged: (_) {
                        setState(() => selectedSuggestion = null);
                      },
                      autofocus: true,
                    ),
                    if (filteredSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final activity in filteredSuggestions)
                              ChoiceChip(
                                avatar: Icon(
                                  Icons.bolt_outlined,
                                  size: 18,
                                  color: Color(activity.color),
                                ),
                                label: _OneOffSuggestionLabel(
                                  name: activity.name,
                                ),
                                selected: selectedSuggestion?.id == activity.id,
                                onSelected: (_) {
                                  setState(() {
                                    selectedSuggestion = activity;
                                    selectedColor = activity.color;
                                    controller.text = activity.name;
                                    controller.selection =
                                        TextSelection.collapsed(
                                      offset: controller.text.length,
                                    );
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ActivityColorPicker(
                      selectedColor: selectedColor,
                      onColorChanged: (color) => setState(() {
                        selectedSuggestion = null;
                        selectedColor = color;
                      }),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    return;
                  }
                  saved = await state.createOneOffActivity(
                    name,
                    selectedColor,
                    reuseActivity: selectedSuggestion,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(AppLocalizations.of(context)!.start),
              ),
            ],
          );
        },
      );
    },
  );
  return saved;
}

class _OneOffSuggestionLabel extends StatelessWidget {
  const _OneOffSuggestionLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            AppLocalizations.of(context)!.oneOff,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
          ),
        ),
      ],
    );
  }
}

class ActivityColorPicker extends StatelessWidget {
  const ActivityColorPicker({
    required this.selectedColor,
    required this.onColorChanged,
    super.key,
  });

  final int selectedColor;
  final ValueChanged<int> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final color = Color(selectedColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final colorValue in activityPalette)
              IconButton(
                tooltip: AppLocalizations.of(context)!
                    .selectColorTooltip(_formatHexColor(colorValue)),
                onPressed: () => onColorChanged(colorValue),
                icon: Icon(
                  selectedColor == colorValue
                      ? Icons.check_circle
                      : Icons.circle,
                  color: Color(colorValue),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tune),
          title: Text(AppLocalizations.of(context)!.rgbTuner),
          subtitle: Text(_formatHexColor(selectedColor)),
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatHexColor(selectedColor),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RgbChannelControl(
              label: 'R',
              value: _redOf(selectedColor),
              color: Colors.red,
              onChanged: (value) => onColorChanged(
                _withRgb(selectedColor, red: value),
              ),
            ),
            _RgbChannelControl(
              label: 'G',
              value: _greenOf(selectedColor),
              color: Colors.green,
              onChanged: (value) => onColorChanged(
                _withRgb(selectedColor, green: value),
              ),
            ),
            _RgbChannelControl(
              label: 'B',
              value: _blueOf(selectedColor),
              color: Colors.blue,
              onChanged: (value) => onColorChanged(
                _withRgb(selectedColor, blue: value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RgbChannelControl extends StatefulWidget {
  const _RgbChannelControl({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  State<_RgbChannelControl> createState() => _RgbChannelControlState();
}

class _RgbChannelControlState extends State<_RgbChannelControl> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant _RgbChannelControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value.toString()) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final slider = Slider(
          label: '${widget.label} ${widget.value}',
          min: 0,
          max: 255,
          divisions: 255,
          value: widget.value.toDouble(),
          activeColor: widget.color,
          onChanged: (value) => widget.onChanged(value.round()),
        );
        final input = SizedBox(
          width: 86,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: Icon(Icons.tag, color: widget.color),
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed == null) {
                return;
              }
              widget.onChanged(parsed.clamp(0, 255));
            },
          ),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              input,
              slider,
            ],
          );
        }
        return Row(
          children: [
            input,
            const SizedBox(width: 12),
            Expanded(child: slider),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

String _formatHexColor(int color) {
  final rgb = color & 0x00ffffff;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

int _redOf(int color) => (color >> 16) & 0xff;

int _greenOf(int color) => (color >> 8) & 0xff;

int _blueOf(int color) => color & 0xff;

int _withRgb(
  int color, {
  int? red,
  int? green,
  int? blue,
}) {
  final nextRed = (red ?? _redOf(color)).clamp(0, 255).toInt();
  final nextGreen = (green ?? _greenOf(color)).clamp(0, 255).toInt();
  final nextBlue = (blue ?? _blueOf(color)).clamp(0, 255).toInt();
  return 0xff000000 | (nextRed << 16) | (nextGreen << 8) | nextBlue;
}
