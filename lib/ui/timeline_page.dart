import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
import 'ui_components.dart';

part 'timeline_canvas.dart';
part 'timeline_entry_lists.dart';
part 'timeline_entry_editor.dart';

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
                          ? AppLocalizations.of(context)!.emptyDayEntries
                          : AppLocalizations.of(context)!.emptyRangeEntries,
                    ),
                  TimelineViewMode.actions => _ActionLogList(
                      state: state,
                      logs: data.logs,
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
                label: Text(AppLocalizations.of(context)!.addEntry),
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
