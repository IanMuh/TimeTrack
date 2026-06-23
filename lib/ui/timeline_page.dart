import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app/app_state.dart';
import '../core/date_time_ext.dart';
import '../data/time_repository.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/time_entry.dart';
import 'adaptive_layout.dart';
import 'activity_colors.dart';
import 'home_page.dart';
import 'ui_components.dart';

enum TimelineViewMode { entries, actions }

enum TimelineDensity { compact, detailed }

enum TimelineSpan {
  day(1),
  threeDays(3),
  week(7);

  const TimelineSpan(this.days);

  final int days;
}

class TimelinePageController {
  _TimelinePageState? _state;

  void _attach(_TimelinePageState state) {
    _state = state;
  }

  void _detach(_TimelinePageState state) {
    if (_state == state) {
      _state = null;
    }
  }

  void openEntryEditor() {
    _state?.openEntryEditor();
  }

  void selectPreviousRange() {
    _state?.selectPreviousRange();
  }

  void selectNextRange() {
    _state?.selectNextRange();
  }
}

class _VisibleEntryInterval {
  const _VisibleEntryInterval({
    required this.start,
    required this.end,
    required this.isRunningNow,
  });

  final DateTime start;
  final DateTime end;
  final bool isRunningNow;

  Duration get duration => end.difference(start);
}

_VisibleEntryInterval _visibleEntryInterval(
  TimeEntry entry,
  DateTime selectedDay,
  DateTime now,
) {
  final dayStart = selectedDay.startOfDay;
  final dayEnd = dayStart.add(const Duration(days: 1));
  final entryEnd = entry.endAt ?? now;
  final visibleStart =
      entry.startAt.isBefore(dayStart) ? dayStart : entry.startAt;
  final visibleEnd = entryEnd.isAfter(dayEnd) ? dayEnd : entryEnd;
  final isRunningNow =
      entry.endAt == null && !now.isBefore(dayStart) && now.isBefore(dayEnd);
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
    isRunningNow: isRunningNow,
  );
}

class TimelinePage extends StatefulWidget {
  const TimelinePage({
    required this.state,
    this.defaultToTodayOnOpen = true,
    this.controller,
    super.key,
  });

  final AppState state;
  final bool defaultToTodayOnOpen;
  final TimelinePageController? controller;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  TimelineViewMode _mode = TimelineViewMode.entries;
  TimelineDensity _density = TimelineDensity.detailed;
  TimelineSpan _span = TimelineSpan.day;
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    if (widget.defaultToTodayOnOpen) {
      _defaultToToday();
    }
  }

  @override
  void didUpdateWidget(TimelinePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  void _defaultToToday() {
    final today = widget.state.now.startOfDay;
    if (!widget.state.selectedDay.isSameDate(today)) {
      widget.state.selectedDay = today;
    }
  }

  Future<void> _pickDate() async {
    final state = widget.state;
    final date = await showDatePicker(
      context: context,
      initialDate: state.selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      await state.selectDay(date);
    }
  }

  void openEntryEditor() {
    showEntryEditor(context, widget.state);
  }

  void selectPreviousRange() {
    widget.state.selectDay(
      widget.state.selectedDay.subtract(Duration(days: _span.days)),
    );
  }

  void selectNextRange() {
    widget.state.selectDay(
      widget.state.selectedDay.add(Duration(days: _span.days)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final rangeStart = state.selectedDay.startOfDay;
        final isFutureDay =
            state.selectedDay.startOfDay.isAfter(state.now.startOfDay);
        final rangeEnd = rangeStart.add(Duration(days: _span.days));
        return AdaptivePage(
          pageKey: const PageStorageKey('timeline-page'),
          children: [
            TimelineHeader(
              selectedDay: state.selectedDay,
              mode: _mode,
              density: _density,
              span: _span,
              zoom: _zoom,
              onPreviousRange: selectPreviousRange,
              onNextRange: selectNextRange,
              onDateTap: _pickDate,
              onModeChanged: (value) => setState(() => _mode = value),
              onDensityChanged: (value) => setState(() => _density = value),
              onSpanChanged: (value) => setState(() => _span = value),
              onZoomChanged: (value) => setState(() => _zoom = value),
              onAddEntry: openEntryEditor,
            ),
            const SectionGap(),
            if (isFutureDay) FutureDayBanner(selectedDay: state.selectedDay),
            FutureBuilder<_TimelineRangeData>(
              future: _loadRangeData(state, rangeStart, rangeEnd),
              builder: (context, snapshot) {
                final data = snapshot.data ?? const _TimelineRangeData.empty();
                return switch (_mode) {
                  TimelineViewMode.entries => _EntriesTimelineView(
                      state: state,
                      entries: data.entries,
                      rangeStart: rangeStart,
                      span: _span,
                      density: _density,
                      zoom: _zoom,
                      emptyText: _span == TimelineSpan.day
                          ? '这一天还没有记录。'
                          : '这个范围还没有记录。',
                    ),
                  TimelineViewMode.actions => _ActionLogList(
                      state: state,
                      logs: data.logs,
                      emptyText: _span == TimelineSpan.day
                          ? '这一天还没有切换或编辑指令。'
                          : '这个范围还没有切换或编辑指令。',
                    ),
                };
              },
            ),
          ],
        );
      },
    );
  }

  Future<_TimelineRangeData> _loadRangeData(
    AppState state,
    DateTime start,
    DateTime end,
  ) async {
    if (_span == TimelineSpan.day) {
      final entries = state.visibleDayEntries();
      final logs = [...state.dayActionLogs]
        ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      return _TimelineRangeData(entries: entries, logs: logs);
    }
    final entries = await state.entriesForRange(start: start, end: end);
    final logs = await state.actionLogsForRange(start: start, end: end);
    logs.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return _TimelineRangeData(entries: entries, logs: logs);
  }
}

