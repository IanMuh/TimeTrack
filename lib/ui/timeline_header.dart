part of 'timeline_page.dart';

class TimelineHeader extends StatelessWidget {
  const TimelineHeader({
    required this.selectedDay,
    required this.mode,
    required this.density,
    required this.span,
    required this.segmentsPerDay,
    required this.zoom,
    required this.onPreviousRange,
    required this.onNextRange,
    required this.onDateTap,
    required this.onModeChanged,
    required this.onDensityChanged,
    required this.onSpanChanged,
    required this.onSegmentsPerDayChanged,
    required this.onZoomChanged,
    required this.onAddEntry,
    this.displayMode = TimelineDisplayMode.singleLine,
    this.onDisplayModeChanged,
    super.key,
  });

  final DateTime selectedDay;
  final TimelineViewMode mode;
  final TimelineDensity density;
  final TimelineDisplayMode displayMode;
  final TimelineSpan span;
  final int segmentsPerDay;
  final double zoom;
  final VoidCallback onPreviousRange;
  final VoidCallback onNextRange;
  final VoidCallback onDateTap;
  final ValueChanged<TimelineViewMode> onModeChanged;
  final ValueChanged<TimelineDensity> onDensityChanged;
  final ValueChanged<TimelineDisplayMode>? onDisplayModeChanged;
  final ValueChanged<TimelineSpan> onSpanChanged;
  final ValueChanged<int> onSegmentsPerDayChanged;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onAddEntry;

  @override
  Widget build(BuildContext context) {
    final rangeEnd = selectedDay.add(Duration(days: span.days - 1));
    final header = PageHeader(
      title: AppLocalizations.of(context)!.timeline,
      subtitle: span == TimelineSpan.day
          ? DateFormat('yyyy-MM-dd').format(selectedDay)
          : '${DateFormat('MM-dd').format(selectedDay)} - ${DateFormat('MM-dd').format(rangeEnd)}',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final daySelector = DayRangeSelector(
          selectedDay: selectedDay,
          rangeEnd: rangeEnd,
          onPreviousDay: onPreviousRange,
          onNextDay: onNextRange,
          onDateTap: onDateTap,
          dense: compact,
        );
        final showRecordControls = mode == TimelineViewMode.entries;
        final modeSelector = _TimelineModeControl(
          selectedMode: mode,
          compact: compact,
          onModeChanged: onModeChanged,
        );
        final densitySelector = SegmentedButton<TimelineDensity>(
          segments: [
            ButtonSegment(
              value: TimelineDensity.compact,
              icon: const Icon(Icons.density_small),
              label: Text(AppLocalizations.of(context)!.compact),
            ),
            ButtonSegment(
              value: TimelineDensity.detailed,
              icon: const Icon(Icons.view_agenda_outlined),
              label: Text(AppLocalizations.of(context)!.detailed),
            ),
          ],
          selected: {density},
          onSelectionChanged: (value) => onDensityChanged(value.first),
        );
        final spanSelector = SegmentedButton<TimelineSpan>(
          segments: [
            ButtonSegment(
              value: TimelineSpan.day,
              label: Text(AppLocalizations.of(context)!.singleDay),
            ),
            ButtonSegment(
              value: TimelineSpan.threeDays,
              label: Text(AppLocalizations.of(context)!.threeDays),
            ),
            ButtonSegment(
              value: TimelineSpan.week,
              label: Text(AppLocalizations.of(context)!.sevenDays),
            ),
          ],
          selected: {span},
          onSelectionChanged: (value) => onSpanChanged(value.first),
        );
        final displaySelector = SegmentedButton<TimelineDisplayMode>(
          segments: [
            ButtonSegment(
              value: TimelineDisplayMode.singleLine,
              icon: const Icon(Icons.zoom_out_map),
              label: Text(AppLocalizations.of(context)!.singleLineZoom),
            ),
            ButtonSegment(
              value: TimelineDisplayMode.segmentedDay,
              icon: const Icon(Icons.view_day_outlined),
              label: Text(AppLocalizations.of(context)!.segmentedDayDisplay),
            ),
          ],
          selected: {displayMode},
          onSelectionChanged: (value) =>
              onDisplayModeChanged?.call(value.first),
        );
        final segmentControl = _TimelineSegmentControl(
          segmentsPerDay: segmentsPerDay,
          onChanged: onSegmentsPerDayChanged,
        );
        final zoomControl = _TimelineZoomControl(
          zoom: zoom,
          onZoomChanged: onZoomChanged,
        );
        final addEntryButton = FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: Size(44, compact ? 40 : 44),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 8 : 11,
            ),
          ),
          onPressed: onAddEntry,
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context)!.addEntry),
        );
        final primaryControls = _TimelinePrimaryControls(
          compact: compact,
          daySelector: daySelector,
          modeSelector: modeSelector,
          addEntryButton: addEntryButton,
        );
        final displayOptions = _TimelineDisplayOptions(
          key: ValueKey(
            'timeline-display-options-${compact ? 'compact' : 'wide'}-$mode',
          ),
          showRecordControls: showRecordControls,
          densitySelector: densitySelector,
          spanSelector: spanSelector,
          displaySelector: displaySelector,
          detailControl: displayMode == TimelineDisplayMode.segmentedDay
              ? segmentControl
              : zoomControl,
          compact: compact,
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 8),
              primaryControls,
              const SizedBox(height: 6),
              displayOptions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 12),
            primaryControls,
            const SizedBox(height: 10),
            displayOptions,
          ],
        );
      },
    );
  }
}

