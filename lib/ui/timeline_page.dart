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
import 'activity_color_picker.dart';
import 'activity_colors.dart';
import 'activity_editor_dialog.dart';
import 'snackbar_helper.dart';
import 'sort_controls.dart';
import 'ui_components.dart';

part 'timeline_canvas.dart';
part 'timeline_entry_lists.dart';
part 'timeline_entry_editor.dart';
part 'timeline_header.dart';
part 'timeline_surface_widgets.dart';

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

Duration _visibleEntryDurationForRange(
  TimeEntry entry,
  DateTime rangeStart,
  DateTime rangeEnd,
  DateTime now,
) {
  final rawEnd = entry.endAt ?? now;
  final visibleStart =
      entry.startAt.isBefore(rangeStart) ? rangeStart : entry.startAt;
  final visibleEnd = rawEnd.isAfter(rangeEnd) ? rangeEnd : rawEnd;
  if (!visibleEnd.isAfter(visibleStart)) {
    return Duration.zero;
  }
  return visibleEnd.difference(visibleStart);
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
  _TimelineRangeCacheKey? _rangeDataKey;
  Future<_TimelineRangeData>? _rangeDataFuture;

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
    if (oldWidget.state != widget.state) {
      _rangeDataKey = null;
      _rangeDataFuture = null;
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
          onRefresh: state.refresh,
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
              future: _rangeDataFor(state, rangeStart, rangeEnd),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Icon(
                        Icons.hourglass_empty,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                }
                final data = snapshot.data ?? const _TimelineRangeData.empty();
                final content = switch (_mode) {
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TimelineRangeSummaryCard(
                      state: state,
                      entries: data.entries,
                      logs: data.logs,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      mode: _mode,
                    ),
                    const SectionGap(height: 12),
                    content,
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<_TimelineRangeData> _rangeDataFor(
    AppState state,
    DateTime start,
    DateTime end,
  ) {
    final key = _TimelineRangeCacheKey(
      start: start,
      end: end,
      span: _span,
      dataRevision: state.dataRevision,
    );
    final cached = _rangeDataFuture;
    if (cached != null && _rangeDataKey == key) {
      return cached;
    }
    _rangeDataKey = key;
    return _rangeDataFuture = _loadRangeData(state, start, end);
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

class _TimelineRangeCacheKey {
  const _TimelineRangeCacheKey({
    required this.start,
    required this.end,
    required this.span,
    required this.dataRevision,
  });

  final DateTime start;
  final DateTime end;
  final TimelineSpan span;
  final int dataRevision;

  @override
  bool operator ==(Object other) {
    return other is _TimelineRangeCacheKey &&
        other.start == start &&
        other.end == end &&
        other.span == span &&
        other.dataRevision == dataRevision;
  }

  @override
  int get hashCode => Object.hash(start, end, span, dataRevision);
}

class _TimelineRangeData {
  const _TimelineRangeData({required this.entries, required this.logs});

  const _TimelineRangeData.empty()
      : entries = const [],
        logs = const [];

  final List<TimeEntry> entries;
  final List<ActionLog> logs;
}
