part of 'timeline_page.dart';

class TimelineBlockColor {
  const TimelineBlockColor._();

  static Color textOn(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}

class DayCoverageCard extends StatelessWidget {
  const DayCoverageCard({
    required this.state,
    required this.entries,
    super.key,
  });

  final AppState state;
  final List<TimeEntry> entries;

  @override
  Widget build(BuildContext context) {
    final dayStart = state.selectedDay.startOfDay;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.dayCoverageLine,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 22,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      for (final entry in entries)
                        _CoverageSegment(
                          state: state,
                          entry: entry,
                          dayStart: dayStart,
                          width: constraints.maxWidth,
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('00:00'),
                Text('12:00'),
                Text('23:59'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverageSegment extends StatelessWidget {
  const _CoverageSegment({
    required this.state,
    required this.entry,
    required this.dayStart,
    required this.width,
  });

  final AppState state;
  final TimeEntry entry;
  final DateTime dayStart;
  final double width;

  @override
  Widget build(BuildContext context) {
    final interval = _visibleEntryInterval(entry, state.selectedDay, state.now);
    final startRatio =
        interval.start.difference(dayStart).inSeconds.clamp(0, 86400) / 86400;
    final endRatio =
        interval.end.difference(dayStart).inSeconds.clamp(0, 86400) / 86400;
    final left = width * startRatio;
    final segmentWidth = (width * (endRatio - startRatio)).clamp(2.0, width);
    final activityName = state.activityNameForEntry(entry);
    final activityColor = state.activityColorForEntry(entry);
    final endText = interval.isRunningNow
        ? AppLocalizations.of(context)!.inProgress
        : _formatVisibleEndTime(interval, state.selectedDay);

    return Positioned(
      left: left,
      top: 16,
      width: segmentWidth,
      child: Tooltip(
        message: '$activityName ${_formatTime(interval.start)} - $endText',
        child: Container(
          height: 20,
          decoration: BoxDecoration(
            color: Color(activityColor),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class RangeTimelineCard extends StatefulWidget {
  const RangeTimelineCard({
    required this.state,
    required this.entries,
    required this.rangeStart,
    required this.span,
    required this.density,
    required this.zoom,
    this.showEmptyState = true,
    this.displayMode = TimelineDisplayMode.fitSingleLine,
    super.key,
  });

  final AppState state;
  final List<TimeEntry> entries;
  final DateTime rangeStart;
  final TimelineSpan span;
  final TimelineDensity density;
  final TimelineDisplayMode displayMode;
  final double zoom;
  final bool showEmptyState;

  @override
  State<RangeTimelineCard> createState() => _RangeTimelineCardState();
}

class _RangeTimelineCardState extends State<RangeTimelineCard> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final metrics = _TimelineLayoutMetrics.forWidth(
          compact: compact,
          density: widget.density,
          zoom: widget.zoom,
          fitWidth:
              constraints.maxWidth - metricsHorizontalInsets(compact: compact),
          displayMode: widget.displayMode,
        );
        final canvasHeight =
            metrics.timeScaleHeight + metrics.laneHeight * widget.span.days;
        return TimelineSurface(
          padding: EdgeInsets.all(metrics.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TimelineCardHeader(
                title: AppLocalizations.of(context)!.zoomableTimeline,
                subtitle: AppLocalizations.of(context)!.timelineDragHint,
                icon: Icons.timeline,
              ),
              const SizedBox(height: 14),
              if (widget.displayMode == TimelineDisplayMode.splitByDay)
                _SplitTimelineCanvas(
                  state: widget.state,
                  entries: widget.entries,
                  rangeStart: widget.rangeStart,
                  span: widget.span,
                  density: widget.density,
                  metrics: metrics,
                  showInlineDayLabels: true,
                )
              else if (compact)
                SizedBox(
                  width: metrics.dayWidth,
                  height: canvasHeight,
                  child: _TimelineCanvas(
                    state: widget.state,
                    entries: widget.entries,
                    rangeStart: widget.rangeStart,
                    span: widget.span,
                    density: widget.density,
                    metrics: metrics,
                    showInlineDayLabels: true,
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TimelineDateColumn(
                      rangeStart: widget.rangeStart,
                      days: widget.span.days,
                      laneHeight: metrics.laneHeight,
                      timeScaleHeight: metrics.timeScaleHeight,
                      height: canvasHeight,
                    ),
                    SizedBox(width: metrics.dateColumnGap),
                    Expanded(
                      child: SizedBox(
                        height: canvasHeight,
                        child: _TimelineCanvas(
                          state: widget.state,
                          entries: widget.entries,
                          rangeStart: widget.rangeStart,
                          span: widget.span,
                          density: widget.density,
                          metrics: metrics,
                          showInlineDayLabels: false,
                        ),
                      ),
                    ),
                  ],
                ),
              if (widget.showEmptyState && widget.entries.isEmpty) ...[
                const SizedBox(height: 12),
                TimelineEmptyState(
                    text: AppLocalizations.of(context)!.emptyRangeEntries),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TimelineLayoutMetrics {
  const _TimelineLayoutMetrics({
    required this.cardPadding,
    required this.dayWidth,
    required this.laneHeight,
    required this.timeScaleHeight,
    required this.blockHeight,
    required this.blockTopInset,
    required this.dateColumnGap,
  });

  factory _TimelineLayoutMetrics.forWidth({
    required bool compact,
    required TimelineDensity density,
    required double zoom,
    required double fitWidth,
    required TimelineDisplayMode displayMode,
  }) {
    final laneHeight = density == TimelineDensity.compact
        ? (compact ? 78.0 : 72.0)
        : (compact ? 106.0 : 104.0);
    final blockHeight = density == TimelineDensity.compact ? 38.0 : 64.0;
    final usableFitWidth = math.max(240.0, fitWidth);
    return _TimelineLayoutMetrics(
      cardPadding: compact ? 10.0 : 16.0,
      dayWidth: displayMode == TimelineDisplayMode.fitSingleLine ||
              displayMode == TimelineDisplayMode.splitByDay
          ? usableFitWidth
          : 960.0 * zoom,
      laneHeight: laneHeight,
      timeScaleHeight: density == TimelineDensity.compact ? 24.0 : 32.0,
      blockHeight: blockHeight,
      blockTopInset: compact ? 28.0 : 8.0,
      dateColumnGap: compact ? 0 : 12.0,
    );
  }

  final double cardPadding;
  final double dayWidth;
  final double laneHeight;
  final double timeScaleHeight;
  final double blockHeight;
  final double blockTopInset;
  final double dateColumnGap;
}

double metricsHorizontalInsets({required bool compact}) {
  final padding = compact ? 10.0 : 16.0;
  final dateColumn = compact ? 0.0 : 92.0 + 12.0;
  return padding * 2 + dateColumn;
}

class _TimelineDateColumn extends StatelessWidget {
  const _TimelineDateColumn({
    required this.rangeStart,
    required this.days,
    required this.laneHeight,
    required this.timeScaleHeight,
    required this.height,
  });

  final DateTime rangeStart;
  final int days;
  final double laneHeight;
  final double timeScaleHeight;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: height,
      child: Column(
        children: [
          SizedBox(height: timeScaleHeight),
          for (var index = 0; index < days; index += 1)
            SizedBox(
              height: laneHeight,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    DateFormat('MM-dd E').format(
                      rangeStart.add(Duration(days: index)),
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SplitTimelineCanvas extends StatelessWidget {
  const _SplitTimelineCanvas({
    required this.state,
    required this.entries,
    required this.rangeStart,
    required this.span,
    required this.density,
    required this.metrics,
    required this.showInlineDayLabels,
  });

  final AppState state;
  final List<TimeEntry> entries;
  final DateTime rangeStart;
  final TimelineSpan span;
  final TimelineDensity density;
  final _TimelineLayoutMetrics metrics;
  final bool showInlineDayLabels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < span.days; index += 1) ...[
          SizedBox(
            height: metrics.timeScaleHeight + metrics.laneHeight,
            child: _TimelineCanvas(
              state: state,
              entries: entries,
              rangeStart: rangeStart.add(Duration(days: index)),
              span: TimelineSpan.day,
              density: density,
              metrics: metrics,
              showInlineDayLabels: showInlineDayLabels,
            ),
          ),
          if (index != span.days - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TimelineCanvas extends StatelessWidget {
  const _TimelineCanvas({
    required this.state,
    required this.entries,
    required this.rangeStart,
    required this.span,
    required this.density,
    required this.metrics,
    required this.showInlineDayLabels,
  });

  final AppState state;
  final List<TimeEntry> entries;
  final DateTime rangeStart;
  final TimelineSpan span;
  final TimelineDensity density;
  final _TimelineLayoutMetrics metrics;
  final bool showInlineDayLabels;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _TimelineTimeScale(
          width: metrics.dayWidth,
          height: metrics.timeScaleHeight,
        ),
        for (var index = 0; index < span.days; index += 1)
          _TimelineDayLane(
            top: metrics.timeScaleHeight + index * metrics.laneHeight,
            width: metrics.dayWidth,
            height: metrics.laneHeight,
            label: showInlineDayLabels
                ? DateFormat('MM-dd E').format(
                    rangeStart.add(Duration(days: index)),
                  )
                : null,
          ),
        for (final entry in entries) ..._entryBlocksFor(entry),
      ],
    );
  }

  List<Widget> _entryBlocksFor(
    TimeEntry entry,
  ) {
    final widgets = <Widget>[];
    for (var index = 0; index < span.days; index += 1) {
      final day = rangeStart.add(Duration(days: index));
      final dayStart = day.startOfDay;
      final dayEnd = day.endOfDay;
      final rawEnd = entry.endAt ?? state.now;
      if (!entry.startAt.isBefore(dayEnd) || !rawEnd.isAfter(dayStart)) {
        continue;
      }
      final blockStart =
          entry.startAt.isBefore(dayStart) ? dayStart : entry.startAt;
      final blockEnd = rawEnd.isAfter(dayEnd) ? dayEnd : rawEnd;
      if (!blockEnd.isAfter(blockStart)) {
        continue;
      }
      final startRatio =
          blockStart.difference(dayStart).inSeconds.clamp(0, 86400) / 86400;
      final endRatio =
          blockEnd.difference(dayStart).inSeconds.clamp(0, 86400) / 86400;
      final top = metrics.timeScaleHeight +
          metrics.blockTopInset +
          index * metrics.laneHeight;
      widgets.add(
        Positioned(
          left: metrics.dayWidth * startRatio,
          top: top,
          width: math.max(16, metrics.dayWidth * (endRatio - startRatio)),
          height: metrics.blockHeight,
          child: _TimelineBlock(
            state: state,
            entry: entry,
            density: density,
          ),
        ),
      );
    }
    return widgets;
  }
}

class _TimelineTimeScale extends StatelessWidget {
  const _TimelineTimeScale({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final hour in const [0, 6, 12, 18, 24])
          Positioned(
            left: math.min(width - 40, math.max(0, width * hour / 24 - 20)),
            top: 0,
            width: 40,
            height: height,
            child: Text(
              hour == 24 ? '24:00' : '${hour.toString().padLeft(2, '0')}:00',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

class _TimelineDayLane extends StatelessWidget {
  const _TimelineDayLane({
    required this.top,
    required this.width,
    required this.height,
    this.label,
  });

  final double top;
  final double width;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: top,
          width: width,
          height: height - 8,
          child: DecoratedBox(
            key: ValueKey<String>('timeline-lane-${label ?? top}'),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        for (final hour in const [0, 6, 12, 18, 24])
          Positioned(
            left: width * hour / 24,
            top: top,
            height: height - 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.80),
                  ),
                ),
              ),
            ),
          ),
        if (label != null)
          Positioned(
            left: 10,
            top: top + 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  label!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TimelineBlock extends StatelessWidget {
  const _TimelineBlock({
    required this.state,
    required this.entry,
    required this.density,
  });

  final AppState state;
  final TimeEntry entry;
  final TimelineDensity density;

  @override
  Widget build(BuildContext context) {
    final activityName = state.activityNameForEntry(entry);
    final color = Color(state.activityColorForEntry(entry));
    final textColor = TimelineBlockColor.textOn(color);
    final timeText =
        '${_formatTime(entry.startAt)} - ${entry.endAt == null ? AppLocalizations.of(context)!.inProgress : _formatTime(entry.endAt!)}';
    return Tooltip(
      message: '$activityName $timeText',
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => showEntryEditor(context, state, entry: entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: density == TimelineDensity.compact
                ? Text(
                    activityName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        activityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _EntriesTimelineView extends StatelessWidget {
  const _EntriesTimelineView({
    required this.state,
    required this.entries,
    required this.rangeStart,
    required this.span,
    required this.density,
    required this.displayMode,
    required this.zoom,
    required this.emptyText,
  });

  final AppState state;
  final List<TimeEntry> entries;
  final DateTime rangeStart;
  final TimelineSpan span;
  final TimelineDensity density;
  final TimelineDisplayMode displayMode;
  final double zoom;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final timeline = RangeTimelineCard(
      state: state,
      entries: entries,
      rangeStart: rangeStart,
      span: span,
      density: density,
      displayMode: displayMode,
      zoom: zoom,
      showEmptyState: false,
    );
    final list = _TimelineEntryListSection(
      state: state,
      entries: entries,
      emptyText: emptyText,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        timeline,
        const SectionGap(),
        list,
      ],
    );
  }
}