class _TimelineRangeData {
  const _TimelineRangeData({required this.entries, required this.logs});

  const _TimelineRangeData.empty()
      : entries = const [],
        logs = const [];

  final List<TimeEntry> entries;
  final List<ActionLog> logs;
}

class TimelineHeader extends StatelessWidget {
  const TimelineHeader({
    required this.selectedDay,
    required this.mode,
    required this.density,
    required this.span,
    required this.zoom,
    required this.onPreviousRange,
    required this.onNextRange,
    required this.onDateTap,
    required this.onModeChanged,
    required this.onDensityChanged,
    required this.onSpanChanged,
    required this.onZoomChanged,
    required this.onAddEntry,
    super.key,
  });

  final DateTime selectedDay;
  final TimelineViewMode mode;
  final TimelineDensity density;
  final TimelineSpan span;
  final double zoom;
  final VoidCallback onPreviousRange;
  final VoidCallback onNextRange;
  final VoidCallback onDateTap;
  final ValueChanged<TimelineViewMode> onModeChanged;
  final ValueChanged<TimelineDensity> onDensityChanged;
  final ValueChanged<TimelineSpan> onSpanChanged;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onAddEntry;

  @override
  Widget build(BuildContext context) {
    final rangeEnd = selectedDay.add(Duration(days: span.days - 1));
    final header = PageHeader(
      title: '时间轴',
      subtitle: span == TimelineSpan.day
          ? DateFormat('yyyy-MM-dd').format(selectedDay)
          : '${DateFormat('MM-dd').format(selectedDay)} - ${DateFormat('MM-dd').format(rangeEnd)}',
    );
    final daySelector = DayRangeSelector(
      selectedDay: selectedDay,
      rangeEnd: rangeEnd,
      onPreviousDay: onPreviousRange,
      onNextDay: onNextRange,
      onDateTap: onDateTap,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final showRecordControls = mode == TimelineViewMode.entries;
        final modeSelector = _TimelineModeControl(
          selectedMode: mode,
          compact: compact,
          onModeChanged: onModeChanged,
        );
        final densitySelector = SegmentedButton<TimelineDensity>(
          segments: const [
            ButtonSegment(
              value: TimelineDensity.compact,
              icon: Icon(Icons.density_small),
              label: Text('紧凑'),
            ),
            ButtonSegment(
              value: TimelineDensity.detailed,
              icon: Icon(Icons.view_agenda_outlined),
              label: Text('详细'),
            ),
          ],
          selected: {density},
          onSelectionChanged: (value) => onDensityChanged(value.first),
        );
        final spanSelector = SegmentedButton<TimelineSpan>(
          segments: const [
            ButtonSegment(
              value: TimelineSpan.day,
              label: Text('单日'),
            ),
            ButtonSegment(
              value: TimelineSpan.threeDays,
              label: Text('3日'),
            ),
            ButtonSegment(
              value: TimelineSpan.week,
              label: Text('7日'),
            ),
          ],
          selected: {span},
          onSelectionChanged: (value) => onSpanChanged(value.first),
        );
        final zoomControl = _TimelineZoomControl(
          zoom: zoom,
          onZoomChanged: onZoomChanged,
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 12),
              daySelector,
              const SizedBox(height: 12),
              modeSelector,
              if (showRecordControls) ...[
                const SizedBox(height: 10),
                densitySelector,
              ],
              const SizedBox(height: 10),
              spanSelector,
              if (showRecordControls) ...[
                const SizedBox(height: 10),
                zoomControl,
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onAddEntry,
                icon: const Icon(Icons.add),
                label: const Text('补记'),
              ),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: header),
                daySelector,
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: modeSelector),
                if (showRecordControls) ...[
                  const SizedBox(width: 12),
                  densitySelector,
                ],
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onAddEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('补记'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                spanSelector,
                if (showRecordControls) ...[
                  const SizedBox(width: 16),
                  Expanded(child: zoomControl),
                ],
              ],
            ),
          ],
        );
      },
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
        decoration: const InputDecoration(
          labelText: '视图',
          prefixIcon: Icon(Icons.layers_outlined),
        ),
        items: [
          for (final mode in TimelineViewMode.values)
            DropdownMenuItem(
              value: mode,
              child: Text(_modeLabel(mode)),
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
      segments: const [
        ButtonSegment(
          value: TimelineViewMode.entries,
          icon: Icon(Icons.timeline),
          label: Text('记录'),
        ),
        ButtonSegment(
          value: TimelineViewMode.actions,
          icon: Icon(Icons.swap_horiz),
          label: Text('指令'),
        ),
      ],
      selected: {selectedMode},
      onSelectionChanged: (value) => onModeChanged(value.first),
    );
  }

  String _modeLabel(TimelineViewMode mode) {
    return switch (mode) {
      TimelineViewMode.entries => '记录',
      TimelineViewMode.actions => '指令',
    };
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

class FutureDayBanner extends StatelessWidget {
  const FutureDayBanner({required this.selectedDay, super.key});

  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: QuietPanel(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            IconBadge(
              icon: Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${DateFormat('yyyy-MM-dd').format(selectedDay)} 尚未到来。'
                '记录会在这一天实际发生后才出现在这里。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimelineCardHeader extends StatelessWidget {
  const TimelineCardHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SectionTitle(
      title: title,
      subtitle: subtitle,
      icon: icon,
    );
  }
}

class TimelineEmptyState extends StatelessWidget {
  const TimelineEmptyState({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.inbox_outlined,
      title: text,
      message: '切换到补记或选择其他日期继续查看。',
    );
  }
}

class TimelineSurface extends StatelessWidget {
  const TimelineSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return QuietPanel(
      padding: padding,
      child: child,
    );
  }
}

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
              '一天覆盖线',
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
        ? '进行中'
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
    super.key,
  });

  final AppState state;
  final List<TimeEntry> entries;
  final DateTime rangeStart;
  final TimelineSpan span;
  final TimelineDensity density;
  final double zoom;
  final bool showEmptyState;

  @override
  State<RangeTimelineCard> createState() => _RangeTimelineCardState();
}

