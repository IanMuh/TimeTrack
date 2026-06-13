import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../core/date_time_ext.dart';

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
        final totalMinutes = totalDuration.inMinutes <= 0
            ? 1
            : totalDuration.inMinutes;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '统计',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: '今日总记录',
                    value: formatDurationCompact(totalDuration),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: '最长连续',
                    value: formatDurationCompact(state.longestBlock()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
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
                    SizedBox(
                      height: 220,
                      child: totals.isEmpty
                          ? const Center(child: Text('暂无数据'))
                          : PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 44,
                                sections: [
                                  for (final item in totals.entries)
                                    PieChartSectionData(
                                      value: item.value.inMinutes
                                          .clamp(1, 1 << 31)
                                          .toDouble(),
                                      title:
                                          '${(item.value.inMinutes / totalMinutes * 100).round()}%',
                                      radius: 74,
                                      color: Color(
                                        state.activityById(item.key)?.color ??
                                            0xff64748b,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    for (final item in totals.entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.circle,
                          color: Color(
                            state.activityById(item.key)?.color ?? 0xff64748b,
                          ),
                        ),
                        title: Text(state.activityById(item.key)?.name ?? '未知事项'),
                        trailing: Text(formatDurationCompact(item.value)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, Duration>>(
              future: state.weekTotals(),
              builder: (context, snapshot) {
                final weekTotals = snapshot.data ?? const <String, Duration>{};
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本周累计',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
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
                              ),
                              trailing: Text(formatDurationCompact(item.value)),
                            ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
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
