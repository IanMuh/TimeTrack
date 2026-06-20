import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_state.dart';
import '../core/date_time_ext.dart';
import 'adaptive_layout.dart';
import 'ui_components.dart';

enum StatsPreset { today, yesterday, thisWeek, lastWeek, customDay }

class StatsRange {
  const StatsRange({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;
}

class StatsPage extends StatefulWidget {
  const StatsPage({required this.state, super.key});

  final AppState state;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  StatsPreset _preset = StatsPreset.today;
  DateTime _customDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final range = _rangeFor(state.now);
        return AdaptivePage(
          pageKey: const PageStorageKey('stats-page'),
          children: [
            StatsHeader(
              range: range,
              selectedPreset: _preset,
              onPresetChanged: (preset) => setState(() => _preset = preset),
              onPickCustomDay: () => _pickCustomDay(context),
              onPreviousDay: () => _shiftCustomDay(-1),
              onNextDay: () => _shiftCustomDay(1),
            ),
            const SectionGap(),
            FutureBuilder<TimeRangeStats>(
              future: state.statsForRange(start: range.start, end: range.end),
              builder: (context, snapshot) {
                final stats = snapshot.data ??
                    const TimeRangeStats(
                      totalsByActivity: {},
                      totalsByDay: {},
                      totalDuration: Duration.zero,
                      longestBlock: Duration.zero,
                    );
                final totalMinutes = stats.totalDuration.inMinutes <= 0
                    ? 1
                    : stats.totalDuration.inMinutes;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatsMetrics(
                      totalDuration: stats.totalDuration,
                      longestBlock: stats.longestBlock,
                    ),
                    const SectionGap(),
                    _StatsCharts(
                      state: state,
                      range: range,
                      stats: stats,
                      totalMinutes: totalMinutes,
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

  StatsRange _rangeFor(DateTime now) {
    final today = now.startOfDay;
    return switch (_preset) {
      StatsPreset.today => StatsRange(
          start: today,
          end: today.add(const Duration(days: 1)),
          label: '今天',
        ),
      StatsPreset.yesterday => StatsRange(
          start: today.subtract(const Duration(days: 1)),
          end: today,
          label: '昨天',
        ),
      StatsPreset.thisWeek => _weekRange(today, '本周'),
      StatsPreset.lastWeek => _weekRange(
          today.subtract(const Duration(days: 7)),
          '上周',
        ),
      StatsPreset.customDay => StatsRange(
          start: _customDay.startOfDay,
          end: _customDay.startOfDay.add(const Duration(days: 1)),
          label: DateFormat('yyyy-MM-dd').format(_customDay),
        ),
    };
  }

  StatsRange _weekRange(DateTime anchor, String label) {
    final start = anchor.subtract(Duration(days: anchor.weekday - 1));
    return StatsRange(
      start: start.startOfDay,
      end: start.startOfDay.add(const Duration(days: 7)),
      label: label,
    );
  }

  Future<void> _pickCustomDay(BuildContext context) async {
    final next = await showDatePicker(
      context: context,
      initialDate: _customDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (next == null) {
      return;
    }
    setState(() {
      _preset = StatsPreset.customDay;
      _customDay = next;
    });
  }

  void _shiftCustomDay(int days) {
    setState(() {
      final anchor = _preset == StatsPreset.customDay
          ? _customDay
          : _rangeFor(widget.state.now).start;
      _preset = StatsPreset.customDay;
      _customDay = anchor.add(Duration(days: days));
    });
  }
}

class StatsHeader extends StatelessWidget {
  const StatsHeader({
    required this.range,
    required this.selectedPreset,
    required this.onPresetChanged,
    required this.onPickCustomDay,
    required this.onPreviousDay,
    required this.onNextDay,
    super.key,
  });

  final StatsRange range;
  final StatsPreset selectedPreset;
  final ValueChanged<StatsPreset> onPresetChanged;
  final VoidCallback onPickCustomDay;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context) {
    final header = PageHeader(
      title: '统计',
      subtitle: '查看 ${range.label} 的时间分布和每日累计。',
      trailing: StatusPill(
        label: range.label,
        icon: Icons.insights_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final controls = _StatsPresetControl(
          selectedPreset: selectedPreset,
          compact: compact,
          onPresetChanged: onPresetChanged,
        );
        final dayStepper = _StatsDayStepper(
          onPreviousDay: onPreviousDay,
          onPickCustomDay: onPickCustomDay,
          onNextDay: onNextDay,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 12),
              controls,
              const SizedBox(height: 10),
              dayStepper,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: controls),
                const SizedBox(width: 12),
                dayStepper,
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatsDayStepper extends StatelessWidget {
  const _StatsDayStepper({
    required this.onPreviousDay,
    required this.onPickCustomDay,
    required this.onNextDay,
  });

  final VoidCallback onPreviousDay;
  final VoidCallback onPickCustomDay;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
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
          OutlinedButton.icon(
            onPressed: onPickCustomDay,
            icon: const Icon(Icons.event),
            label: const Text('选择日期'),
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

class _StatsPresetControl extends StatelessWidget {
  const _StatsPresetControl({
    required this.selectedPreset,
    required this.compact,
    required this.onPresetChanged,
  });

  final StatsPreset selectedPreset;
  final bool compact;
  final ValueChanged<StatsPreset> onPresetChanged;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return DropdownButtonFormField<StatsPreset>(
        initialValue: selectedPreset,
        decoration: const InputDecoration(
          labelText: '范围',
          prefixIcon: Icon(Icons.date_range),
        ),
        items: [
          for (final preset in StatsPreset.values)
            DropdownMenuItem(
              value: preset,
              child: Text(_presetLabel(preset)),
            ),
        ],
        onChanged: (value) {
          if (value != null) {
            onPresetChanged(value);
          }
        },
      );
    }

    return SegmentedButton<StatsPreset>(
      segments: [
        for (final preset in StatsPreset.values)
          ButtonSegment(
            value: preset,
            label: Text(_presetLabel(preset)),
          ),
      ],
      selected: {selectedPreset},
      onSelectionChanged: (value) => onPresetChanged(value.first),
    );
  }

  String _presetLabel(StatsPreset preset) {
    return switch (preset) {
      StatsPreset.today => '今天',
      StatsPreset.yesterday => '昨天',
      StatsPreset.thisWeek => '本周',
      StatsPreset.lastWeek => '上周',
      StatsPreset.customDay => '单日',
    };
  }
}

class _StatsMetrics extends StatelessWidget {
  const _StatsMetrics({
    required this.totalDuration,
    required this.longestBlock,
  });

  final Duration totalDuration;
  final Duration longestBlock;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final cards = [
          _MetricCard(
            label: '范围总记录',
            value: formatDurationCompact(totalDuration),
          ),
          _MetricCard(
            label: '最长连续',
            value: formatDurationCompact(longestBlock),
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
    );
  }
}

class _StatsCharts extends StatelessWidget {
  const _StatsCharts({
    required this.state,
    required this.range,
    required this.stats,
    required this.totalMinutes,
  });

  final AppState state;
  final StatsRange range;
  final TimeRangeStats stats;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth >= expandedBreakpoint;
        final distributionCard = RangeDistributionCard(
          state: state,
          title: '${range.label}分布',
          totals: stats.totalsByActivity,
          totalMinutes: totalMinutes,
        );
        final dayTotalsCard = DayTotalsCard(dayTotals: stats.totalsByDay);
        if (!expanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              distributionCard,
              const SectionGap(),
              dayTotalsCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: distributionCard),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: dayTotalsCard),
          ],
        );
      },
    );
  }
}

class RangeDistributionCard extends StatelessWidget {
  const RangeDistributionCard({
    required this.state,
    required this.title,
    required this.totals,
    required this.totalMinutes,
    super.key,
  });

  final AppState state;
  final String title;
  final Map<String, Duration> totals;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: title,
            subtitle: totals.isEmpty ? '暂无可视化数据' : '按事项汇总，颜色与事项保持一致。',
            icon: Icons.pie_chart_outline,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final chart = SizedBox(
                height: compact ? 220 : 260,
                child: totals.isEmpty
                    ? const EmptyState(
                        icon: Icons.pie_chart_outline,
                        title: '暂无数据',
                        message: '开始记录或选择其他范围后会显示分布。',
                      )
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
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
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
                    _LegendRow(
                      color: Color(
                        state.activityById(item.key)?.color ?? 0xff64748b,
                      ),
                      label: state.activityById(item.key)?.name ?? '未知事项',
                      value: formatDurationCompact(item.value),
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
    );
  }
}

class DayTotalsCard extends StatelessWidget {
  const DayTotalsCard({required this.dayTotals, super.key});

  final Map<DateTime, Duration> dayTotals;

  @override
  Widget build(BuildContext context) {
    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: '每日累计',
            subtitle: '用于观察本周或自选范围的记录节奏。',
            icon: Icons.calendar_view_week_outlined,
          ),
          const SizedBox(height: 12),
          if (dayTotals.isEmpty)
            const EmptyState(
              icon: Icons.event_busy_outlined,
              title: '暂无数据',
              message: '有记录后会按日期列出总时长。',
            )
          else
            for (final item in _sortedDayTotals())
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  DateFormat('yyyy-MM-dd').format(item.key),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(formatDurationCompact(item.value)),
              ),
        ],
      ),
    );
  }

  List<MapEntry<DateTime, Duration>> _sortedDayTotals() {
    return dayTotals.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return QuietPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
