import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_state.dart';
import '../core/date_time_ext.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/time_entry.dart';
import 'adaptive_layout.dart';
import 'home_page.dart';

enum TimelineViewMode { coverage, actions }

class TimelinePage extends StatefulWidget {
  const TimelinePage({required this.state, super.key});

  final AppState state;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  TimelineViewMode _mode = TimelineViewMode.coverage;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final entries = state.visibleDayEntries();
        final logs = [...state.dayActionLogs]
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
        return AdaptivePage(
          pageKey: const PageStorageKey('timeline-page'),
          children: [
            TimelineHeader(
              selectedDay: state.selectedDay,
              mode: _mode,
              onPreviousDay: () => state.selectDay(
                state.selectedDay.subtract(const Duration(days: 1)),
              ),
              onNextDay: () => state.selectDay(
                state.selectedDay.add(const Duration(days: 1)),
              ),
              onModeChanged: (value) => setState(() => _mode = value),
              onAddEntry: () => showEntryEditor(context, state),
            ),
            const SectionGap(),
            if (_mode == TimelineViewMode.coverage) ...[
              DayCoverageCard(state: state, entries: entries),
              const SizedBox(height: 14),
              if (entries.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('这一天还没有记录。'),
                  ),
                )
              else
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TimelineEntryCard(
                      state: state,
                      entry: entry,
                    ),
                  ),
            ] else ...[
              if (logs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('这一天还没有切换或编辑指令。'),
                  ),
                )
              else
                for (final log in logs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ActionLogCard(state: state, log: log),
                  ),
            ],
          ],
        );
      },
    );
  }
}

class TimelineHeader extends StatelessWidget {
  const TimelineHeader({
    required this.selectedDay,
    required this.mode,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onModeChanged,
    required this.onAddEntry,
    super.key,
  });

