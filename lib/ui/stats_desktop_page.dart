part of 'stats_page.dart';

class DesktopStatsPage extends StatelessWidget {
  const DesktopStatsPage({
    required this.state,
    required this.range,
    required this.selectedPreset,
    required this.stats,
    required this.previousStats,
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
  final TimeRangeStats previousStats;
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
    final rows = stats.groupRows(dimension: StatsDimension.activity);
    final rangeDays = _rangeDayCount(range);
    final averageMinutes = rangeDays == 0
        ? 0
        : (stats.totalDuration.inMinutes / rangeDays).round();
    final previousAverageMinutes = rangeDays == 0
        ? 0
        : (previousStats.totalDuration.inMinutes / rangeDays).round();
    final metricCards = [
      _MobileStatsMetricCard(
        label: _mobileText(
          context,
          english: 'Total Time',
          chinese: '总时长',
        ),
        value: _formatMobileDuration(
          context,
          stats.totalDuration,
          padMinutes: false,
        ),
        delta: _formatMobileDelta(
          context,
          currentMinutes: stats.totalDuration.inMinutes,
          previousMinutes: previousStats.totalDuration.inMinutes,
          preset: selectedPreset,
        ),
      ),
      _MobileStatsMetricCard(
        label: _mobileText(
          context,
          english: 'Daily Avg',
          chinese: '日均',
        ),
        value: _formatMobileDuration(
          context,
          Duration(minutes: averageMinutes),
          padMinutes: true,
        ),
        delta: _formatMobileDelta(
          context,
          currentMinutes: averageMinutes,
          previousMinutes: previousAverageMinutes,
          preset: selectedPreset,
        ),
      ),
    ];
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
        Row(
          children: [
            Expanded(child: metricCards[0]),
            const SizedBox(width: 10),
            Expanded(child: metricCards[1]),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final dayChart = _MobileDayBarsChart(
              range: range,
              dayTotals: stats.totalsByDay,
            );
            final activityChart = _MobileActivityDonut(
              rows: rows,
              totalMinutes: totalMinutes,
            );
            if (constraints.maxWidth < 960) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  dayChart,
                  const SizedBox(height: 12),
                  activityChart,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: dayChart),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: activityChart),
              ],
            );
          },
        ),
      ],
    );
  }
}
