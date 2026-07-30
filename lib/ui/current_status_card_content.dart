import 'package:flutter/material.dart';

import '../domain/activity.dart';
import '../domain/time_entry.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'current_status_card_compact_metrics.dart';
import 'current_status_card_header.dart';
import 'current_status_card_helpers.dart';
import 'current_status_card_sections.dart';
import 'ui_components.dart';

class CurrentStatusCardContent extends StatelessWidget {
  const CurrentStatusCardContent({
    required this.runningActivity,
    required this.clockNotifier,
    required this.runningDurationAt,
    required this.onStop,
    this.onSwitch,
    this.entries = const [],
    super.key,
  });

  final Activity? runningActivity;
  final ValueNotifier<DateTime> clockNotifier;
  final Duration Function(DateTime at) runningDurationAt;
  final VoidCallback? onStop;
  final VoidCallback? onSwitch;
  final List<TimeEntry> entries;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final runningColor = runningActivity == null
        ? colorScheme.secondary
        : _effectiveActivityColor(Color(runningActivity!.color));

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        return QuietPanel(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 14),
            child: ValueListenableBuilder<DateTime>(
              valueListenable: clockNotifier,
              builder: (context, now, _) {
                final duration = runningActivity == null
                    ? Duration.zero
                    : runningDurationAt(now);
                final todayDuration = _dayDuration(now);
                final sessions = entries.length;
                final activityName = runningActivity?.name ??
                    AppLocalizations.of(context)!.notStartedRecord;
                final statusBody = compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CurrentStatusTimerRing(
                            compact: true,
                            duration: duration,
                            activityName: activityName,
                            runningColor: runningColor,
                          ),
                          const SizedBox(height: 4),
                          CurrentStatusActions(
                            runningActivity: runningActivity,
                            onStop: onStop,
                            onSwitch: onSwitch,
                            compact: true,
                          ),
                          const SizedBox(height: 4),
                          CurrentStatusCompactMetrics(
                            todayDuration: todayDuration,
                            sessions: sessions,
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: CurrentStatusTimerRing(
                              compact: false,
                              duration: duration,
                              activityName: activityName,
                              runningColor: runningColor,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CurrentStatusActions(
                                  runningActivity: runningActivity,
                                  onStop: onStop,
                                  onSwitch: onSwitch,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SummaryTile(
                                        label:
                                            AppLocalizations.of(context)!.today,
                                        value: formatSummaryDuration(
                                          todayDuration,
                                        ),
                                        icon: Icons.today_outlined,
                                        dense: true,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: SummaryTile(
                                        label: AppLocalizations.of(context)!
                                            .sessions,
                                        value: '$sessions',
                                        icon: Icons.view_list_outlined,
                                        dense: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CurrentStatusHeader(
                      runningActivity: runningActivity,
                      runningColor: runningColor,
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    statusBody,
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Duration _dayDuration(DateTime now) {
    return entries.fold<Duration>(
      Duration.zero,
      (total, entry) => total + entry.durationUntil(now),
    );
  }

  Color _effectiveActivityColor(Color color) {
    if (ThemeData.estimateBrightnessForColor(color) == Brightness.light) {
      return color;
    }
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + 0.16).clamp(0.0, 1.0)).toColor();
  }
}
