part of 'timeline_page.dart';

class _TimelineEntryListSection extends StatelessWidget {
  const _TimelineEntryListSection({
    required this.state,
    required this.entries,
    required this.sortMetric,
    required this.sortOrder,
    required this.onSortMetricChanged,
    required this.onSortOrderChanged,
    required this.emptyText,
  });

  final AppState state;
  final List<TimeEntry> entries;
  final TimelineEntrySortMetric sortMetric;
  final SortOrder sortOrder;
  final ValueChanged<TimelineEntrySortMetric> onSortMetricChanged;
  final ValueChanged<SortOrder> onSortOrderChanged;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TimelineCardHeader(
          title: AppLocalizations.of(context)!.entryList,
          subtitle: AppLocalizations.of(context)!.entryListHint,
          icon: Icons.view_list_outlined,
        ),
        const SizedBox(height: 10),
        _TimelineEntrySortControls(
          metric: sortMetric,
          order: sortOrder,
          onMetricChanged: onSortMetricChanged,
          onOrderChanged: onSortOrderChanged,
        ),
        const SizedBox(height: 10),
        _EntryList(
          state: state,
          entries: entries,
          emptyText: emptyText,
        ),
      ],
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.state,
    required this.entries,
    required this.emptyText,
  });

  final AppState state;
  final List<TimeEntry> entries;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return TimelineEmptyState(text: emptyText);
    }
    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TimelineEntryCard(
              state: state,
              entry: entry,
            ),
          ),
      ],
    );
  }
}

// ignore: unused_element
class _ActionLogList extends StatelessWidget {
  const _ActionLogList({
    required this.state,
    required this.logs,
    required this.sortMetric,
    required this.sortOrder,
    required this.onSortMetricChanged,
    required this.onSortOrderChanged,
    required this.emptyText,
  });

  final AppState state;
  final List<ActionLog> logs;
  final ActionLogSortMetric sortMetric;
  final SortOrder sortOrder;
  final ValueChanged<ActionLogSortMetric> onSortMetricChanged;
  final ValueChanged<SortOrder> onSortOrderChanged;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return TimelineEmptyState(text: emptyText);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionLogSortControls(
          metric: sortMetric,
          order: sortOrder,
          onMetricChanged: onSortMetricChanged,
          onOrderChanged: onSortOrderChanged,
        ),
        const SizedBox(height: 12),
        for (final log in logs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ActionLogCard(state: state, log: log),
          ),
      ],
    );
  }
}

class _TimelineEntrySortControls extends StatelessWidget {
  const _TimelineEntrySortControls({
    required this.metric,
    required this.order,
    required this.onMetricChanged,
    required this.onOrderChanged,
  });

  final TimelineEntrySortMetric metric;
  final SortOrder order;
  final ValueChanged<TimelineEntrySortMetric> onMetricChanged;
  final ValueChanged<SortOrder> onOrderChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SortControlRow<TimelineEntrySortMetric>(
      label: l10n.entrySortLabel,
      value: metric,
      values: TimelineEntrySortMetric.values,
      order: order,
      labelFor: (value) => switch (value) {
        TimelineEntrySortMetric.startTime => l10n.sortStartTime,
        TimelineEntrySortMetric.duration => l10n.sortDuration,
        TimelineEntrySortMetric.activityName => l10n.sortActivityName,
        TimelineEntrySortMetric.color => l10n.sortColor,
      },
      onMetricChanged: onMetricChanged,
      onOrderChanged: onOrderChanged,
    );
  }
}

class _ActionLogSortControls extends StatelessWidget {
  const _ActionLogSortControls({
    required this.metric,
    required this.order,
    required this.onMetricChanged,
    required this.onOrderChanged,
  });

  final ActionLogSortMetric metric;
  final SortOrder order;
  final ValueChanged<ActionLogSortMetric> onMetricChanged;
  final ValueChanged<SortOrder> onOrderChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SortControlRow<ActionLogSortMetric>(
      label: l10n.actionSortLabel,
      value: metric,
      values: ActionLogSortMetric.values,
      order: order,
      labelFor: (value) => switch (value) {
        ActionLogSortMetric.occurredAt => l10n.sortOccurredAt,
        ActionLogSortMetric.actionType => l10n.sortActionType,
        ActionLogSortMetric.activityName => l10n.sortActivityName,
        ActionLogSortMetric.device => l10n.sortDevice,
      },
      onMetricChanged: onMetricChanged,
      onOrderChanged: onOrderChanged,
    );
  }
}