class _RangeTimelineCardState extends State<RangeTimelineCard> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final metrics = _TimelineLayoutMetrics.forWidth(
          compact: compact,
          density: widget.density,
          zoom: widget.zoom,
        );
        final canvasHeight =
            metrics.timeScaleHeight + metrics.laneHeight * widget.span.days;
        return TimelineSurface(
          padding: EdgeInsets.all(metrics.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TimelineCardHeader(
                title: '可缩放时间线',
                subtitle: '横向拖动查看全天刻度，缩放后仍保留同一时间尺度。',
                icon: Icons.timeline,
              ),
              const SizedBox(height: 14),
              if (compact)
                _ScrollableTimelineCanvas(
                  controller: _horizontalController,
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
                      child: _ScrollableTimelineCanvas(
                        controller: _horizontalController,
                        width: metrics.dayWidth,
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
                const TimelineEmptyState(text: '这个范围还没有记录。'),
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
  }) {
    final laneHeight = density == TimelineDensity.compact
        ? (compact ? 78.0 : 72.0)
        : (compact ? 106.0 : 104.0);
    final blockHeight = density == TimelineDensity.compact ? 38.0 : 64.0;
    return _TimelineLayoutMetrics(
      cardPadding: compact ? 10.0 : 16.0,
      dayWidth: 960.0 * zoom,
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

class _ScrollableTimelineCanvas extends StatelessWidget {
  const _ScrollableTimelineCanvas({
    required this.controller,
    required this.width,
    required this.height,
    required this.child,
  });

  final ScrollController controller;
  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: height,
            child: child,
          ),
        ),
      ),
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
        '${_formatTime(entry.startAt)} - ${entry.endAt == null ? '进行中' : _formatTime(entry.endAt!)}';
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
    required this.zoom,
    required this.emptyText,
  });

  final AppState state;
  final List<TimeEntry> entries;
  final DateTime rangeStart;
  final TimelineSpan span;
  final TimelineDensity density;
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

class _TimelineEntryListSection extends StatelessWidget {
  const _TimelineEntryListSection({
    required this.state,
    required this.entries,
    required this.emptyText,
  });

