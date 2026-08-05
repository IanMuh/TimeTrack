part of 'timeline_page.dart';

enum _MobileTimelineMoreAction { addEntry, pickDate, previous, next }

class _MobileTimelinePage extends StatelessWidget {
  const _MobileTimelinePage({
    required this.state,
    required this.mode,
    required this.span,
    required this.rangeStart,
    required this.rangeEnd,
    required this.isFutureDay,
    required this.rangeDataFuture,
    required this.maxWidth,
    required this.showGeneratedGaps,
    required this.onModeChanged,
    required this.onSpanChanged,
    required this.onDateTap,
    required this.onPreviousRange,
    required this.onNextRange,
    required this.onAddEntry,
  });

  final AppState state;
  final TimelineViewMode mode;
  final TimelineSpan span;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool isFutureDay;
  final Future<_TimelineRangeData> rangeDataFuture;
  final double maxWidth;
  final bool showGeneratedGaps;
  final ValueChanged<TimelineViewMode> onModeChanged;
  final ValueChanged<TimelineSpan> onSpanChanged;
  final VoidCallback onDateTap;
  final VoidCallback onPreviousRange;
  final VoidCallback onNextRange;
  final VoidCallback onAddEntry;

  @override
  Widget build(BuildContext context) {
    return AdaptivePage(
      pageKey: const PageStorageKey('timeline-page-mobile'),
      maxWidth: maxWidth,
      onRefresh: state.refresh,
      children: [
        _MobileTimelineHeader(
          onFilterTap: () => _showFilterSheet(context),
          onMoreSelected: (action) => _handleMoreAction(action),
        ),
        const SizedBox(height: 14),
        _MobileTimelineSpanControl(
          span: span,
          onChanged: onSpanChanged,
        ),
        const SizedBox(height: 18),
        if (isFutureDay) FutureDayBanner(selectedDay: state.selectedDay),
        FutureBuilder<_TimelineRangeData>(
          future: rangeDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 64),
                child: Center(
                  child: Icon(
                    Icons.hourglass_empty,
                    size: 30,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            }
            final data = snapshot.data ?? const _TimelineRangeData.empty();
            return switch (mode) {
              TimelineViewMode.entries => _MobileTimelineEntryFlow(
                  state: state,
                  entries: _sortedMobileEntries(
                    data.entries,
                    showGeneratedGaps: showGeneratedGaps,
                  ),
                  rangeStart: rangeStart,
                  rangeEnd: rangeEnd,
                  emptyText: span == TimelineSpan.day
                      ? AppLocalizations.of(context)!.emptyDayEntries
                      : AppLocalizations.of(context)!.emptyRangeEntries,
                ),
              TimelineViewMode.actions => _MobileTimelineActionFlow(
                  state: state,
                  logs: data.logs,
                  emptyText: span == TimelineSpan.day
                      ? AppLocalizations.of(context)!.emptyDayActions
                      : AppLocalizations.of(context)!.emptyRangeActions,
                ),
            };
          },
        ),
      ],
    );
  }

  void _handleMoreAction(_MobileTimelineMoreAction action) {
    switch (action) {
      case _MobileTimelineMoreAction.addEntry:
        onAddEntry();
        break;
      case _MobileTimelineMoreAction.pickDate:
        onDateTap();
        break;
      case _MobileTimelineMoreAction.previous:
        onPreviousRange();
        break;
      case _MobileTimelineMoreAction.next:
        onNextRange();
        break;
    }
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.filters,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<TimelineViewMode>(
                  segments: [
                    ButtonSegment(
                      value: TimelineViewMode.entries,
                      icon: const Icon(Icons.timeline),
                      label: Text(l10n.entries),
                    ),
                    ButtonSegment(
                      value: TimelineViewMode.actions,
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(l10n.actions),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) {
                    onModeChanged(value.first);
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 12),
                SegmentedButton<TimelineSpan>(
                  segments: [
                    ButtonSegment(
                      value: TimelineSpan.day,
                      label: Text(l10n.today),
                    ),
                    ButtonSegment(
                      value: TimelineSpan.week,
                      label: Text(l10n.thisWeek),
                    ),
                  ],
                  selected: {
                    span == TimelineSpan.week ? span : TimelineSpan.day
                  },
                  onSelectionChanged: (value) {
                    onSpanChanged(value.first);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MobileTimelineHeader extends StatelessWidget {
  const _MobileTimelineHeader({
    required this.onFilterTap,
    required this.onMoreSelected,
  });

  final VoidCallback onFilterTap;
  final ValueChanged<_MobileTimelineMoreAction> onMoreSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.navTimeline,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        IconButton(
          tooltip: l10n.filters,
          onPressed: onFilterTap,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.filter_alt_outlined, size: 20),
        ),
        PopupMenuButton<_MobileTimelineMoreAction>(
          tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
          icon: const Icon(Icons.more_horiz, size: 22),
          onSelected: onMoreSelected,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _MobileTimelineMoreAction.addEntry,
              child: ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.addEntry),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _MobileTimelineMoreAction.pickDate,
              child: ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(l10n.selectDate),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _MobileTimelineMoreAction.previous,
              child: ListTile(
                leading: const Icon(Icons.chevron_left),
                title: Text(l10n.previousDay),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _MobileTimelineMoreAction.next,
              child: ListTile(
                leading: const Icon(Icons.chevron_right),
                title: Text(l10n.nextDay),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MobileTimelineSpanControl extends StatelessWidget {
  const _MobileTimelineSpanControl({
    required this.span,
    required this.onChanged,
  });

  final TimelineSpan span;
  final ValueChanged<TimelineSpan> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedSpan = span == TimelineSpan.week ? span : TimelineSpan.day;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          _MobileTimelineSpanButton(
            label: l10n.today,
            selected: selectedSpan == TimelineSpan.day,
            onPressed: () => onChanged(TimelineSpan.day),
          ),
          _MobileTimelineSpanButton(
            label: l10n.thisWeek,
            selected: selectedSpan == TimelineSpan.week,
            onPressed: () => onChanged(TimelineSpan.week),
          ),
        ],
      ),
    );
  }
}

class _MobileTimelineSpanButton extends StatelessWidget {
  const _MobileTimelineSpanButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: SizedBox(
        height: 34,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor:
                selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            backgroundColor: selected
                ? colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
            minimumSize: const Size.fromHeight(34),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileTimelineEntryFlow extends StatelessWidget {
  const _MobileTimelineEntryFlow({
    required this.state,
    required this.entries,
    required this.rangeStart,
    required this.rangeEnd,
    required this.emptyText,
  });

  final AppState state;
  final List<TimeEntry> entries;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return TimelineEmptyState(text: emptyText);
    }
    return Column(
      children: [
        for (final (index, entry) in entries.indexed)
          _MobileTimelineEntryRow(
            state: state,
            entry: entry,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            first: index == 0,
            last: index == entries.length - 1,
          ),
      ],
    );
  }
}

class _MobileTimelineEntryRow extends StatelessWidget {
  const _MobileTimelineEntryRow({
    required this.state,
    required this.entry,
    required this.rangeStart,
    required this.rangeEnd,
    required this.first,
    required this.last,
  });

  final AppState state;
  final TimeEntry entry;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = Color(state.activityColorForEntry(entry));
    final interval =
        _mobileVisibleEntryInterval(entry, rangeStart, rangeEnd, state.now);
    final title = activityNameForEntryDisplay(context, state, entry);
    final note = entry.note.trim();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatMobileTimelineStartTime(context, interval.start),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimelineDurationTerse(context, interval.duration),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 14,
            child: _MobileTimelineRail(
              color: color,
              first: first,
              last: last,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 10),
              child: Material(
                key: ValueKey('mobile-timeline-entry-${entry.id}'),
                color: color.withValues(alpha: 0.10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: color.withValues(alpha: 0.12),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showEntryEditor(context, state, entry: entry),
                  child: Semantics(
                    button: true,
                    label:
                        AppLocalizations.of(context)!.editEntrySemantics(title),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            note.isEmpty
                                ? _formatMobileTimelineRange(context, interval)
                                : note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileTimelineRail extends StatelessWidget {
  const _MobileTimelineRail({
    required this.color,
    required this.first,
    required this.last,
  });

  final Color color;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: first ? 10 : 0,
          bottom: last ? 38 : 0,
          child: Container(
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        Positioned(
          top: 6,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileTimelineActionFlow extends StatelessWidget {
  const _MobileTimelineActionFlow({
    required this.state,
    required this.logs,
    required this.emptyText,
  });

  final AppState state;
  final List<ActionLog> logs;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return TimelineEmptyState(text: emptyText);
    }
    return Column(
      children: [
        for (final log in logs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ActionLogCard(state: state, log: log),
          ),
      ],
    );
  }
}

List<TimeEntry> _sortedMobileEntries(
  List<TimeEntry> entries, {
  required bool showGeneratedGaps,
}) {
  return [
    for (final entry in entries)
      if (showGeneratedGaps || entry.deviceId != 'unassigned-gap') entry,
  ]..sort((a, b) => a.startAt.compareTo(b.startAt));
}

_VisibleEntryInterval _mobileVisibleEntryInterval(
  TimeEntry entry,
  DateTime rangeStart,
  DateTime rangeEnd,
  DateTime now,
) {
  final rawEnd = entry.endAt ?? now;
  final visibleStart =
      entry.startAt.isBefore(rangeStart) ? rangeStart : entry.startAt;
  final visibleEnd = rawEnd.isAfter(rangeEnd) ? rangeEnd : rawEnd;
  if (!visibleStart.isBefore(visibleEnd)) {
    return _VisibleEntryInterval(
      start: visibleStart,
      end: visibleStart,
      isRunningNow: false,
    );
  }
  return _VisibleEntryInterval(
    start: visibleStart,
    end: visibleEnd,
    isRunningNow: entry.endAt == null,
  );
}

String _formatMobileTimelineStartTime(BuildContext context, DateTime value) {
  return DateFormat.jm(Localizations.localeOf(context).toLanguageTag())
      .format(value);
}

String _formatMobileTimelineRange(
  BuildContext context,
  _VisibleEntryInterval interval,
) {
  final start = _formatMobileTimelineStartTime(context, interval.start);
  final end = interval.isRunningNow
      ? AppLocalizations.of(context)!.inProgress
      : _formatMobileTimelineStartTime(context, interval.end);
  return '$start - $end';
}