class _SortControlRow<T extends Object> extends StatelessWidget {
  const _SortControlRow({
    required this.label,
    required this.value,
    required this.values,
    required this.order,
    required this.labelFor,
    required this.onMetricChanged,
    required this.onOrderChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final SortOrder order;
  final String Function(T value) labelFor;
  final ValueChanged<T> onMetricChanged;
  final ValueChanged<SortOrder> onOrderChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < compactBreakpoint;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: compact ? double.infinity : 220,
          child: DropdownButtonFormField<T>(
            isExpanded: true,
            initialValue: value,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.sort),
            ),
            items: [
              for (final item in values)
                DropdownMenuItem(
                  value: item,
                  child: Text(labelFor(item)),
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
  }
}

class TimelineEntryCard extends StatelessWidget {
  const TimelineEntryCard({
    required this.state,
    required this.entry,
    super.key,
  });

  final AppState state;
  final TimeEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = Color(state.activityColorForEntry(entry));
    final interval = _visibleEntryInterval(entry, state.selectedDay, state.now);
    final endText = interval.isRunningNow
        ? AppLocalizations.of(context)!.inProgress
        : _formatVisibleEndTime(interval, state.selectedDay);
    final timeText = '${_formatTime(interval.start)} - $endText';
    void openEditor() => showEntryEditor(context, state, entry: entry);
    return QuietPanel(
      padding: EdgeInsets.zero,
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              openEditor();
              return null;
            },
          ),
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: openEditor,
          child: Semantics(
            button: true,
            label: AppLocalizations.of(context)!.editEntrySemantics(
                activityNameForEntryDisplay(context, state, entry)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimelineEntryContent(
                      title: activityNameForEntryDisplay(context, state, entry),
                      duration:
                          formatDurationForDisplay(context, interval.duration),
                      timeText: timeText,
                      note: entry.note,
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.editTooltip,
                    onPressed: openEditor,
                    icon: const Icon(Icons.edit_outlined),
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

class _TimelineEntryContent extends StatelessWidget {
  const _TimelineEntryContent({
    required this.title,
    required this.duration,
    required this.timeText,
    required this.note,
  });

  final String title;
  final String duration;
  final String timeText;
  final String note;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 320;
        final titleText = Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        );
        final durationText = Text(
          duration,
          style: Theme.of(context).textTheme.labelLarge,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              titleText,
              const SizedBox(height: 2),
              durationText,
            ] else
              Row(
                children: [
                  Expanded(child: titleText),
                  const SizedBox(width: 8),
                  durationText,
                ],
              ),
            const SizedBox(height: 4),
            Text(timeText),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(note),
            ],
          ],
        );
      },
    );
  }
}

class ActionLogCard extends StatelessWidget {
  const ActionLogCard({
    required this.state,
    required this.log,
    super.key,
  });

  final AppState state;
  final ActionLog log;

  @override
  Widget build(BuildContext context) {
    final activity =
        log.activityId == null ? null : state.activityById(log.activityId!);
    final color = Color(
      activity?.color ?? AppConstants.defaultActivityColor,
    );
    return QuietPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(_logIcon(log.actionType), color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 82,
                  child: Text(_formatTime(log.occurredAt)),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity == null
                            ? log.message
                            : '${log.message}: '
                                '${activityNameForDisplay(context, activity)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(AppLocalizations.of(context)!
                          .deviceLabel(log.deviceId)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _logIcon(ActionType actionType) {
    return switch (actionType) {
      ActionType.switch_ => Icons.swap_horiz,
      ActionType.stop => Icons.stop_circle_outlined,
      ActionType.manual => Icons.add_circle_outline,
      ActionType.edit => Icons.edit_outlined,
      ActionType.delete => Icons.delete_outline,
      ActionType.merge => Icons.merge_type_outlined,
      ActionType.split => Icons.call_split_outlined,
      ActionType.activityDelete => Icons.label_off_outlined,
      _ => Icons.bolt_outlined,
    };
  }
}