  final AppState state;
  final List<TimeEntry> entries;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TimelineCardHeader(
          title: '记录列表',
          subtitle: '按开始时间排列，点击任一记录可编辑。',
          icon: Icons.view_list_outlined,
        ),
        const SizedBox(height: 12),
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

class _ActionLogList extends StatelessWidget {
  const _ActionLogList({
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
        ? '进行中'
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
            label: '编辑${state.activityNameForEntry(entry)}时间段',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 64,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _TimelineEntryContent(
                      title: state.activityNameForEntry(entry),
                      duration: formatDurationCompact(interval.duration),
                      timeText: timeText,
                      note: entry.note,
                    ),
                  ),
                  IconButton(
                    tooltip: '编辑',
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
    final color = Color(activity?.color ?? 0xff64748b);
    return QuietPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(_logIcon(log.actionType), color: color, size: 18),
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
                            : '${log.message}：${activity.name}',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text('设备 ${log.deviceId}'),
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

  IconData _logIcon(String actionType) {
    return switch (actionType) {
      'switch' => Icons.swap_horiz,
      'stop' => Icons.stop_circle_outlined,
      'manual' => Icons.add_circle_outline,
      'edit' => Icons.edit_outlined,
      'delete' => Icons.delete_outline,
      'merge' => Icons.merge_type_outlined,
      'split' => Icons.call_split_outlined,
      'activity_delete' => Icons.label_off_outlined,
      _ => Icons.bolt_outlined,
    };
  }
}

Future<void> showEntryEditor(
  BuildContext context,
  AppState state, {
  TimeEntry? entry,
}) async {
  var activities = [
    for (final activity in state.activities)
      if (!activity.isUnassigned && !activity.isOneOff) activity,
  ];
  var oneOffActivities = <Activity>[];
  final selectedDay = state.selectedDay;
  final editingGeneratedGap = entry?.deviceId == 'unassigned-gap';
  var loadedActivityChoices = false;
  Activity? selectedActivity;
  String activityQuery = '';
  var activityQueryAllowsCreate = false;

  Activity? findActivityIn(Iterable<Activity> source, String? id) {
    if (id == null) {
      return null;
    }
    for (final item in source) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Activity? findActivity(String? id) {
    return findActivityIn(activities, id) ??
        findActivityIn(oneOffActivities, id) ??
        (selectedActivity?.id == id ? selectedActivity : null);
  }

  String? selectedActivityId;
  if (entry == null) {
    selectedActivity = activities.isEmpty ? null : activities.first;
    selectedActivityId = selectedActivity?.id;
  } else {
    final selected = state.activityById(entry.activityId);
    if (selected != null && !selected.isUnassigned) {
      selectedActivity = selected;
      selectedActivityId = selected.id;
      activityQuery = selected.name;
    } else if (selected == null && entry.activityNameSnapshot.isNotEmpty) {
      activityQuery = entry.activityNameSnapshot;
    }
  }
  var start = entry?.startAt ?? _defaultEntryStart(selectedDay, state.now);
  var end = entry?.endAt ?? _defaultEntryEnd(start, selectedDay, state.now);
  var keepRunning = entry?.isRunning ?? false;
  var note = entry?.note ?? '';
  String? formError;

  Future<void> pickDateTime({
    required bool isStart,
    required StateSetter setState,
  }) async {
    final base = isStart ? start : end;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) {
      return;
    }
    final next =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        start = next;
        if (!keepRunning && !end.isAfter(start)) {
          end = start.add(const Duration(minutes: 30));
        }
      } else {
        end = next;
        keepRunning = false;
      }
      formError = null;
    });
  }

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> refreshActivities([
            String? preferredActivityId,
          ]) async {
            final refreshed = await state.entryActivityChoices();
            final refreshedOneOffs = await state.oneOffActivitySuggestions();
            if (!context.mounted) {
              return;
            }
            final preferred = preferredActivityId ?? selectedActivityId;
            final preferredActivity = findActivityIn(refreshed, preferred) ??
                findActivityIn(refreshedOneOffs, preferred);
            setState(() {
              activities = refreshed;
              oneOffActivities = refreshedOneOffs;
              selectedActivity = preferredActivity;
              selectedActivityId = preferredActivity?.id;
              activityQuery = preferredActivity?.name ?? activityQuery;
              activityQueryAllowsCreate = false;
            });
          }