class _TimelinePrimaryControls extends StatelessWidget {
  const _TimelinePrimaryControls({
    required this.compact,
    required this.daySelector,
    required this.modeSelector,
    required this.addEntryButton,
  });

  final bool compact;
  final Widget daySelector;
  final Widget modeSelector;
  final Widget addEntryButton;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: daySelector),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: modeSelector),
              const SizedBox(width: 10),
              addEntryButton,
            ],
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        daySelector,
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: modeSelector,
        ),
        addEntryButton,
      ],
    );
  }
}

class _TimelineDisplayOptions extends StatefulWidget {
  const _TimelineDisplayOptions({
    required this.showRecordControls,
    required this.densitySelector,
    required this.spanSelector,
    required this.displaySelector,
    required this.detailControl,
    required this.compact,
    super.key,
  });

  final bool showRecordControls;
  final Widget densitySelector;
  final Widget spanSelector;
  final Widget displaySelector;
  final Widget detailControl;
  final bool compact;

  @override
  State<_TimelineDisplayOptions> createState() =>
      _TimelineDisplayOptionsState();
}

class _TimelineDisplayOptionsState extends State<_TimelineDisplayOptions> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return QuietPanel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: PageStorageKey<String>(
          'timeline-display-options-tile-'
          '${widget.compact ? 'compact' : 'wide'}-'
          '${widget.showRecordControls ? 'records' : 'actions'}',
        ),
        dense: widget.compact,
        visualDensity:
            widget.compact ? VisualDensity.compact : VisualDensity.standard,
        tilePadding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 12 : 16,
        ),
        leading: const Icon(Icons.tune),
        title: Text(AppLocalizations.of(context)!.displayOptions),
        onExpansionChanged: (value) => setState(() => _expanded = value),
        childrenPadding: EdgeInsets.fromLTRB(
          widget.compact ? 12 : 16,
          0,
          widget.compact ? 12 : 16,
          widget.compact ? 12 : 16,
        ),
        children: _expanded
            ? [
                widget.spanSelector,
                if (widget.showRecordControls) ...[
                  const SizedBox(height: 10),
                  widget.densitySelector,
                  const SizedBox(height: 10),
                  widget.displaySelector,
                  const SizedBox(height: 10),
                  widget.detailControl,
                ],
              ]
            : const [],
      ),
    );
  }
}

class _TimelineModeControl extends StatelessWidget {
  const _TimelineModeControl({
    required this.selectedMode,
    required this.compact,
    required this.onModeChanged,
  });

  final TimelineViewMode selectedMode;
  final bool compact;
  final ValueChanged<TimelineViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return DropdownButtonFormField<TimelineViewMode>(
        initialValue: selectedMode,
        isDense: true,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.viewMode,
          prefixIcon: const Icon(Icons.layers_outlined),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          for (final mode in TimelineViewMode.values)
            DropdownMenuItem(
              value: mode,
              child: Text(_modeLabel(context, mode)),
            ),
        ],
        onChanged: (value) {
          if (value != null) {
            onModeChanged(value);
          }
        },
      );
    }

    return SegmentedButton<TimelineViewMode>(
      segments: [
        ButtonSegment(
          value: TimelineViewMode.entries,
          icon: const Icon(Icons.timeline),
          label: Text(AppLocalizations.of(context)!.entries),
        ),
        ButtonSegment(
          value: TimelineViewMode.actions,
          icon: const Icon(Icons.swap_horiz),
          label: Text(AppLocalizations.of(context)!.actions),
        ),
      ],
      selected: {selectedMode},
      onSelectionChanged: (value) => onModeChanged(value.first),
    );
  }

  String _modeLabel(BuildContext context, TimelineViewMode mode) {
    return switch (mode) {
      TimelineViewMode.entries => AppLocalizations.of(context)!.entries,
      TimelineViewMode.actions => AppLocalizations.of(context)!.actions,
    };
  }
}

class _TimelineSegmentControl extends StatelessWidget {
  const _TimelineSegmentControl({
    required this.segmentsPerDay,
    required this.onChanged,
  });

  final int segmentsPerDay;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: l10n.timelineDecreaseSegments,
          onPressed:
              segmentsPerDay <= 1 ? null : () => onChanged(segmentsPerDay - 1),
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(l10n.timelineSegmentsPerDay(segmentsPerDay)),
        ),
        IconButton.filledTonal(
          tooltip: l10n.timelineIncreaseSegments,
          onPressed:
              segmentsPerDay >= 12 ? null : () => onChanged(segmentsPerDay + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _TimelineZoomControl extends StatelessWidget {
  const _TimelineZoomControl({
    required this.zoom,
    required this.onZoomChanged,
  });

  final double zoom;
  final ValueChanged<double> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.zoom_in,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            min: 0.25,
            max: 3,
            divisions: 11,
            value: zoom,
            label: '${zoom.toStringAsFixed(2)}x',
            onChanged: onZoomChanged,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '${zoom.toStringAsFixed(2)}x',
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
