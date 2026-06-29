import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_state.dart';
import '../core/date_time_ext.dart';
import '../l10n/app_localizations.dart';
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
  StatsDimension _dimension = StatsDimension.activity;
  final Set<String> _selectedCategoryIds = {};
  bool _showCompactStatsFilters = false;
  DateTime? _statsRangeStart;
  DateTime? _statsRangeEnd;
  int? _statsDataRevision;
  Future<TimeRangeStats>? _statsFuture;

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
              future: _statsForRange(range),
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
                          _showCompactStatsFilters = !_showCompactStatsFilters;
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
      title: AppLocalizations.of(context)!.stats,
      subtitle: AppLocalizations.of(context)!.statsSubtitle(range.label),
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
        final dayStepper = DayRangeSelector(
          selectedDay: range.start,
          rangeEnd: _displayRangeEnd(range),
          onPreviousDay: onPreviousDay,
          onDateTap: onPickCustomDay,
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
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.range,
          prefixIcon: const Icon(Icons.date_range),
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
            label: AppLocalizations.of(context)!.totalRangeRecords,
            value: formatDurationCompact(totalDuration),
          ),
          _MetricCard(
            label: AppLocalizations.of(context)!.longestStreak,
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
              const SectionGap(),
              dayTotalsCard,
            ],
          );
        }
        if (!expanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              controls,
              const SectionGap(),
              distributionCard,
              const SectionGap(),
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
                  controls,
                  const SectionGap(),
                  distributionCard,
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
      padding: const EdgeInsets.all(16),
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
      padding: const EdgeInsets.all(18),
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
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final chart = SizedBox(
                height: compact ? 220 : 260,
                child: rows.isEmpty
                    ? EmptyState(
                        icon: Icons.pie_chart_outline,
                        title: AppLocalizations.of(context)!.noData,
                        message:
                            AppLocalizations.of(context)!.startRecordingHint,
                      )
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: compact ? 44 : 54,
                          sections: [
                            for (final row in rows)
                              PieChartSectionData(
                                value: row.totalDuration.inMinutes
                                    .clamp(1, 1 << 31)
                                    .toDouble(),
                                title:
                                    '${(row.totalDuration.inMinutes / totalMinutes * 100).round()}%',
                                radius: compact ? 74 : 88,
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                                color: Color(row.color),
                              ),
                          ],
                        ),
                      ),
              );
              final legend = Column(
                children: [
                  for (final item in rows)
                    _LegendRow(
                      color: Color(item.color),
                      label: item.label,
                      value: '${formatDurationCompact(item.totalDuration)}'
                          ' · ${item.count}次',
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

  // State is retained for constructor compatibility in widget tests and future
  // drill-down actions.
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
          SectionTitle(
            title: AppLocalizations.of(context)!.dailyTotal,
            subtitle: AppLocalizations.of(context)!.dailyTotalHint,
            icon: Icons.calendar_view_week_outlined,
          ),
          const SizedBox(height: 12),
          if (dayTotals.isEmpty)
            EmptyState(
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
