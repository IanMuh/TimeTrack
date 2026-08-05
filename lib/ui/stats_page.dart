import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_state.dart';
import '../core/date_time_ext.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'ui_components.dart';

part 'stats_desktop_page.dart';

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

class _StatsViewData {
  const _StatsViewData({
    required this.current,
    required this.previous,
  });

  final TimeRangeStats current;
  final TimeRangeStats previous;
}

const _emptyStats = TimeRangeStats(
  totalsByActivity: {},
  totalsByDay: {},
  totalDuration: Duration.zero,
  longestBlock: Duration.zero,
);

class _StatsLoadingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Icon(
          Icons.hourglass_empty,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class StatsPage extends StatefulWidget {
  const StatsPage({required this.state, super.key});

  final AppState state;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  StatsPreset _preset = StatsPreset.thisWeek;
  DateTime _customDay = DateTime.now();
  StatsDimension _dimension = StatsDimension.activity;
  final Set<String> _selectedCategoryIds = {};
  bool _showCompactStatsFilters = false;
  DateTime? _statsRangeStart;
  DateTime? _statsRangeEnd;
  int? _statsDataRevision;
  Future<TimeRangeStats>? _statsFuture;
  DateTime? _mobileStatsRangeStart;
  DateTime? _mobileStatsRangeEnd;
  int? _mobileStatsDataRevision;
  Future<_StatsViewData>? _mobileStatsFuture;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_invalidateStatsFuture);
  }

  @override
  void didUpdateWidget(covariant StatsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state == widget.state) {
      return;
    }
    oldWidget.state.removeListener(_invalidateStatsFuture);
    widget.state.addListener(_invalidateStatsFuture);
    _clearStatsFuture();
  }

  @override
  void dispose() {
    widget.state.removeListener(_invalidateStatsFuture);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final range = _rangeFor(state.now);
        return LayoutBuilder(
          builder: (context, constraints) {
            final sizeClass = adaptiveSizeClassFor(constraints.maxWidth);
            final compact = sizeClass == AdaptiveSizeClass.compact;
            final expanded = sizeClass == AdaptiveSizeClass.expanded;
            return AdaptivePage(
              maxWidth: compact ? 430 : 1120,
              pageKey: const PageStorageKey('stats-page'),
              onRefresh: state.refresh,
              children: [
                if (compact)
                  _MobileStatsHeader(
                    selectedPreset: _preset,
                    onPresetChanged: (preset) {
                      setState(() => _preset = preset);
                    },
                    onPickCustomDay: () => _pickCustomDay(context),
                  )
                else if (!expanded)
                  StatsHeader(
                    range: range,
                    selectedPreset: _preset,
                    onPresetChanged: (preset) {
                      setState(() => _preset = preset);
                    },
                    onPickCustomDay: () => _pickCustomDay(context),
                    onPreviousDay: () => _shiftCustomDay(-1),
                    onNextDay: () => _shiftCustomDay(1),
                  ),
                if (!expanded) SectionGap(height: compact ? 18 : 16),
                if (compact)
                  FutureBuilder<_StatsViewData>(
                    future: _mobileStatsForRange(range),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return _StatsLoadingIndicator();
                      }
                      final data = snapshot.data ??
                          const _StatsViewData(
                            current: _emptyStats,
                            previous: _emptyStats,
                          );
                      final stats = data.current;
                      final totalMinutes = stats.totalDuration.inMinutes <= 0
                          ? 1
                          : stats.totalDuration.inMinutes;
                      return _MobileStatsContent(
                        range: range,
                        selectedPreset: _preset,
                        stats: stats,
                        previousStats: data.previous,
                        totalMinutes: totalMinutes,
                      );
                    },
                  )
                else if (expanded)
                  FutureBuilder<TimeRangeStats>(
                    future: _statsForRange(range),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return _StatsLoadingIndicator();
                      }
                      final stats = snapshot.data ?? _emptyStats;
                      final totalMinutes = stats.totalDuration.inMinutes <= 0
                          ? 1
                          : stats.totalDuration.inMinutes;
                      return DesktopStatsPage(
                        state: state,
                        range: range,
                        selectedPreset: _preset,
                        stats: stats,
                        dimension: _dimension,
                        selectedCategoryIds: _selectedCategoryIds,
                        totalMinutes: totalMinutes,
                        onPresetChanged: (preset) {
                          setState(() => _preset = preset);
                        },
                        onPickCustomDay: () => _pickCustomDay(context),
                        onPreviousDay: () => _shiftCustomDay(-1),
                        onNextDay: () => _shiftCustomDay(1),
                        onDimensionChanged: (value) {
                          setState(() => _dimension = value);
                        },
                        onCategoryFilterToggled: _toggleCategoryFilter,
                      );
                    },
                  )
                else
                  FutureBuilder<TimeRangeStats>(
                    future: _statsForRange(range),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return _StatsLoadingIndicator();
                      }
                      final stats = snapshot.data ?? _emptyStats;
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
                          const SectionGap(height: 12),
                          _StatsCharts(
                            state: state,
                            range: range,
                            stats: stats,
                            dimension: _dimension,
                            selectedCategoryIds: _selectedCategoryIds,
                            onDimensionChanged: (value) {
                              setState(() => _dimension = value);
                            },
                            onCategoryFilterToggled: _toggleCategoryFilter,
                            totalMinutes: totalMinutes,
                            showCompactFilters: _showCompactStatsFilters,
                            onCompactFiltersToggled: () {
                              setState(() {
                                _showCompactStatsFilters =
                                    !_showCompactStatsFilters;
                              });
                            },
                          ),
                        ],
                      );
                    },
                  ),
              ],
            );
          },
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
          label: AppLocalizations.of(context)!.today,
        ),
      StatsPreset.yesterday => StatsRange(
          start: today.subtract(const Duration(days: 1)),
          end: today,
          label: AppLocalizations.of(context)!.yesterday,
        ),
      StatsPreset.thisWeek =>
        _weekRange(today, AppLocalizations.of(context)!.thisWeek),
      StatsPreset.lastWeek => _weekRange(
          today.subtract(const Duration(days: 7)),
          AppLocalizations.of(context)!.lastWeek,
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

  void _toggleCategoryFilter(String categoryId) {
    setState(() {
      if (!_selectedCategoryIds.add(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      }
    });
  }

  Future<TimeRangeStats> _statsForRange(StatsRange range) {
    final cached = _statsFuture;
    final revision = widget.state.dataRevision;
    if (cached != null &&
        _statsRangeStart == range.start &&
        _statsRangeEnd == range.end &&
        _statsDataRevision == revision) {
      return cached;
    }
    _statsRangeStart = range.start;
    _statsRangeEnd = range.end;
    _statsDataRevision = revision;
    return _statsFuture = widget.state.statsForRange(
      start: range.start,
      end: range.end,
    );
  }

  Future<_StatsViewData> _mobileStatsForRange(StatsRange range) {
    final cached = _mobileStatsFuture;
    final revision = widget.state.dataRevision;
    if (cached != null &&
        _mobileStatsRangeStart == range.start &&
        _mobileStatsRangeEnd == range.end &&
        _mobileStatsDataRevision == revision) {
      return cached;
    }
    _mobileStatsRangeStart = range.start;
    _mobileStatsRangeEnd = range.end;
    _mobileStatsDataRevision = revision;
    return _mobileStatsFuture = _loadMobileStatsForRange(range);
  }

  Future<_StatsViewData> _loadMobileStatsForRange(StatsRange range) async {
    final previousDuration = range.end.difference(range.start);
    final previousEnd = range.start;
    final previousStart = previousEnd.subtract(previousDuration);
    final [current, previous] = await Future.wait([
      widget.state.statsForRange(start: range.start, end: range.end),
      widget.state.statsForRange(start: previousStart, end: previousEnd),
    ]);
    return _StatsViewData(current: current, previous: previous);
  }

  void _invalidateStatsFuture() {
    if (_statsDataRevision == widget.state.dataRevision) {
      return;
    }
    _clearStatsFuture();
  }

  void _clearStatsFuture() {
    _statsRangeStart = null;
    _statsRangeEnd = null;
    _statsDataRevision = null;
    _statsFuture = null;
    _mobileStatsRangeStart = null;
    _mobileStatsRangeEnd = null;
    _mobileStatsDataRevision = null;
    _mobileStatsFuture = null;
  }
}

class _MobileStatsHeader extends StatelessWidget {
  const _MobileStatsHeader({
    required this.selectedPreset,
    required this.onPresetChanged,
    required this.onPickCustomDay,
  });

  final StatsPreset selectedPreset;
  final ValueChanged<StatsPreset> onPresetChanged;
  final VoidCallback onPickCustomDay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            _mobileStatsTitle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        PopupMenuButton<StatsPreset>(
          tooltip: _mobileText(
            context,
            english: 'Select range',
            chinese: '选择范围',
          ),
          onSelected: (preset) {
            if (preset == StatsPreset.customDay) {
              onPickCustomDay();
              return;
            }
            onPresetChanged(preset);
          },
          itemBuilder: (context) {
            return [
              for (final preset in StatsPreset.values)
                PopupMenuItem(
                  value: preset,
                  child: Text(_mobilePresetLabel(context, preset)),
                ),
            ];
          },
          child: Material(
            color: colorScheme.surface,
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              key: const ValueKey('mobile-stats-range-menu'),
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _mobilePresetLabel(context, selectedPreset),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileStatsContent extends StatelessWidget {
  const _MobileStatsContent({
    required this.range,
    required this.selectedPreset,
    required this.stats,
    required this.previousStats,
    required this.totalMinutes,
  });

  final StatsRange range;
  final StatsPreset selectedPreset;
  final TimeRangeStats stats;
  final TimeRangeStats previousStats;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final rangeDays = _rangeDayCount(range);
    final averageMinutes = rangeDays == 0
        ? 0
        : (stats.totalDuration.inMinutes / rangeDays).round();
    final previousAverageMinutes = rangeDays == 0
        ? 0
        : (previousStats.totalDuration.inMinutes / rangeDays).round();
    final rows = stats.groupRows(dimension: StatsDimension.activity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MobileStatsMetricCard(
                key: const ValueKey('mobile-stats-total-time-card'),
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
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MobileStatsMetricCard(
                key: const ValueKey('mobile-stats-daily-avg-card'),
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
            ),
          ],
        ),
        const SizedBox(height: 28),
        _MobileDayBarsChart(
          range: range,
          dayTotals: stats.totalsByDay,
        ),
        const SizedBox(height: 30),
        _MobileActivityDonut(
          rows: rows,
          totalMinutes: totalMinutes,
        ),
      ],
    );
  }
}

class _MobileStatsMetricCard extends StatelessWidget {
  const _MobileStatsMetricCard({
    required this.label,
    required this.value,
    required this.delta,
    super.key,
  });

  final String label;
  final String value;
  final String delta;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 88,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              delta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xff16a34a),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDayBarsChart extends StatelessWidget {
  const _MobileDayBarsChart({
    required this.range,
    required this.dayTotals,
  });

  final StatsRange range;
  final Map<DateTime, Duration> dayTotals;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final days = _chartDaysForRange(range);
    final maxMinutes = days.fold<int>(
      60,
      (max, day) {
        final minutes = dayTotals[day.startOfDay]?.inMinutes ?? 0;
        return minutes > max ? minutes : max;
      },
    );
    final maxHours = (maxMinutes / 60).ceil();
    final midHours = (maxHours / 2).ceil();
    const chartHeight = 126.0;
    final barColors = [
      const Color(0xff14b8a6),
      const Color(0xff3b82f6),
      const Color(0xff06b6d4),
      const Color(0xff0891b2),
      const Color(0xff60a5fa),
      const Color(0xff93c5fd),
      const Color(0xff38bdf8),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _mobileText(
            context,
            english: 'Time by Day (h)',
            chinese: '每日时间 (小时)',
          ),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 162,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: chartHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _AxisLabel('$maxHours'),
                    _AxisLabel('$midHours'),
                    const _AxisLabel('0'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: chartHeight,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (var i = 0; i < 3; i += 1)
                                  Container(
                                    height: 1,
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.72),
                                  ),
                              ],
                            ),
                          ),
                          Positioned.fill(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                for (var i = 0; i < days.length; i += 1)
                                  _MobileDayBar(
                                    key: ValueKey('mobile-stats-day-bar-$i'),
                                    color: barColors[i % barColors.length],
                                    height: _barHeight(
                                      dayTotals[days[i].startOfDay] ??
                                          Duration.zero,
                                      maxMinutes,
                                      chartHeight,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (final day in days)
                          Expanded(
                            child: Text(
                              _weekdayLabel(context, day.weekday),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _barHeight(Duration duration, int maxMinutes, double chartHeight) {
    if (duration <= Duration.zero) {
      return 0;
    }
    final scaled = duration.inMinutes / maxMinutes * chartHeight;
    return scaled.clamp(8.0, chartHeight);
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _MobileDayBar extends StatelessWidget {
  const _MobileDayBar({
    required this.color,
    required this.height,
    super.key,
  });

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 16,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}

class _MobileActivityDonut extends StatelessWidget {
  const _MobileActivityDonut({
    required this.rows,
    required this.totalMinutes,
  });

  final List<StatsGroupRow> rows;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _mobileText(
            context,
            english: 'Time by Activity',
            chinese: '事项时间',
          ),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          SizedBox(
            height: 132,
            child: _StatsEmptyCanvas(
              icon: Icons.pie_chart_outline,
              title: AppLocalizations.of(context)!.noData,
              message: AppLocalizations.of(context)!.startRecordingHint,
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 124,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 34,
                    sections: [
                      for (final row in rows)
                        PieChartSectionData(
                          value: row.totalDuration.inMinutes
                              .clamp(1, 1 << 31)
                              .toDouble(),
                          title: '',
                          radius: 25,
                          color: Color(row.color),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    for (final row in rows)
                      _MobileActivityLegendRow(
                        key: ValueKey('mobile-stats-activity-row-${row.id}'),
                        color: Color(row.color),
                        label: row.label,
                        percent: _mobilePercent(row.totalDuration),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  int _mobilePercent(Duration duration) {
    return (duration.inMinutes / totalMinutes * 100).round();
  }
}

class _MobileActivityLegendRow extends StatelessWidget {
  const _MobileActivityLegendRow({
    required this.color,
    required this.label,
    required this.percent,
    super.key,
  });

  final Color color;
  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$percent%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final header = PageHeader(
          title: AppLocalizations.of(context)!.stats,
          subtitle: AppLocalizations.of(context)!.statsSubtitle(range.label),
          trailing: compact
              ? null
              : StatusPill(
                  label: range.label,
                  icon: Icons.insights_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
        );
        final controls = _StatsPresetControl(
          selectedPreset: selectedPreset,
          compact: compact,
          onPresetChanged: onPresetChanged,
        );
        final dayStepper = DayRangeSelector(
          selectedDay: range.start,
          rangeEnd: _displayRangeEnd(range),
          onPreviousDay: onPreviousDay,
          onDateTap: onPickCustomDay,
          onNextDay: onNextDay,
          dense: compact,
          shortDateLabel: compact,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(flex: 4, child: controls),
                  const SizedBox(width: 8),
                  Expanded(flex: 6, child: dayStepper),
                ],
              ),
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

  DateTime _displayRangeEnd(StatsRange range) {
    final endDay = range.end.startOfDay;
    if (range.end == endDay && range.end.isAfter(range.start)) {
      return endDay.subtract(const Duration(days: 1));
    }
    return endDay;
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
        isExpanded: true,
        isDense: true,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        items: [
          for (final preset in StatsPreset.values)
            DropdownMenuItem(
              value: preset,
              child: Text(_presetLabel(context, preset)),
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
            label: Text(_presetLabel(context, preset)),
          ),
      ],
      selected: {selectedPreset},
      onSelectionChanged: (value) => onPresetChanged(value.first),
    );
  }

  String _presetLabel(BuildContext context, StatsPreset preset) {
    final l10n = AppLocalizations.of(context)!;
    return switch (preset) {
      StatsPreset.today => l10n.today,
      StatsPreset.yesterday => l10n.yesterday,
      StatsPreset.thisWeek => l10n.thisWeek,
      StatsPreset.lastWeek => l10n.lastWeek,
      StatsPreset.customDay => l10n.customDay,
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
            icon: Icons.timer_outlined,
            label: AppLocalizations.of(context)!.totalRangeRecords,
            value: formatDurationForDisplay(context, totalDuration),
            color: Theme.of(context).colorScheme.primary,
          ),
          _MetricCard(
            icon: Icons.auto_graph_outlined,
            label: AppLocalizations.of(context)!.longestStreak,
            value: formatDurationForDisplay(context, longestBlock),
            color: Theme.of(context).colorScheme.secondary,
          ),
        ];
        if (compact) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 8),
              Expanded(child: cards[1]),
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
    required this.dimension,
    required this.selectedCategoryIds,
    required this.onDimensionChanged,
    required this.onCategoryFilterToggled,
    required this.totalMinutes,
    required this.showCompactFilters,
    required this.onCompactFiltersToggled,
  });

  final AppState state;
  final StatsRange range;
  final TimeRangeStats stats;
  final StatsDimension dimension;
  final Set<String> selectedCategoryIds;
  final ValueChanged<StatsDimension> onDimensionChanged;
  final ValueChanged<String> onCategoryFilterToggled;
  final int totalMinutes;
  final bool showCompactFilters;
  final VoidCallback onCompactFiltersToggled;

  @override
  Widget build(BuildContext context) {
    final rows = stats.groupRows(
      dimension: dimension,
      selectedCategoryIds: selectedCategoryIds,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final expanded = constraints.maxWidth >= expandedBreakpoint;
        final controls = _StatsControls(
          state: state,
          dimension: dimension,
          selectedCategoryIds: selectedCategoryIds,
          onDimensionChanged: onDimensionChanged,
          onCategoryFilterToggled: onCategoryFilterToggled,
        );
        final distributionCard = RangeDistributionCard(
          state: state,
          title:
              AppLocalizations.of(context)!.distributionChartTitle(range.label),
          rows: rows,
          totalMinutes: totalMinutes,
        );
        final dayTotalsCard = DayTotalsCard(dayTotals: stats.totalsByDay);
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              distributionCard,
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onCompactFiltersToggled,
                  icon: Icon(
                    showCompactFilters ? Icons.expand_less : Icons.filter_list,
                  ),
                  label: Text(AppLocalizations.of(context)!.filters),
                ),
              ),
              if (showCompactFilters) ...[
                const SizedBox(height: 10),
                controls,
              ],
              const SectionGap(height: 12),
              dayTotalsCard,
            ],
          );
        }
        if (!expanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              distributionCard,
              const SectionGap(height: 12),
              controls,
              const SectionGap(height: 12),
              dayTotalsCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  distributionCard,
                  const SectionGap(height: 12),
                  controls,
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: dayTotalsCard),
          ],
        );
      },
    );
  }
}

