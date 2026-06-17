import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../core/date_time_ext.dart';
import '../domain/stats_period.dart';
import 'adaptive_layout.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({required this.state, super.key});

  final AppState state;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  StatsPeriod _period = StatsPeriod.day;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return AdaptivePage(
          pageKey: const PageStorageKey('stats-page'),
          children: [
            Text(
              '统计',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SectionGap(),
            SegmentedButton<StatsPeriod>(
              segments: StatsPeriod.values
                  .map(
                    (p) => ButtonSegment<StatsPeriod>(
                      value: p,
                      label: Text(p.label),
                    ),
                  )
                  .toList(),
              selected: {_period},
              onSelectionChanged: (value) =>
                  setState(() => _period = value.first),
            ),
            const SectionGap(),
            FutureBuilder<PeriodStats>(
              future: _fetchPeriodStats(state, _period),
              builder: (context, snapshot) {
                final stats = snapshot.data ??
                    const PeriodStats(
                      totals: {},
                      longestBlock: Duration.zero,
                    );
                final totalDuration = stats.totals.values.fold<Duration>(
                  Duration.zero,
                  (sum, item) => sum + item,
                );
                final totalMinutes = totalDuration.inMinutes <= 0
                    ? 1
                    : totalDuration.inMinutes;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact =
                            constraints.maxWidth < compactBreakpoint;
                        final cards = [
                          _MetricCard(
                            label: _period.totalRecordsLabel(),
                            value: formatDurationCompact(totalDuration),
                          ),
                          _MetricCard(
                            label: '最长连续',
                            value:
                                formatDurationCompact(stats.longestBlock),
                          ),
                        ];
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              cards[0],
                              const SizedBox(height: 12),
                              cards[1],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 12),
                            Expanded(child: cards[1]),
                          ],
                        );
                      },
                    ),
                    const SectionGap(),
                    PeriodDistributionCard(
                      state: state,
                      totals: stats.totals,
                      totalMinutes: totalMinutes,
                      title: _period.distributionTitle(),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class PeriodStats {
  const PeriodStats({
    required this.totals,
    required this.longestBlock,
  });

  final Map<String, Duration> totals;
  final Duration longestBlock;
}

Future<PeriodStats> _fetchPeriodStats(AppState state, StatsPeriod period) async {
  final totals = await state.totalsForPeriod(period);
  final longestBlock = await state.longestBlockForPeriod(period);
  return PeriodStats(totals: totals, longestBlock: longestBlock);
}

class PeriodDistributionCard extends StatelessWidget {
  const PeriodDistributionCard({
    required this.state,
    required this.totals,
    required this.totalMinutes,
    required this.title,
    super.key,
  });

  final AppState state;
  final Map<String, Duration> totals;
  final int totalMinutes;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final chart = SizedBox(
                  height: compact ? 220 : 260,
                  child: totals.isEmpty
                      ? const Center(child: Text('暂无数据'))
                      : PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: compact ? 44 : 54,
                            sections: [
                              for (final item in totals.entries)
                                PieChartSectionData(
                                  value: item.value.inMinutes
                                      .clamp(1, 1 << 31)
                                      .toDouble(),
                                  title:
                                      '${(item.value.inMinutes / totalMinutes * 100).round()}%',
                                  radius: compact ? 74 : 88,
                                  color: Color(
                                    state.activityById(item.key)?.color ??
                                        0xff64748b,
                                  ),
                                ),
                            ],
                          ),
                        ),
                );
                final legend = Column(
                  children: [
                    for (final item in totals.entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.circle,
                          color: Color(
                            state.activityById(item.key)?.color ?? 0xff64748b,
                          ),
                        ),
                        title: Text(
                          state.activityById(item.key)?.name ?? '未知事项',
                        ),
                        trailing: Text(formatDurationCompact(item.value)),
                      ),
                  ],
                );
                if (compact) {
                  return Column(
                    children: [
                      chart,
                      const SizedBox(height: 12),
                      legend,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: chart),
                    const SizedBox(width: 20),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
