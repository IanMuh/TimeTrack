part of 'timeline_page.dart';

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

class TimelineRangeSummaryCard extends StatelessWidget {
  const TimelineRangeSummaryCard({
    required this.state,
    required this.entries,
    required this.logs,
    required this.rangeStart,
    required this.rangeEnd,
    required this.mode,
    super.key,
  });

  final AppState state;
  final List<TimeEntry> entries;
  final List<ActionLog> logs;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final TimelineViewMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final totalDuration = entries.fold<Duration>(
      Duration.zero,
      (total, entry) =>
          total +
          _visibleEntryDurationForRange(
            entry,
            rangeStart,
            rangeEnd,
            state.now,
          ),
    );
    final longestBlock = entries.fold<Duration>(
      Duration.zero,
      (longest, entry) {
        final duration = _visibleEntryDurationForRange(
          entry,
          rangeStart,
          rangeEnd,
          state.now,
        );
        return duration > longest ? duration : longest;
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final countLabel =
            mode == TimelineViewMode.entries ? l10n.sessions : l10n.actions;
        final countValue =
            mode == TimelineViewMode.entries ? entries.length : logs.length;
        final tiles = [
          _TimelineSummaryTile(
            icon: Icons.timer_outlined,
            label: l10n.totalRangeRecords,
            value: compact
                ? _formatTimelineDurationTerse(context, totalDuration)
                : formatDurationForDisplay(context, totalDuration),
            color: colorScheme.primary,
          ),
          _TimelineSummaryTile(
            icon: mode == TimelineViewMode.entries
                ? Icons.view_list_outlined
                : Icons.swap_horiz,
            label: countLabel,
            value: NumberFormat.decimalPattern().format(countValue),
            color: colorScheme.secondary,
          ),
          _TimelineSummaryTile(
            icon: Icons.auto_graph_outlined,
            label: l10n.longestStreak,
            value: compact
                ? _formatTimelineDurationTerse(context, longestBlock)
                : formatDurationForDisplay(context, longestBlock),
            color: colorScheme.primary,
          ),
        ];
        return TimelineSurface(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: compact
              ? Row(
                  children: [
                    for (final (index, tile) in tiles.indexed) ...[
                      Expanded(
                        child: _TimelineSummaryTile(
                          icon: tile.icon,
                          label: tile.label,
                          value: tile.value,
                          color: tile.color,
                          dense: true,
                        ),
                      ),
                      if (index != tiles.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                )
              : Row(
                  children: [
                    for (final (index, tile) in tiles.indexed) ...[
                      Expanded(child: tile),
                      if (index != tiles.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

String _formatTimelineDurationTerse(BuildContext context, Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final languageCode = Localizations.localeOf(context).languageCode;
  if (languageCode == 'zh') {
    if (hours == 0) {
      return '$minutes分';
    }
    if (minutes == 0) {
      return '$hours小时';
    }
    return '$hours小时$minutes分';
  }
  if (hours == 0) {
    return '${minutes}m';
  }
  if (minutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${minutes}m';
}

class _TimelineSummaryTile extends StatelessWidget {
  const _TimelineSummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: EdgeInsets.all(dense ? 9 : 12),
        child: dense
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(icon: icon, color: color, size: 30),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      softWrap: false,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  IconBadge(icon: icon, color: color, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
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
