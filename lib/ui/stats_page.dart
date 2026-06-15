import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../core/date_time_ext.dart';
import 'adaptive_layout.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final totals = state.todayTotals();
        final totalDuration = totals.values.fold<Duration>(
          Duration.zero,
          (sum, item) => sum + item,
        );
        final totalMinutes =
            totalDuration.inMinutes <= 0 ? 1 : totalDuration.inMinutes;
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
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < compactBreakpoint;
                final cards = [
                  _MetricCard(
                    label: '今日总记录',
                    value: formatDurationCompact(totalDuration),
                  ),
                  _MetricCard(
                    label: '最长连续',
                    value: formatDurationCompact(state.longestBlock()),
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
            FutureBuilder<Map<String, Duration>>(
              future: state.weekTotals(),
              builder: (context, snapshot) {
                final weekTotals = snapshot.data ?? const <String, Duration>{};
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final expanded = constraints.maxWidth >= expandedBreakpoint;
                    final todayCard = TodayDistributionCard(
                      state: state,
                      totals: totals,
                      totalMinutes: totalMinutes,
                    );
                    final weekCard = WeekTotalsCard(
                      state: state,
                      weekTotals: weekTotals,
                    );
                    if (!expanded) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          todayCard,
                          const SectionGap(),
                          weekCard,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: todayCard),
                        const SizedBox(width: 16),
                        Expanded(flex: 5, child: weekCard),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class TodayDistributionCard extends StatelessWidget {
  const TodayDistributionCard({
    required this.state,
    required this.totals,
    required this.totalMinutes,
    super.key,
  });

  final AppState state;
  final Map<String, Duration> totals;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日分布',
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

class WeekTotalsCard extends StatelessWidget {
  const WeekTotalsCard({
    required this.state,
    required this.weekTotals,
    super.key,
  });

  final AppState state;
  final Map<String, Duration> weekTotals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本周累计',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (weekTotals.isEmpty)
              const Text('暂无数据')
            else
              for (final item in weekTotals.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    state.activityById(item.key)?.name ?? '未知事项',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(formatDurationCompact(item.value)),
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
