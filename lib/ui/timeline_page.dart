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
part 'timeline_desktop_page.dart';
part 'timeline_mobile_page.dart';
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
  TimelineSpan _span = TimelineSpan.day;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= expandedBreakpoint;
        return AnimatedBuilder(
          animation: state,
          builder: (context, _) {
            final rangeStart = state.selectedDay.startOfDay;
            final isFutureDay =
                state.selectedDay.startOfDay.isAfter(state.now.startOfDay);
            final rangeEnd = rangeStart.add(Duration(days: _span.days));
            if (desktop) {
              return _DesktopTimelinePage(
                state: state,
                mode: _mode,
                span: _span,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                isFutureDay: isFutureDay,
                rangeDataFuture: _rangeDataFor(state, rangeStart, rangeEnd),
                onModeChanged: (value) => setState(() => _mode = value),
                onSpanChanged: (value) {
                  setState(() => _span = value);
                  if (value == TimelineSpan.day) {
                    unawaited(state.selectDay(state.now.startOfDay));
                  }
                },
                onDateTap: _pickDate,
                onPreviousRange: selectPreviousRange,
                onNextRange: selectNextRange,
                onAddEntry: openEntryEditor,
              );
            }
            return _MobileTimelinePage(
              state: state,
              mode: _mode,
              span: _span,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              isFutureDay: isFutureDay,
              rangeDataFuture: _rangeDataFor(state, rangeStart, rangeEnd),
              maxWidth: constraints.maxWidth < compactBreakpoint ? 430 : 720,
              showGeneratedGaps: constraints.maxWidth >= compactBreakpoint,
              onModeChanged: (value) => setState(() => _mode = value),
              onSpanChanged: (value) {
                setState(() => _span = value);
                if (value == TimelineSpan.day) {
                  unawaited(state.selectDay(state.now.startOfDay));
                }
              },
              onDateTap: _pickDate,
              onPreviousRange: selectPreviousRange,
              onNextRange: selectNextRange,
              onAddEntry: openEntryEditor,
            );
          },
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