class _StatsControls extends StatelessWidget {
  const _StatsControls({
    required this.state,
    required this.dimension,
    required this.selectedCategoryIds,
    required this.onDimensionChanged,
    required this.onCategoryFilterToggled,
  });

  final AppState state;
  final StatsDimension dimension;
  final Set<String> selectedCategoryIds;
  final ValueChanged<StatsDimension> onDimensionChanged;
  final ValueChanged<String> onCategoryFilterToggled;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < compactBreakpoint;
    final l10n = AppLocalizations.of(context)!;
    final dimensions = compact
        ? DropdownButtonFormField<StatsDimension>(
            initialValue: dimension,
            decoration: InputDecoration(
              labelText: l10n.statsDimension,
              prefixIcon: const Icon(Icons.query_stats),
            ),
            items: [
              for (final value in StatsDimension.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(_dimensionLabel(context, value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) onDimensionChanged(value);
            },
          )
        : SegmentedButton<StatsDimension>(
            segments: [
              for (final value in StatsDimension.values)
                ButtonSegment(
                  value: value,
                  label: Text(_dimensionLabel(context, value)),
                ),
            ],
            selected: {dimension},
            onSelectionChanged: (value) => onDimensionChanged(value.first),
          );
    return QuietPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.statsDimension,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          dimensions,
          if (state.activityCategories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in state.activityCategories)
                  FilterChip(
                    label: Text(category.name),
                    selected: selectedCategoryIds.contains(category.id),
                    avatar: CircleAvatar(
                      radius: 6,
                      backgroundColor: Color(category.color),
                    ),
                    onSelected: (_) => onCategoryFilterToggled(category.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _dimensionLabel(BuildContext context, StatsDimension value) {
    final l10n = AppLocalizations.of(context)!;
    return switch (value) {
      StatsDimension.activity => l10n.activityDimension,
      StatsDimension.primaryCategory => l10n.primaryCategoryDimension,
      StatsDimension.durationBucket => l10n.durationBucketDimension,
      StatsDimension.primaryCategoryAndDurationBucket =>
        l10n.categoryDurationDimension,
    };
  }
}

class RangeDistributionCard extends StatelessWidget {
  const RangeDistributionCard({
    required this.state,
    required this.title,
    required this.rows,
    required this.totalMinutes,
    super.key,
  });

  final AppState state;
  final String title;
  final List<StatsGroupRow> rows;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    return QuietPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: title,
            subtitle: rows.isEmpty
                ? AppLocalizations.of(context)!.noDataToVisualize
                : AppLocalizations.of(context)!.activityColorLegend,
            icon: Icons.pie_chart_outline,
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(height: constraints.maxWidth < 520 ? 10 : 20);
            },
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final chartExtent = compact ? 104.0 : 144.0;
              final chart = SizedBox(
                height: rows.isEmpty
                    ? (compact ? 132 : 176)
                    : (compact ? 108 : 152),
                child: rows.isEmpty
                    ? _StatsEmptyCanvas(
                        icon: Icons.pie_chart_outline,
                        title: AppLocalizations.of(context)!.noData,
                        message:
                            AppLocalizations.of(context)!.startRecordingHint,
                      )
                    : Center(
                        child: SizedBox.square(
                          dimension: chartExtent,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: compact ? 20 : 30,
                              sections: [
                                for (final row in rows)
                                  PieChartSectionData(
                                    value: row.totalDuration.inMinutes
                                        .clamp(1, 1 << 31)
                                        .toDouble(),
                                    title: '',
                                    radius: compact ? 32 : 42,
                                    color: Color(row.color),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
              );
              final legend = Column(
                children: [
                  for (final item in rows)
                    _LegendRow(
                      color: Color(item.color),
                      label: item.label,
                      value:
                          '${formatDurationForDisplay(context, item.totalDuration)}'
                          ' · ${item.count}${AppLocalizations.of(context)!.statsCountTimes}',
                    ),
                ],
              );
              if (compact) {
                if (rows.isEmpty) {
                  return chart;
                }
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(width: 118, child: chart),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            children: [
                              for (final item in rows)
                                _CompactLegendRow(
                                  color: Color(item.color),
                                  label: item.label,
                                  value: '${_formatDurationTerse(
                                    context,
                                    item.totalDuration,
                                  )} · ${item.count}${AppLocalizations.of(context)!.statsCountTimes}',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

  // State is retained for constructor compatibility in widget tests and future
  // drill-down actions.
}

class DayTotalsCard extends StatelessWidget {
  const DayTotalsCard({required this.dayTotals, super.key});

  final Map<DateTime, Duration> dayTotals;

  @override
  Widget build(BuildContext context) {
    return QuietPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: AppLocalizations.of(context)!.dailyTotal,
            subtitle: AppLocalizations.of(context)!.dailyTotalHint,
            icon: Icons.calendar_view_week_outlined,
          ),
          const SizedBox(height: 12),
          if (dayTotals.isEmpty)
            _StatsEmptyCanvas(
              icon: Icons.event_busy_outlined,
              title: AppLocalizations.of(context)!.noData,
              message: AppLocalizations.of(context)!.recordHint,
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
                trailing: Text(formatDurationForDisplay(context, item.value)),
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
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = constraints.maxWidth < 220;
        return QuietPanel(
          padding: EdgeInsets.all(dense ? 9 : 14),
          child: dense
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBadge(icon: icon, color: color, size: 30),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              label,
                              maxLines: 1,
                              softWrap: false,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        softWrap: false,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    IconBadge(icon: icon, color: color, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _StatsEmptyCanvas extends StatelessWidget {
  const _StatsEmptyCanvas({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 140;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(tight ? 10 : 14),
              child: tight
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconBadge(
                          icon: icon,
                          color: colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconBadge(
                          icon: icon,
                          color: colorScheme.primary,
                          size: 34,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
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
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

String _mobileStatsTitle(BuildContext context) {
  return _mobileText(context, english: 'Statistics', chinese: '统计');
}

String _mobileText(
  BuildContext context, {
  required String english,
  required String chinese,
}) {
  return Localizations.localeOf(context).languageCode == 'zh'
      ? chinese
      : english;
}

String _mobilePresetLabel(BuildContext context, StatsPreset preset) {
  final l10n = AppLocalizations.of(context)!;
  final english = Localizations.localeOf(context).languageCode != 'zh';
  return switch (preset) {
    StatsPreset.today => l10n.today,
    StatsPreset.yesterday => l10n.yesterday,
    StatsPreset.thisWeek => english ? 'This Week' : l10n.thisWeek,
    StatsPreset.lastWeek => english ? 'Last Week' : l10n.lastWeek,
    StatsPreset.customDay => english ? 'Custom Day' : l10n.customDay,
  };
}

String _formatMobileDuration(
  BuildContext context,
  Duration duration, {
  required bool padMinutes,
}) {
  final minutesTotal = duration.inMinutes;
  final hours = minutesTotal ~/ 60;
  final minutes = minutesTotal % 60;
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  if (zh) {
    if (hours == 0) {
      return '$minutes分';
    }
    return '$hours小时${padMinutes ? minutes.toString().padLeft(2, '0') : minutes}分';
  }
  if (hours == 0) {
    return '${minutes}m';
  }
  final minuteLabel = padMinutes ? minutes.toString().padLeft(2, '0') : minutes;
  return '${hours}h ${minuteLabel}m';
}

String _formatMobileDelta(
  BuildContext context, {
  required int currentMinutes,
  required int previousMinutes,
  required StatsPreset preset,
}) {
  if (currentMinutes <= 0 && previousMinutes <= 0) {
    return _mobileText(context, english: '+0%', chinese: '+0%');
  }
  if (previousMinutes <= 0) {
    return _mobileText(
      context,
      english: '+100% ${_mobileComparisonLabel(context, preset)}',
      chinese: '+100%${_mobileComparisonLabel(context, preset)}',
    );
  }
  final delta =
      ((currentMinutes - previousMinutes) / previousMinutes * 100).round();
  final sign = delta >= 0 ? '+' : '';
  final comparison = _mobileComparisonLabel(context, preset);
  return _mobileText(
    context,
    english: '$sign$delta% $comparison',
    chinese: '$sign$delta%$comparison',
  );
}

String _mobileComparisonLabel(BuildContext context, StatsPreset preset) {
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  return switch (preset) {
    StatsPreset.today ||
    StatsPreset.yesterday ||
    StatsPreset.customDay =>
      zh ? '较前日' : 'vs previous day',
    StatsPreset.thisWeek => zh ? '较上周' : 'vs last week',
    StatsPreset.lastWeek => zh ? '较前一周' : 'vs previous week',
  };
}

int _rangeDayCount(StatsRange range) {
  final days = range.end.startOfDay.difference(range.start.startOfDay).inDays;
  return days <= 0 ? 1 : days;
}

List<DateTime> _chartDaysForRange(StatsRange range) {
  final days = _rangeDayCount(range).clamp(1, 7);
  return [
    for (var i = 0; i < days; i += 1)
      range.start.startOfDay.add(Duration(days: i)),
  ];
}

String _weekdayLabel(BuildContext context, int weekday) {
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  final labels = zh
      ? const ['一', '二', '三', '四', '五', '六', '日']
      : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[(weekday - 1).clamp(0, 6)];
}

String _formatDurationTerse(BuildContext context, Duration duration) {
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

class _CompactLegendRow extends StatelessWidget {
  const _CompactLegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