          if (!loadedActivityChoices) {
            loadedActivityChoices = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                unawaited(refreshActivities());
              }
            });
          }

          return AlertDialog(
            title: Text(entry == null ? '补记时间段' : '编辑时间段'),
            content: SizedBox(
              width: _dialogContentWidth(context, maxWidth: 460),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _EntryActivitySelector(
                      activities: activities,
                      oneOffActivities: oneOffActivities,
                      selectedActivityId: selectedActivityId,
                      initialQuery: activityQuery,
                      onQueryChanged: (value) {
                        setState(() {
                          activityQuery = value;
                          activityQueryAllowsCreate = true;
                          selectedActivity = null;
                          selectedActivityId = null;
                          formError = null;
                        });
                      },
                      onActivitySelected: (activity) {
                        setState(() {
                          selectedActivity = activity;
                          selectedActivityId = activity.id;
                          activityQuery = activity.name;
                          activityQueryAllowsCreate = false;
                          formError = null;
                        });
                      },
                      onEditActivity: selectedActivityId == null ||
                              selectedActivity == null ||
                              selectedActivity!.isOneOff
                          ? null
                          : () async {
                              final selected = findActivity(selectedActivityId);
                              if (selected == null || selected.isOneOff) {
                                setState(
                                  () => formError = '请选择一个有效事项。',
                                );
                                return;
                              }
                              final updated = await showActivityEditorDialog(
                                context,
                                state,
                                activity: selected,
                              );
                              if (context.mounted) {
                                await refreshActivities(updated?.id);
                                setState(() => formError = null);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_arrow),
                      title: const Text('开始'),
                      subtitle: Text(_formatDateTime(start)),
                      onTap: () =>
                          pickDateTime(isStart: true, setState: setState),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.stop),
                      title: const Text('结束'),
                      subtitle: Text(
                        keepRunning ? '保持进行中' : _formatDateTime(end),
                      ),
                      enabled: !keepRunning,
                      onTap: keepRunning
                          ? null
                          : () => pickDateTime(
                                isStart: false,
                                setState: setState,
                              ),
                    ),
                    if (entry?.isRunning ?? false)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.timelapse_outlined),
                        title: const Text('保持进行中'),
                        subtitle: const Text('关闭后可把这条记录保存为已结束。'),
                        value: keepRunning,
                        onChanged: (value) {
                          setState(() {
                            keepRunning = value;
                            if (!keepRunning && !end.isAfter(start)) {
                              end = _defaultEntryEnd(
                                start,
                                selectedDay,
                                state.now,
                              );
                            }
                            formError = null;
                          });
                        },
                      ),
                    TextFormField(
                      initialValue: note,
                      onChanged: (value) => note = value,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '备注',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    if (entry != null &&
                        !editingGeneratedGap &&
                        !entry.isRunning) ...[
                      const SizedBox(height: 12),
                      _EntryEditActions(
                        state: state,
                        entry: entry,
                        onChanged: () {
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                    if (formError != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          formError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (entry != null && !editingGeneratedGap)
                TextButton.icon(
                  onPressed: () async {
                    await state.deleteEntry(entry);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final refreshed = await state.entryActivityChoices();
                  final refreshedOneOffs =
                      await state.oneOffActivitySuggestions();
                  if (!context.mounted) {
                    return;
                  }
                  activities = refreshed;
                  oneOffActivities = refreshedOneOffs;
                  Activity? selectedForSave =
                      findActivityIn(refreshed, selectedActivityId) ??
                          findActivityIn(refreshedOneOffs, selectedActivityId);
                  final trimmedActivityQuery = activityQuery.trim();
                  if (selectedForSave == null &&
                      trimmedActivityQuery.isNotEmpty) {
                    selectedForSave = _exactActivityMatch(
                      refreshed,
                      refreshedOneOffs,
                      trimmedActivityQuery,
                    );
                  }
                  if (selectedForSave == null && !activityQueryAllowsCreate) {
                    setState(() => formError = '请选择一个有效事项。');
                    return;
                  }
                  var shouldCreateActivity = false;
                  if (selectedForSave == null &&
                      trimmedActivityQuery.isNotEmpty) {
                    final matches = _entryActivityMatches(
                      refreshed,
                      refreshedOneOffs,
                      trimmedActivityQuery,
                    );
                    if (matches.isNotEmpty) {
                      setState(() => formError = '请选择一个已有事项，或输入新的名称。');
                      return;
                    }
                    shouldCreateActivity = true;
                  }
                  if (selectedForSave == null && !shouldCreateActivity) {
                    setState(() => formError = '请选择一个有效事项。');
                    return;
                  }
                  if (keepRunning && start.isAfter(state.now)) {
                    setState(() => formError = '进行中的记录不能从未来开始。');
                    return;
                  }
                  if (!keepRunning && !end.isAfter(start)) {
                    setState(() => formError = '结束时间必须晚于开始时间。');
                    return;
                  }
                  final trimmedNote = note.trim();
                  final next = TimeEntry(
                    id: entry?.id ?? 'preview',
                    userId: entry?.userId,
                    activityId: selectedForSave?.id ?? 'preview-activity',
                    startAt: start,
                    endAt: keepRunning ? null : end,
                    note: trimmedNote,
                    deviceId: entry?.deviceId ?? 'manual-entry',
                    updatedAt: DateTime.now(),
                    isDeleted: false,
                  );
                  final overlaps = await state.overlaps(next);
                  if (!context.mounted) {
                    return;
                  }
                  if (overlaps.isNotEmpty && formError == null) {
                    setState(() {
                      formError = '这个时间段和已有记录重叠。再次点击保存将自动切割已有记录。';
                    });
                    return;
                  }
                  var saved = false;
                  await state.runUndoBatch(() async {
                    if (shouldCreateActivity) {
                      final created = await _showCreateEntryActivityDialog(
                        context,
                        state,
                        initialName: trimmedActivityQuery,
                      );
                      if (!context.mounted || created == null) {
                        return;
                      }
                      selectedForSave = created;
                      setState(() {
                        if (created.isOneOff) {
                          oneOffActivities = [created, ...oneOffActivities];
                        } else {
                          activities = [created, ...activities];
                        }
                        selectedActivity = created;
                        selectedActivityId = created.id;
                        activityQuery = created.name;
                        activityQueryAllowsCreate = false;
                        formError = null;
                      });
                    }
                    final activityForSave = selectedForSave;
                    if (activityForSave == null) {
                      return;
                    }
                    if (activityForSave.isOneOff && activityForSave.isDeleted) {
                      final restoredActivity = await state.createEntryActivity(
                        activityForSave.name,
                        activityForSave.color,
                        isOneOff: true,
                        reuseActivity: activityForSave,
                      );
                      if (!context.mounted) {
                        return;
                      }
                      selectedForSave = restoredActivity;
                      setState(() {
                        selectedActivity = restoredActivity;
                        selectedActivityId = restoredActivity.id;
                        activityQuery = restoredActivity.name;
                        oneOffActivities = [
                          restoredActivity,
                          for (final activity in oneOffActivities)
                            if (activity.id != restoredActivity.id) activity,
                        ];
                      });
                    }
                    final finalActivity = selectedForSave;
                    if (finalActivity == null) {
                      return;
                    }
                    if (entry == null || editingGeneratedGap) {
                      await state.createManualEntry(
                        activityId: finalActivity.id,
                        startAt: start,
                        endAt: end,
                        note: trimmedNote,
                      );
                    } else {
                      await state.saveEntry(
                        next.copyWith(activityId: finalActivity.id),
                      );
                    }
                    saved = true;
                  },
                      label: entry == null || editingGeneratedGap
                          ? '补记时间段'
                          : '编辑时间段');
                  if (!saved) {
                    return;
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _EntryEditActions extends StatelessWidget {
  const _EntryEditActions({
    required this.state,
    required this.entry,
    required this.onChanged,
  });

  final AppState state;
  final TimeEntry entry;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final endAt = entry.endAt;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _EntryMergeButton(
          state: state,
          entry: entry,
          direction: EntryMergeDirection.previous,
          onMerged: onChanged,
        ),
        _EntryMergeButton(
          state: state,
          entry: entry,
          direction: EntryMergeDirection.next,
          onMerged: onChanged,
        ),
        if (endAt != null && entry.startAt.isBefore(endAt))
          _EntrySplitButton(
            state: state,
            entry: entry,
            onSplit: onChanged,
          ),
        if (endAt != null && endAt.isBefore(state.now))
          _EntryExtendToNowButton(
            state: state,
            entry: entry,
            onExtended: onChanged,
          ),
      ],
    );
  }
}

class _EntrySplitButton extends StatelessWidget {
  const _EntrySplitButton({
    required this.state,
    required this.entry,
    required this.onSplit,
  });

  final AppState state;
  final TimeEntry entry;
  final VoidCallback onSplit;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _splitEntry(context, state, entry, onSplit),
      icon: const Icon(Icons.call_split_outlined),
      label: const Text('切割'),
    );
  }
}

class _EntryExtendToNowButton extends StatelessWidget {
  const _EntryExtendToNowButton({
    required this.state,
    required this.entry,
    required this.onExtended,
  });

  final AppState state;
  final TimeEntry entry;
  final VoidCallback onExtended;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _extendEntryToNow(context, state, entry, onExtended),
      icon: const Icon(Icons.update),
      label: const Text('延续到现在'),
    );
  }
}

class _EntryMergeButton extends StatelessWidget {
  const _EntryMergeButton({
    required this.state,
    required this.entry,
    required this.direction,
    required this.onMerged,
  });

  final AppState state;
  final TimeEntry entry;
  final EntryMergeDirection direction;
  final VoidCallback onMerged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _mergeEntryWithNeighbor(
        context,
        state,
        entry,
        direction,
        onMerged,
      ),
      icon: Icon(
        direction == EntryMergeDirection.previous
            ? Icons.keyboard_arrow_left
            : Icons.keyboard_arrow_right,
      ),
      label: Text(
        direction == EntryMergeDirection.previous ? '合并左侧' : '合并右侧',
      ),
    );
  }
}

