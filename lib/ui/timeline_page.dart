import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app/app_state.dart';
import '../core/app_constants.dart';
import '../core/date_time_ext.dart';
import '../data/repository_interfaces.dart';
import '../data/time_repository.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/time_entry.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'activity_colors.dart';
import 'home_page.dart';
import 'sort_controls.dart';
import 'ui_components.dart';

part 'timeline_canvas.dart';
part 'timeline_entry_lists.dart';
part 'timeline_entry_editor.dart';

enum TimelineViewMode { entries, actions }

enum TimelineDensity { compact, detailed }

enum TimelineDisplayMode { singleLine, segmentedDay }

enum TimelineEntrySortMetric { startTime, duration, activityName, color }

enum ActionLogSortMetric { occurredAt, actionType, activityName, device }

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
  TimelineDisplayMode _displayMode = TimelineDisplayMode.singleLine;
  TimelineSpan _span = TimelineSpan.day;
  TimelineEntrySortMetric _entrySortMetric = TimelineEntrySortMetric.startTime;
  ActionLogSortMetric _actionSortMetric = ActionLogSortMetric.occurredAt;
  SortOrder _entrySortOrder = SortOrder.ascending;
  SortOrder _actionSortOrder = SortOrder.ascending;
  int _segmentsPerDay = 4;
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
              displayMode: _displayMode,
              span: _span,
              segmentsPerDay: _segmentsPerDay,
              zoom: _zoom,
              onPreviousRange: selectPreviousRange,
              onNextRange: selectNextRange,
              onDateTap: _pickDate,
              onModeChanged: (value) => setState(() => _mode = value),
              onDensityChanged: (value) => setState(() => _density = value),
              onDisplayModeChanged: (value) =>
                  setState(() => _displayMode = value),
              onSpanChanged: (value) => setState(() => _span = value),
              onSegmentsPerDayChanged: (value) {
                setState(() => _segmentsPerDay = value);
              },
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
                      entries: _sortedEntries(state, data.entries),
                      rangeStart: rangeStart,
                      span: _span,
                      density: _density,
                      displayMode: _displayMode,
                      segmentsPerDay: _segmentsPerDay,
                      zoom: _zoom,
                      sortMetric: _entrySortMetric,
                      sortOrder: _entrySortOrder,
                      onSortMetricChanged: (value) {
                        setState(() => _entrySortMetric = value);
                      },
                      onSortOrderChanged: (value) {
                        setState(() => _entrySortOrder = value);
                      },
                      emptyText: _span == TimelineSpan.day
                          ? AppLocalizations.of(context)!.emptyDayEntries
                          : AppLocalizations.of(context)!.emptyRangeEntries,
                    ),
                  TimelineViewMode.actions => _ActionLogList(
                      state: state,
                      logs: _sortedActionLogs(state, data.logs),
                      sortMetric: _actionSortMetric,
                      sortOrder: _actionSortOrder,
                      onSortMetricChanged: (value) {
                        setState(() => _actionSortMetric = value);
                      },
                      onSortOrderChanged: (value) {
                        setState(() => _actionSortOrder = value);
                      },
                      emptyText: _span == TimelineSpan.day
                          ? AppLocalizations.of(context)!.emptyDayActions
                          : AppLocalizations.of(context)!.emptyRangeActions,
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

  List<TimeEntry> _sortedEntries(AppState state, List<TimeEntry> entries) {
    final sorted = [...entries];
    sorted.sort((a, b) {
      final compare = switch (_entrySortMetric) {
        TimelineEntrySortMetric.startTime => a.startAt.compareTo(b.startAt),
        TimelineEntrySortMetric.duration =>
          _entryDuration(a, state.now).compareTo(_entryDuration(b, state.now)),
        TimelineEntrySortMetric.activityName => state
            .activityNameForEntry(a)
            .compareTo(state.activityNameForEntry(b)),
        TimelineEntrySortMetric.color => state
            .activityColorForEntry(a)
            .compareTo(state.activityColorForEntry(b)),
      };
      final directed =
          _entrySortOrder == SortOrder.ascending ? compare : -compare;
      if (directed != 0) return directed;
      return a.startAt.compareTo(b.startAt);
    });
    return sorted;
  }

  List<ActionLog> _sortedActionLogs(AppState state, List<ActionLog> logs) {
    final sorted = [...logs];
    sorted.sort((a, b) {
      final compare = switch (_actionSortMetric) {
        ActionLogSortMetric.occurredAt => a.occurredAt.compareTo(b.occurredAt),
        ActionLogSortMetric.actionType =>
          a.actionType.storageValue.compareTo(b.actionType.storageValue),
        ActionLogSortMetric.activityName =>
          _logActivityName(state, a).compareTo(_logActivityName(state, b)),
        ActionLogSortMetric.device => a.deviceId.compareTo(b.deviceId),
      };
      final directed =
          _actionSortOrder == SortOrder.ascending ? compare : -compare;
      if (directed != 0) return directed;
      return a.occurredAt.compareTo(b.occurredAt);
    });
    return sorted;
  }

  Duration _entryDuration(TimeEntry entry, DateTime now) {
    return (entry.endAt ?? now).difference(entry.startAt);
  }

  String _logActivityName(AppState state, ActionLog log) {
    final activityId = log.activityId;
    return activityId == null ? '' : state.activityById(activityId)?.name ?? '';
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
        if (compact) {
          final displayOptions = _TimelineDisplayOptions(
            showRecordControls: showRecordControls,
            densitySelector: densitySelector,
            spanSelector: spanSelector,
            displaySelector: displaySelector,
            detailControl: displayMode == TimelineDisplayMode.segmentedDay
                ? segmentControl
                : zoomControl,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 12),
              daySelector,
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: modeSelector),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: onAddEntry,
                    icon: const Icon(Icons.add),
                    label: Text(AppLocalizations.of(context)!.addEntry),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              displayOptions,
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
                  label: Text(AppLocalizations.of(context)!.addEntry),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                spanSelector,
                if (showRecordControls) ...[
                  const SizedBox(width: 16),
                  displaySelector,
                  const SizedBox(width: 16),
                  Expanded(
                    child: displayMode == TimelineDisplayMode.segmentedDay
                        ? segmentControl
                        : zoomControl,
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TimelineDisplayOptions extends StatelessWidget {
  const _TimelineDisplayOptions({
    required this.showRecordControls,
    required this.densitySelector,
    required this.spanSelector,
    required this.displaySelector,
    required this.detailControl,
  });

  final bool showRecordControls;
  final Widget densitySelector;
  final Widget spanSelector;
  final Widget displaySelector;
  final Widget detailControl;

  @override
  Widget build(BuildContext context) {
    return QuietPanel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.tune),
        title: Text(AppLocalizations.of(context)!.displayOptions),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          spanSelector,
          if (showRecordControls) ...[
            const SizedBox(height: 10),
            densitySelector,
            const SizedBox(height: 10),
            displaySelector,
            const SizedBox(height: 10),
            detailControl,
          ],
        ],
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
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.viewMode,
          prefixIcon: const Icon(Icons.layers_outlined),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: '减少分段',
          onPressed:
              segmentsPerDay <= 1 ? null : () => onChanged(segmentsPerDay - 1),
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('每天 $segmentsPerDay 段'),
        ),
        IconButton.filledTonal(
          tooltip: '增加分段',
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
                AppLocalizations.of(context)!.futureDayBanner(
                    DateFormat('yyyy-MM-dd').format(selectedDay)),
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
      message: AppLocalizations.of(context)!.switchToRecordHint,
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
