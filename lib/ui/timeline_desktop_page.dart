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
            final primaryPane = mode == TimelineViewMode.entries
                ? _MobileTimelineEntryFlow(
                    state: state,
                    entries: entries,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                    emptyText: span == TimelineSpan.day
                        ? AppLocalizations.of(context)!.emptyDayEntries
                        : AppLocalizations.of(context)!.emptyRangeEntries,
                  )
                : _MobileTimelineActionFlow(
                    state: state,
                    logs: logs,
                    emptyText: span == TimelineSpan.day
                        ? AppLocalizations.of(context)!.emptyDayActions
                        : AppLocalizations.of(context)!.emptyRangeActions,
                  );
            final readablePrimaryPane = Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: primaryPane,
              ),
            );
            final secondaryPane = RangeTimelineCard(
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
            );
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 940) {
                      return readablePrimaryPane;
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: readablePrimaryPane),
                        const SizedBox(width: 12),
                        Expanded(flex: 5, child: secondaryPane),
                      ],
                    );
                  },
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