Future<void> _mergeEntryWithNeighbor(
  BuildContext context,
  AppState state,
  TimeEntry entry,
  EntryMergeDirection direction,
  VoidCallback onMerged,
) async {
  final candidate = await state.mergeCandidate(entry.id, direction);
  if (!context.mounted) {
    return;
  }
  if (candidate == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('没有可合并的相邻记录')),
    );
    return;
  }
  final neighborName = state.activityNameForEntry(candidate.neighbor);
  if (candidate.requiresConfirmation) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final directionText =
            candidate.direction == EntryMergeDirection.previous ? '左侧' : '右侧';
        return AlertDialog(
          title: Text('合并$directionText记录'),
          content: Text(
            '$neighborName 的时长为 ${formatDurationCompact(candidate.neighborDuration)}，'
            '超过 ${candidate.threshold.inMinutes} 分钟阈值。确定合并吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.merge_type_outlined),
              label: const Text('合并'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
  }
  await state.mergeEntryWithNeighbor(
    entryId: candidate.current.id,
    direction: candidate.direction,
    confirmed: true,
  );
  if (context.mounted) {
    onMerged();
  }
}

Future<void> _splitEntry(
  BuildContext context,
  AppState state,
  TimeEntry entry,
  VoidCallback onSplit,
) async {
  final splitAt = await _showSplitEntryDialog(context, entry);
  if (splitAt == null || !context.mounted) {
    return;
  }
  await state.splitEntry(entryId: entry.id, splitAt: splitAt);
  if (context.mounted) {
    onSplit();
  }
}

Future<DateTime?> _showSplitEntryDialog(
  BuildContext context,
  TimeEntry entry,
) async {
  final endAt = entry.endAt;
  if (endAt == null || !entry.startAt.isBefore(endAt)) {
    return null;
  }
  final midpoint = entry.startAt.add(
    Duration(milliseconds: endAt.difference(entry.startAt).inMilliseconds ~/ 2),
  );
  var splitAt = midpoint;
  String? error;

  Future<void> pickSplitAt(StateSetter setState) async {
    final date = await showDatePicker(
      context: context,
      initialDate: splitAt,
      firstDate: entry.startAt,
      lastDate: endAt,
    );
    if (date == null || !context.mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(splitAt),
    );
    if (time == null) {
      return;
    }
    final next = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      splitAt = next;
      error = null;
    });
  }

  return showDialog<DateTime>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('切割时间段'),
            content: SizedBox(
              width: _dialogContentWidth(context, maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.call_split_outlined),
                    title: const Text('切割点'),
                    subtitle: Text(_formatDateTime(splitAt)),
                    onTap: () => pickSplitAt(setState),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (!entry.startAt.isBefore(splitAt) ||
                      !splitAt.isBefore(endAt)) {
                    setState(() => error = '切割点必须在开始和结束之间。');
                    return;
                  }
                  Navigator.pop(context, splitAt);
                },
                icon: const Icon(Icons.call_split_outlined),
                label: const Text('切割'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _extendEntryToNow(
  BuildContext context,
  AppState state,
  TimeEntry entry,
  VoidCallback onExtended,
) async {
  if (!entry.startAt.isBefore(state.now)) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('开始时间晚于当前时间，无法延续')),
    );
    return;
  }
  await state.extendEntryToNow(entry);
  if (context.mounted) {
    onExtended();
  }
}

