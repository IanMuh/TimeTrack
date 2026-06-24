part of 'timeline_page.dart';

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
        TimelineCardHeader(
          title: AppLocalizations.of(context)!.entryList,
          subtitle: AppLocalizations.of(context)!.entryListHint,
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
        ? AppLocalizations.of(context)!.inProgress
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
            label: AppLocalizations.of(context)!
                .editEntrySemantics(state.activityNameForEntry(entry)),
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
                    tooltip: AppLocalizations.of(context)!.editTooltip,
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
    final color = Color(
      activity?.color ?? AppConstants.defaultActivityColor,
    );
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
                            : '${log.message}: ${activity.name}',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(AppLocalizations.of(context)!
                          .deviceLabel(log.deviceId)),
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

  IconData _logIcon(ActionType actionType) {
    return switch (actionType) {
      ActionType.switch_ => Icons.swap_horiz,
      ActionType.stop => Icons.stop_circle_outlined,
      ActionType.manual => Icons.add_circle_outline,
      ActionType.edit => Icons.edit_outlined,
      ActionType.delete => Icons.delete_outline,
      ActionType.merge => Icons.merge_type_outlined,
      ActionType.split => Icons.call_split_outlined,
      ActionType.activityDelete => Icons.label_off_outlined,
      _ => Icons.bolt_outlined,
    };
  }
}
