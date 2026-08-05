part of 'timeline_page.dart';

class _DesktopTimelinePage extends StatelessWidget {
  const _DesktopTimelinePage({
    required this.state,
    required this.mode,
    required this.span,
    required this.rangeStart,
    required this.rangeEnd,
    required this.isFutureDay,
    required this.rangeDataFuture,
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
  final ValueChanged<TimelineViewMode> onModeChanged;
  final ValueChanged<TimelineSpan> onSpanChanged;
  final VoidCallback onDateTap;
  final VoidCallback onPreviousRange;
  final VoidCallback onNextRange;
  final VoidCallback onAddEntry;

  @override
  Widget build(BuildContext context) {
    return AdaptivePage(
      pageKey: const PageStorageKey('timeline-page-desktop'),
      maxWidth: 1120,
      onRefresh: state.refresh,
      children: [
        _DesktopTimelineHeader(
          selectedDay: state.selectedDay,
          span: span,
          mode: mode,
          onModeChanged: onModeChanged,
          onSpanChanged: onSpanChanged,
          onDateTap: onDateTap,
          onPreviousRange: onPreviousRange,
          onNextRange: onNextRange,
          onAddEntry: onAddEntry,
        ),
        const SizedBox(height: 16),
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
            final entries = _sortedMobileEntries(
              data.entries,
              showGeneratedGaps: true,
            );
            final logs = [...data.logs]
              ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TimelineRangeSummaryCard(
                  state: state,
                  entries: entries,
                  logs: logs,
                  rangeStart: rangeStart,
                  rangeEnd: rangeEnd,
                  mode: mode,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: RangeTimelineCard(
                        state: state,
                        entries: entries,
                        rangeStart: rangeStart,
                        span: span,
                        density: TimelineDensity.compact,
                        displayMode: span == TimelineSpan.day
                            ? TimelineDisplayMode.segmentedDay
                            : TimelineDisplayMode.singleLine,
                        segmentsPerDay: 4,
                        zoom: 1,
                        showEmptyState: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: _DesktopTimelineListPanel(
                        state: state,
                        mode: mode,
                        entries: entries,
                        logs: logs,
                        emptyText: mode == TimelineViewMode.entries
                            ? (span == TimelineSpan.day
                                ? AppLocalizations.of(context)!.emptyDayEntries
                                : AppLocalizations.of(context)!
                                    .emptyRangeEntries)
                            : (span == TimelineSpan.day
                                ? AppLocalizations.of(context)!.emptyDayActions
                                : AppLocalizations.of(context)!
                                    .emptyRangeActions),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DesktopTimelineHeader extends StatelessWidget {
  const _DesktopTimelineHeader({
    required this.selectedDay,
    required this.span,
    required this.mode,
    required this.onModeChanged,
    required this.onSpanChanged,
    required this.onDateTap,
    required this.onPreviousRange,
    required this.onNextRange,
    required this.onAddEntry,
  });

  final DateTime selectedDay;
  final TimelineSpan span;
  final TimelineViewMode mode;
  final ValueChanged<TimelineViewMode> onModeChanged;
  final ValueChanged<TimelineSpan> onSpanChanged;
  final VoidCallback onDateTap;
  final VoidCallback onPreviousRange;
  final VoidCallback onNextRange;
  final VoidCallback onAddEntry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final colorScheme = Theme.of(context).colorScheme;
    final addEntryTextStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colorScheme.onPrimary,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w800,
        );
    final rangeEnd = selectedDay.add(Duration(days: span.days - 1));
    final subtitle = span == TimelineSpan.day
        ? DateFormat.yMMMMd(localeName).format(selectedDay)
        : '${DateFormat.MMMd(localeName).format(selectedDay)} - '
            '${DateFormat.MMMd(localeName).format(rangeEnd)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: l10n.navTimeline,
          subtitle: subtitle,
          trailing: FilledButton.icon(
            onPressed: onAddEntry,
            icon: const Icon(Icons.add),
            label: Text(l10n.addEntry, style: addEntryTextStyle),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            DayRangeSelector(
              selectedDay: selectedDay,
              rangeEnd: rangeEnd,
              onPreviousDay: onPreviousRange,
              onDateTap: onDateTap,
              onNextDay: onNextRange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SegmentedButton<TimelineSpan>(
                segments: [
                  ButtonSegment(
                    value: TimelineSpan.day,
                    label: Text(l10n.today),
                  ),
                  ButtonSegment(
                    value: TimelineSpan.threeDays,
                    label: Text(l10n.threeDays),
                  ),
                  ButtonSegment(
                    value: TimelineSpan.week,
                    label: Text(l10n.thisWeek),
                  ),
                ],
                selected: {span},
                onSelectionChanged: (value) => onSpanChanged(value.first),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 260,
              child: SegmentedButton<TimelineViewMode>(
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
                onSelectionChanged: (value) => onModeChanged(value.first),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DesktopTimelineListPanel extends StatelessWidget {
  const _DesktopTimelineListPanel({
    required this.state,
    required this.mode,
    required this.entries,
    required this.logs,
    required this.emptyText,
  });

  final AppState state;
  final TimelineViewMode mode;
  final List<TimeEntry> entries;
  final List<ActionLog> logs;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TimelineSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: mode == TimelineViewMode.entries
                ? l10n.entryList
                : l10n.actions,
            subtitle: mode == TimelineViewMode.entries
                ? l10n.entryListHint
                : l10n.timelineDragHint,
            icon: mode == TimelineViewMode.entries
                ? Icons.view_list_outlined
                : Icons.swap_horiz,
          ),
          const SizedBox(height: 12),
          if (mode == TimelineViewMode.entries)
            _DesktopEntryList(
              state: state,
              entries: entries,
              emptyText: emptyText,
            )
          else
            _DesktopActionList(
              state: state,
              logs: logs,
              emptyText: emptyText,
            ),
        ],
      ),
    );
  }
}

class _DesktopEntryList extends StatelessWidget {
  const _DesktopEntryList({
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
              key: ValueKey('mobile-timeline-entry-${entry.id}'),
              state: state,
              entry: entry,
            ),
          ),
      ],
    );
  }
}

class _DesktopActionList extends StatelessWidget {
  const _DesktopActionList({
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