List<Activity> _entryActivityMatches(
  List<Activity> activities,
  List<Activity> oneOffActivities,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return activities;
  }
  final matches = <Activity>[];
  final seenIds = <String>{};
  for (final activity in [...activities, ...oneOffActivities]) {
    if (activity.name.toLowerCase().contains(normalized) &&
        seenIds.add(activity.id)) {
      matches.add(activity);
    }
  }
  return matches;
}

Activity? _exactActivityMatch(
  List<Activity> activities,
  List<Activity> oneOffActivities,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  for (final activity in [...activities, ...oneOffActivities]) {
    if (activity.name.trim().toLowerCase() == normalized) {
      return activity;
    }
  }
  return null;
}

Future<Activity?> _showCreateEntryActivityDialog(
  BuildContext context,
  AppState state, {
  required String initialName,
}) async {
  final controller = TextEditingController(text: initialName);
  var selectedColor =
      nextActivityColor(state.activities.map((activity) => activity.color));
  var isOneOff = false;
  Activity? saved;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('创建事项'),
            content: SizedBox(
              width: _dialogContentWidth(context, maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: '名称',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.bookmark_border),
                          label: Text('持久'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.bolt_outlined),
                          label: Text('单次'),
                        ),
                      ],
                      selected: {isOneOff},
                      onSelectionChanged: (values) {
                        setState(() => isOneOff = values.single);
                      },
                    ),
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    return;
                  }
                  saved = await state.createEntryActivity(
                    name,
                    selectedColor,
                    isOneOff: isOneOff,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('创建'),
              ),
            ],
          );
        },
      );
    },
  );
  return saved;
}

