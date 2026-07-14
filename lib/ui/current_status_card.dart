import 'package:flutter/material.dart';

import '../core/date_time_ext.dart';
import '../domain/activity.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'ui_components.dart';

class CurrentStatusCard extends StatelessWidget {
  const CurrentStatusCard({
    required this.runningActivity,
    required this.clockNotifier,
    required this.runningDurationAt,
    required this.onStop,
    super.key,
  });

  final Activity? runningActivity;
  final ValueNotifier<DateTime> clockNotifier;
  final Duration Function(DateTime at) runningDurationAt;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final runningColor = runningActivity == null
        ? colorScheme.primary
        : Color(runningActivity!.color);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        return QuietPanel(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(
                      icon: runningActivity == null
                          ? Icons.timer_outlined
                          : Icons.play_arrow_rounded,
                      color: runningColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.currentDoing,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    StatusPill(
                      label: runningActivity == null
                          ? AppLocalizations.of(context)!.notStarted
                          : AppLocalizations.of(context)!.recording,
                      icon: runningActivity == null
                          ? Icons.pause_circle_outline
                          : Icons.radio_button_checked,
                      color: runningColor,
                    ),
                  ],
                ),
                SizedBox(height: compact ? 8 : 12),
                Text(
                  runningActivity?.name ??
                      AppLocalizations.of(context)!.notStartedRecord,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: (compact
                          ? Theme.of(context).textTheme.headlineSmall
                          : Theme.of(context).textTheme.displaySmall)
                      ?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: compact ? 4 : 8),
                if (runningActivity == null)
                  Text(
                    AppLocalizations.of(context)!.selectActivityToStart,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  )
                else
                  ValueListenableBuilder<DateTime>(
                    valueListenable: clockNotifier,
                    builder: (context, now, _) {
                      final duration = runningDurationAt(now);
                      return Text(
                        AppLocalizations.of(context)!
                            .elapsedDuration(formatDurationCompact(duration)),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                      );
                    },
                  ),
                if (runningActivity != null) ...[
                  SizedBox(height: compact ? 12 : 18),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    onPressed: onStop,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label:
                        Text(AppLocalizations.of(context)!.stopCurrentActivity),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