  final DateTime selectedDay;
  final TimelineViewMode mode;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final ValueChanged<TimelineViewMode> onModeChanged;
  final VoidCallback onAddEntry;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      '时间轴',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
    final daySelector = _DaySelector(
      selectedDay: selectedDay,
      onPreviousDay: onPreviousDay,
      onNextDay: onNextDay,
    );
    final modeSelector = SegmentedButton<TimelineViewMode>(
      segments: const [
        ButtonSegment(
          value: TimelineViewMode.coverage,
          icon: Icon(Icons.timeline),
          label: Text('覆盖'),
        ),
        ButtonSegment(
          value: TimelineViewMode.actions,
          icon: Icon(Icons.swap_horiz),
          label: Text('指令'),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (value) => onModeChanged(value.first),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 12),
              daySelector,
              const SizedBox(height: 12),
              modeSelector,
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
                Expanded(child: title),
                daySelector,
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(child: modeSelector),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onAddEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('补记'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.selectedDay,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  final DateTime selectedDay;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '前一天',
            onPressed: onPreviousDay,
            icon: const Icon(Icons.chevron_left),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 104),
            child: Text(
              DateFormat('yyyy-MM-dd').format(selectedDay),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            tooltip: '后一天',
            onPressed: onNextDay,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
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
    final dayEnd = state.selectedDay.endOfDay;
    final rawStart =
        entry.startAt.isBefore(dayStart) ? dayStart : entry.startAt;
    final rawEnd = (entry.endAt ?? state.now).isAfter(dayEnd)
        ? dayEnd
        : entry.endAt ?? state.now;
    final startRatio =
        rawStart.difference(dayStart).inSeconds.clamp(0, 86400) / 86400;
    final endRatio =
        rawEnd.difference(dayStart).inSeconds.clamp(0, 86400) / 86400;
    final left = width * startRatio;
    final segmentWidth = (width * (endRatio - startRatio)).clamp(2.0, width);
    final activity = state.activityById(entry.activityId);

    return Positioned(
      left: left,
      top: 16,
      width: segmentWidth,
      child: Tooltip(
        message:
            '${activity?.name ?? '未知事项'} ${_formatTime(entry.startAt)} - ${entry.endAt == null ? '进行中' : _formatTime(entry.endAt!)}',
        child: Container(
          height: 20,
          decoration: BoxDecoration(
            color: Color(activity?.color ?? 0xff64748b),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
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
    final activity = state.activityById(entry.activityId);
    final color = Color(activity?.color ?? 0xff64748b);
    final timeText =
        '${_formatTime(entry.startAt)} - ${entry.endAt == null ? '进行中' : _formatTime(entry.endAt!)}';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showEntryEditor(context, state, entry: entry),
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
                  title: activity?.name ?? '未知事项',
                  duration:
                      formatDurationCompact(entry.durationUntil(state.now)),
                  timeText: timeText,
                  note: entry.note,
                ),
              ),
              IconButton(
                tooltip: '编辑',
                onPressed: () => showEntryEditor(context, state, entry: entry),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
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
    return Card(
      child: Padding(
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
  if (state.activities.isEmpty) {
    return;
  }
  final selectedDay = state.selectedDay;
  var activity = entry == null
      ? state.activities.first
      : state.activityById(entry.activityId) ?? state.activities.first;
  var start = entry?.startAt ??
      DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 9);
  var end = entry?.endAt ?? start.add(const Duration(hours: 1));
  final noteController = TextEditingController(text: entry?.note ?? '');
  String? overlapWarning;

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
        if (!end.isAfter(start)) {
          end = start.add(const Duration(minutes: 30));
        }
      } else {
        end = next;
      }
    });
  }

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(entry == null ? '补记时间段' : '编辑时间段'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Activity>(
                          initialValue: activity,
                          decoration: const InputDecoration(
                            labelText: '事项',
                            prefixIcon: Icon(Icons.label_outline),
                          ),
                          items: [
                            for (final item in state.activities)
                              DropdownMenuItem(
                                value: item,
                                child: Text(item.name),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => activity = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: '新增事项',
                        onPressed: () async {
                          final created = await showActivityEditorDialog(
                            context,
                            state,
                          );
                          if (created != null) {
                            setState(() => activity = created);
                          }
                        },
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        tooltip: '编辑当前事项',
                        onPressed: () async {
                          final updated = await showActivityEditorDialog(
                            context,
                            state,
                            activity: activity,
                          );
                          if (updated != null) {
                            setState(() => activity = updated);
                          }
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
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
                    subtitle: Text(_formatDateTime(end)),
                    onTap: () =>
                        pickDateTime(isStart: false, setState: setState),
                  ),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '备注',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  if (overlapWarning != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      overlapWarning!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (entry != null)
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
                  if (!end.isAfter(start)) {
                    setState(() => overlapWarning = '结束时间必须晚于开始时间。');
                    return;
                  }
                  final next = TimeEntry(
                    id: entry?.id ?? 'preview',
                    userId: entry?.userId,
                    activityId: activity.id,
                    startAt: start,
                    endAt: end,
                    note: noteController.text.trim(),
                    deviceId: entry?.deviceId ?? 'manual-entry',
                    updatedAt: DateTime.now(),
                    isDeleted: false,
                  );
                  final overlaps = await state.overlaps(next);
                  if (overlaps.isNotEmpty && overlapWarning == null) {
                    setState(() {
                      overlapWarning = '这个时间段和已有记录重叠。再次点击保存将保留重叠并稍后手动修正。';
                    });
                    return;
                  }
                  if (entry == null) {
                    await state.createManualEntry(
                      activityId: activity.id,
                      startAt: start,
                      endAt: end,
                      note: noteController.text.trim(),
                    );
                  } else {
                    await state.saveEntry(next);
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

String _formatTime(DateTime value) => DateFormat('HH:mm:ss').format(value);

String _formatDateTime(DateTime value) =>
    DateFormat('yyyy-MM-dd HH:mm:ss').format(value);
