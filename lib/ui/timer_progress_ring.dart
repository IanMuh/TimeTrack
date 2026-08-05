import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'current_status_card_helpers.dart';

class TimerProgressRing extends StatelessWidget {
  const TimerProgressRing({
    required this.duration,
    required this.activityName,
    required this.runningColor,
    super.key,
  });

  final Duration duration;
  final String activityName;
  final Color runningColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: 236,
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: 0.82,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  backgroundColor:
                      colorScheme.secondary.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation(runningColor),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatTimerText(duration),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.currentSession,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: runningColor, size: 10),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          activityName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
