import 'package:flutter/material.dart';

import '../domain/activity.dart';
import '../domain/time_entry.dart';
import '../l10n/app_localizations.dart';
import 'current_status_card_helpers.dart';
import 'timer_progress_ring.dart';

class TimerSessionCard extends StatelessWidget {
  const TimerSessionCard({
    required this.runningActivity,
    required this.clockNotifier,
    required this.runningDurationAt,
    required this.entries,
    required this.onStop,
    required this.onSwitch,
    super.key,
  });

  final Activity? runningActivity;
  final ValueNotifier<DateTime> clockNotifier;
  final Duration Function(DateTime at) runningDurationAt;
  final List<TimeEntry> entries;
  final VoidCallback? onStop;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: clockNotifier,
      builder: (context, now, _) {
        final duration =
            runningActivity == null ? Duration.zero : runningDurationAt(now);
        final activityName = runningActivity?.name ??
            AppLocalizations.of(context)!.notStartedRecord;
        final runningColor = runningActivity == null
            ? Theme.of(context).colorScheme.secondary
            : _effectiveActivityColor(
                Color(runningActivity!.color),
                Theme.of(context).colorScheme.brightness,
              );
        final todayDuration = entries.fold<Duration>(
          Duration.zero,
          (total, entry) => total + entry.durationUntil(now),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TimerProgressRing(
              duration: duration,
              activityName: activityName,
              runningColor: runningColor,
            ),
            const SizedBox(height: 18),
            _TimerActions(
              isRunning: runningActivity != null,
              onStop: onStop,
              onSwitch: onSwitch,
            ),
            const SizedBox(height: 14),
            _TimerMetrics(
              todayDuration: todayDuration,
              sessions: entries.length,
            ),
          ],
        );
      },
    );
  }

  Color _effectiveActivityColor(Color color, Brightness brightness) {
    if (brightness == Brightness.light) {
      return color;
    }
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + 0.16).clamp(0.0, 1.0)).toColor();
  }
}

class _TimerActions extends StatelessWidget {
  const _TimerActions({
    required this.isRunning,
    required this.onStop,
    required this.onSwitch,
  });

  final bool isRunning;
  final VoidCallback? onStop;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final dark = colorScheme.brightness == Brightness.dark;
    final stopBackground = dark ? const Color(0xffef4444) : colorScheme.error;
    final stopForeground = dark ? Colors.white : colorScheme.onError;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w800,
        );
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: stopBackground,
              foregroundColor: stopForeground,
            ),
            onPressed: isRunning ? onStop : null,
            child: Text(
              l10n.stop,
              style: labelStyle?.copyWith(color: stopForeground),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onSwitch,
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: Text(
              l10n.switchActivity,
              style: labelStyle?.copyWith(color: colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerMetrics extends StatelessWidget {
  const _TimerMetrics({
    required this.todayDuration,
    required this.sessions,
  });

  final Duration todayDuration;
  final int sessions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
    final valueStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        );
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '${AppLocalizations.of(context)!.today}: ',
              style: labelStyle,
              children: [
                TextSpan(
                  text: formatSummaryDuration(todayDuration),
                  style: valueStyle,
                ),
              ],
            ),
          ),
        ),
        Text.rich(
          TextSpan(
            text: '${AppLocalizations.of(context)!.sessions}: ',
            style: labelStyle,
            children: [
              TextSpan(text: '$sessions', style: valueStyle),
            ],
          ),
        ),
      ],
    );
  }
}
