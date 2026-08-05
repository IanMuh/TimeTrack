import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_state.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'current_status_card_helpers.dart';
import 'today_activity_list.dart';
import 'today_desktop_page.dart';
import 'today_metric_card.dart';
import 'today_summary.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    required this.state,
    this.onOpenTimeline,
    super.key,
  });

  final AppState state;
  final VoidCallback? onOpenTimeline;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= expandedBreakpoint;
        return AnimatedBuilder(
          animation: state,
          builder: (context, _) {
            return ValueListenableBuilder<DateTime>(
              valueListenable: state.clockNotifier,
              builder: (context, now, _) {
                final summary = TodaySummary.fromState(state, now);
                final metrics = _metrics(context, summary);
                return AdaptivePage(
                  pageKey: const PageStorageKey('today-page'),
                  maxWidth: desktop ? 1040 : 430,
                  onRefresh: state.refresh,
                  children: desktop
                      ? [
                          DesktopTodayPage(
                            state: state,
                            summary: summary,
                            metrics: metrics,
                            now: now,
                            onSelectDate: () => _selectDate(context),
                            onOpenTimeline: onOpenTimeline,
                          ),
                        ]
                      : [
                          _TodayHeader(
                            selectedDay: state.selectedDay,
                            onSelectDate: () => _selectDate(context),
                          ),
                          const SizedBox(height: 20),
                          TodayMetricGrid(metrics: metrics),
                          const SizedBox(height: 22),
                          TodayActivityList(
                            activities: summary.activities,
                          ),
                        ],
                );
              },
            );
          },
        );
      },
    );
  }

  List<TodayMetricData> _metrics(
    BuildContext context,
    TodaySummary summary,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return [
      TodayMetricData(
        label: l10n.todayTotalTime,
        value: formatSummaryDuration(summary.totalDuration),
        supportingText: l10n.todayVsYesterday(12),
        positive: summary.totalDuration > Duration.zero,
      ),
      TodayMetricData(
        label: l10n.sessions,
        value: summary.sessionCount.toString(),
        supportingText: l10n.todaySessionsVsYesterday(1),
        positive: summary.sessionCount > 0,
      ),
      TodayMetricData(
        label: l10n.todayFocusTime,
        value: formatSummaryDuration(summary.focusDuration),
        supportingText: l10n.todayPercentOfTotal(
          _percent(summary.focusDuration, summary.totalDuration),
        ),
      ),
      TodayMetricData(
        label: l10n.todayBreakTime,
        value: formatSummaryDuration(summary.breakDuration),
        supportingText: l10n.todayPercentOfTotal(
          _percent(summary.breakDuration, summary.totalDuration),
        ),
      ),
    ];
  }

  int _percent(Duration value, Duration total) {
    if (total == Duration.zero) {
      return 0;
    }
    return (value.inSeconds / total.inSeconds * 100).round();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDay,
      firstDate: DateTime(2000),
      lastDate: DateTime(state.now.year + 5, 12, 31),
    );
    if (picked == null) {
      return;
    }
    await state.selectDay(picked);
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.navToday,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            IconButton(
              tooltip: l10n.selectDate,
              onPressed: onSelectDate,
              icon: const Icon(Icons.calendar_today_outlined),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 12),
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
    );
  }
}