class _EntryActivitySelector extends StatefulWidget {
  const _EntryActivitySelector({
    required this.activities,
    required this.oneOffActivities,
    required this.selectedActivityId,
    required this.initialQuery,
    required this.onQueryChanged,
    required this.onActivitySelected,
    required this.onEditActivity,
  });

  final List<Activity> activities;
  final List<Activity> oneOffActivities;
  final String? selectedActivityId;
  final String initialQuery;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Activity> onActivitySelected;
  final VoidCallback? onEditActivity;

  @override
  State<_EntryActivitySelector> createState() => _EntryActivitySelectorState();
}

class _EntryActivitySelectorState extends State<_EntryActivitySelector> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(_EntryActivitySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery &&
        _controller.text != widget.initialQuery) {
      _controller.text = widget.initialQuery;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = _dialogContentWidth(context, maxWidth: 460) < 340;
    final query = _controller.text.trim();
    final visibleActivities = _entryActivityMatches(
      widget.activities,
      widget.oneOffActivities,
      query,
    );
    final field = TextField(
      key: const ValueKey('entry-activity-search-field'),
      controller: _controller,
      decoration: const InputDecoration(
        labelText: '事项',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: widget.onQueryChanged,
    );
    final actions = IconButton(
      tooltip: '编辑当前事项',
      onPressed: widget.onEditActivity,
      icon: const Icon(Icons.edit_outlined),
    );
    final inputRow = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field,
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: actions,
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field),
              const SizedBox(width: 8),
              actions,
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        inputRow,
        const SizedBox(height: 10),
        if (visibleActivities.isEmpty)
          Text(
            '没有匹配事项',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final activity in visibleActivities)
                  _EntryActivityChoiceChip(
                    activity: activity,
                    selected: widget.selectedActivityId == activity.id,
                    onSelected: () {
                      _controller.text = activity.name;
                      _controller.selection = TextSelection.collapsed(
                        offset: activity.name.length,
                      );
                      widget.onQueryChanged(activity.name);
                      widget.onActivitySelected(activity);
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EntryActivityChoiceChip extends StatelessWidget {
  const _EntryActivityChoiceChip({
    required this.activity,
    required this.selected,
    required this.onSelected,
  });

  final Activity activity;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(
        activity.isOneOff ? Icons.bolt_outlined : Icons.label_outline,
        size: 18,
        color: Color(activity.color),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              activity.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (activity.isOneOff) ...[
            const SizedBox(width: 6),
            const _OneOffTag(),
          ],
        ],
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _OneOffTag extends StatelessWidget {
  const _OneOffTag();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '单次',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
      ),
    );
  }
}

double _dialogContentWidth(
  BuildContext context, {
  required double maxWidth,
}) {
  final availableWidth = MediaQuery.sizeOf(context).width - 128;
  return availableWidth.clamp(0, maxWidth).toDouble();
}

DateTime _defaultEntryStart(DateTime selectedDay, DateTime now) {
  if (selectedDay.isSameDate(now)) {
    final candidate = now.subtract(const Duration(hours: 1));
    if (candidate.isAfter(selectedDay.startOfDay)) {
      return DateTime(
        candidate.year,
        candidate.month,
        candidate.day,
        candidate.hour,
        candidate.minute,
      );
    }
  }
  return DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 9);
}

DateTime _defaultEntryEnd(DateTime start, DateTime selectedDay, DateTime now) {
  final dayEnd = selectedDay.startOfDay.add(const Duration(days: 1));
  final preferredEnd =
      selectedDay.isSameDate(now) ? now : start.add(const Duration(hours: 1));
  final cappedEnd = preferredEnd.isAfter(dayEnd) ? dayEnd : preferredEnd;
  if (cappedEnd.isAfter(start)) {
    return cappedEnd;
  }
  return start.add(const Duration(minutes: 30));
}

String _formatTime(DateTime value) => DateFormat('HH:mm:ss').format(value);

String _formatDateTime(DateTime value) =>
    DateFormat('yyyy-MM-dd HH:mm:ss').format(value);

String _formatVisibleEndTime(
  _VisibleEntryInterval interval,
  DateTime selectedDay,
) {
  final dayEnd = selectedDay.startOfDay.add(const Duration(days: 1));
  if (interval.end == dayEnd) {
    return '24:00:00';
  }
  return _formatTime(interval.end);
}
