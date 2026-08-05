import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_state.dart';
import '../domain/time_entry.dart';
import '../l10n/app_localizations.dart';
import 'current_status_card_helpers.dart';
import 'today_metric_card.dart';
import 'today_summary.dart';

class DesktopTodayPage extends StatelessWidget {
  const DesktopTodayPage({
    required this.state,
    required this.summary,
    required this.metrics,
    required this.now,
    required this.onSelectDate,
    required this.onOpenTimeline,
    super.key,
  });

  final AppState state;
  final TodaySummary summary;
  final List<TodayMetricData> metrics;
  final DateTime now;
  final VoidCallback onSelectDate;
  final VoidCallback? onOpenTimeline;

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final entry in state.dayEntries)
        if (!entry.isDeleted) entry,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DesktopTodayHeader(
          selectedDay: state.selectedDay,
          onSelectDate: onSelectDate,
        ),
        const SizedBox(height: 16),
        _DesktopMetricRow(metrics: metrics),
        const SizedBox(height: 12),
        SizedBox(
          height: 214,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: _DesktopSurface(
                  child: _DesktopActivityBreakdown(
                    activities: summary.activities,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: _DesktopSurface(
                  child: _DesktopTimelinePreview(
                    entries: entries,
                    now: now,
                    onOpenTimeline: onOpenTimeline,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DesktopSurface(
          child: _DesktopTopActivities(activities: summary.activities),
        ),
      ],
    );
  }
}

class _DesktopTodayHeader extends StatelessWidget {
  const _DesktopTodayHeader({
    required this.selectedDay,
    required this.onSelectDate,
  });

  final DateTime selectedDay;
  final VoidCallback onSelectDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.navToday,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat.yMMMMd(localeName).format(selectedDay),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat.EEEE(localeName).format(selectedDay),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.selectDate,
          onPressed: onSelectDate,
          icon: const Icon(Icons.calendar_today_outlined),
        ),
      ],
    );
  }
}

class _DesktopMetricRow extends StatelessWidget {
  const _DesktopMetricRow({required this.metrics});

  final List<TodayMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, metric) in metrics.indexed) ...[
          Expanded(child: _DesktopMetricCard(metric: metric)),
          if (index != metrics.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _DesktopMetricCard extends StatelessWidget {
  const _DesktopMetricCard({required this.metric});

  final TodayMetricData metric;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final supportingColor = metric.positive
        ? const Color(0xff16a34a)
        : colorScheme.onSurfaceVariant;
    return SizedBox(
      height: 80,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                metric.supportingText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: supportingColor,
                      fontWeight:
                          metric.positive ? FontWeight.w700 : FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopSurface extends StatelessWidget {
  const _DesktopSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

class _DesktopActivityBreakdown extends StatelessWidget {
  const _DesktopActivityBreakdown({required this.activities});

  final List<TodayActivityTotal> activities;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.todayTimeByActivity,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Center(
                  child: CustomPaint(
                    size: const Size.square(124),
                    painter: _ActivityDonutPainter(
                      activities: activities,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final activity in activities)
                      _ActivityLegendRow(activity: activity),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityLegendRow extends StatelessWidget {
  const _ActivityLegendRow({required this.activity});

  final TodayActivityTotal activity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: Color(activity.color)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              activity.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Text(
            '${activity.percent}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityDonutPainter extends CustomPainter {
  const _ActivityDonutPainter({
    required this.activities,
    required this.backgroundColor,
  });

  final List<TodayActivityTotal> activities;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final totalSeconds = activities.fold<int>(
      0,
      (total, activity) => total + activity.duration.inSeconds,
    );
    if (totalSeconds == 0) {
      final paint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.28;
      canvas.drawCircle(center, radius * 0.72, paint);
      return;
    }

    final rect = Rect.fromCircle(center: center, radius: radius * 0.72);
    final ringWidth = radius * 0.30;
    var start = -math.pi / 2;
    for (final activity in activities) {
      final sweep = math.pi * 2 * activity.duration.inSeconds / totalSeconds;
      final paint = Paint()
        ..color = Color(activity.color)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = ringWidth;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }

    final holePaint = Paint()..color = backgroundColor;
    canvas.drawCircle(center, radius * 0.54, holePaint);
  }

  @override
  bool shouldRepaint(_ActivityDonutPainter oldDelegate) {
    return oldDelegate.activities != activities ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _DesktopTimelinePreview extends StatelessWidget {
  const _DesktopTimelinePreview({
    required this.entries,
    required this.now,
    required this.onOpenTimeline,
  });

  final List<TimeEntry> entries;
  final DateTime now;
  final VoidCallback? onOpenTimeline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = entries.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.navTimeline,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (onOpenTimeline != null)
              TextButton(
                onPressed: onOpenTimeline,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                child: Text(l10n.todayViewFullTimeline),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    l10n.noData,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final (index, entry) in visible.indexed)
                      _DesktopTimelineRow(
                        entry: entry,
                        now: now,
                        index: index,
                        count: visible.length,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DesktopTimelineRow extends StatelessWidget {
  const _DesktopTimelineRow({
    required this.entry,
    required this.now,
    required this.index,
    required this.count,
  });

  final TimeEntry entry;
  final DateTime now;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = entry.activityNameSnapshot;
    final activityColor = Color(entry.activityColorSnapshot ?? 0xff64748b);
    final detail = entry.note.trim().isEmpty
        ? formatSummaryDuration(entry.durationUntil(now))
        : entry.note.trim();
    final showingDuration = entry.note.trim().isEmpty;
    return Expanded(
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              DateFormat('h:mm a').format(entry.startAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: index == 0 ? 15 : 0,
                  bottom: index == count - 1 ? 15 : 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                    ),
                    child: const SizedBox(width: 1),
                  ),
                ),
                Icon(Icons.circle, size: 7, color: activityColor),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            flex: 5,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: activityColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFeatures: showingDuration
                        ? const [FontFeature.tabularFigures()]
                        : null,
                    fontWeight:
                        showingDuration ? FontWeight.w500 : FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopTopActivities extends StatelessWidget {
  const _DesktopTopActivities({required this.activities});

  final List<TodayActivityTotal> activities;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            l10n.todayTopActivities,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        for (final activity in activities)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _DesktopTopActivityChip(activity: activity),
            ),
          ),
      ],
    );
  }
}

class _DesktopTopActivityChip extends StatelessWidget {
  const _DesktopTopActivityChip({required this.activity});

  final TodayActivityTotal activity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 46,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(activity.color).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: Color(activity.color)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      activity.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text(
                  _formatDesktopDuration(activity.duration),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDesktopDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes < 60) {
    return '${totalMinutes}m';
  }
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}
