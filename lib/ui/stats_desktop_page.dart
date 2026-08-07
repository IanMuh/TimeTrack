part of 'stats_page.dart';

class DesktopStatsPage extends StatelessWidget {
  const DesktopStatsPage({
    required this.state,
    required this.range,
    required this.selectedPreset,
    required this.stats,
    required this.dimension,
    required this.selectedCategoryIds,
    required this.totalMinutes,
    required this.onPresetChanged,
    required this.onPickCustomDay,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onDimensionChanged,
    required this.onCategoryFilterToggled,
    super.key,
  });

  final AppState state;
  final StatsRange range;
  final StatsPreset selectedPreset;
  final TimeRangeStats stats;
  final StatsDimension dimension;
  final Set<String> selectedCategoryIds;
  final int totalMinutes;
  final ValueChanged<StatsPreset> onPresetChanged;
  final VoidCallback onPickCustomDay;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final ValueChanged<StatsDimension> onDimensionChanged;
  final ValueChanged<String> onCategoryFilterToggled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = stats.groupRows(
      dimension: dimension,
      selectedCategoryIds: selectedCategoryIds,
    );
    final rangeDays = _rangeDayCount(range);
    final averageMinutes = rangeDays == 0
        ? 0
        : (stats.totalDuration.inMinutes / rangeDays).round();
    final sessionCount = stats.groupSlices.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatsHeader(
          range: range,
          selectedPreset: selectedPreset,
          onPresetChanged: onPresetChanged,
          onPickCustomDay: onPickCustomDay,
          onPreviousDay: onPreviousDay,
          onNextDay: onNextDay,
        ),
        const SizedBox(height: 16),
        _DesktopStatsMetricRow(
          metrics: [
            _DesktopStatsMetric(
              icon: Icons.timer_outlined,
              label: l10n.totalRangeRecords,
              value: formatDurationForDisplay(context, stats.totalDuration),
              color: Theme.of(context).colorScheme.primary,
            ),
            _DesktopStatsMetric(
              icon: Icons.auto_graph_outlined,
              label: l10n.longestStreak,
              value: formatDurationForDisplay(context, stats.longestBlock),
              color: Theme.of(context).colorScheme.secondary,
            ),
            _DesktopStatsMetric(
              icon: Icons.calendar_today_outlined,
              label: _mobileText(
                context,
                english: 'Daily Avg',
                chinese: '日均',
              ),
              value: formatDurationForDisplay(
                context,
                Duration(minutes: averageMinutes),
              ),
              color: const Color(0xff14b8a6),
            ),
            _DesktopStatsMetric(
              icon: Icons.view_list_outlined,
              label: l10n.sessions,
              value: NumberFormat.decimalPattern().format(sessionCount),
              color: const Color(0xff8b5cf6),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: RangeDistributionCard(
                state: state,
                title: l10n.distributionChartTitle(range.label),
                rows: rows,
                totalMinutes: totalMinutes,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: _DesktopStatsDayTrend(
                range: range,
                dayTotals: stats.totalsByDay,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: _StatsControls(
                state: state,
                dimension: dimension,
                selectedCategoryIds: selectedCategoryIds,
                onDimensionChanged: onDimensionChanged,
                onCategoryFilterToggled: onCategoryFilterToggled,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: DayTotalsCard(dayTotals: stats.totalsByDay),
            ),
          ],
        ),
      ],
    );
  }
}

class _DesktopStatsMetric {
  const _DesktopStatsMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _DesktopStatsMetricRow extends StatelessWidget {
  const _DesktopStatsMetricRow({required this.metrics});

  final List<_DesktopStatsMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, metric) in metrics.indexed) ...[
          Expanded(
            child: _MetricCard(
              icon: metric.icon,
              label: metric.label,
              value: metric.value,
              color: metric.color,
            ),
          ),
          if (index != metrics.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _DesktopStatsDayTrend extends StatelessWidget {
  const _DesktopStatsDayTrend({
    required this.range,
    required this.dayTotals,
  });

  final StatsRange range;
  final Map<DateTime, Duration> dayTotals;

  @override
  Widget build(BuildContext context) {
    return QuietPanel(
      padding: const EdgeInsets.all(16),
      child: _MobileDayBarsChart(
        range: range,
        dayTotals: dayTotals,
      ),
    );
  }
}
