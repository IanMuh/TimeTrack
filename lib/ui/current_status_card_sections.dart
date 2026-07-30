import 'package:flutter/material.dart';

import '../domain/activity.dart';
import '../l10n/app_localizations.dart';
import 'current_status_card_helpers.dart';

class CurrentStatusTimerRing extends StatelessWidget {
  const CurrentStatusTimerRing({
    required this.compact,
    required this.duration,
    required this.activityName,
    required this.runningColor,
    super.key,
  });

  final bool compact;
  final Duration duration;
  final String activityName;
  final Color runningColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: compact ? 112 : 132,
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.48,
                    end: 0.82,
                  ),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  builder: (context, value, _) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: compact ? 5.5 : 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: colorScheme.outlineVariant.withValues(
                        alpha: 0.75,
                      ),
                      valueColor: AlwaysStoppedAnimation(runningColor),
                    );
                  },
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatTimerText(duration),
                      style: (compact
                              ? Theme.of(context).textTheme.headlineSmall
                              : Theme.of(context).textTheme.displayMedium)
                          ?.copyWith(
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activityName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
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

class CurrentStatusActions extends StatelessWidget {
  const CurrentStatusActions({
    required this.runningActivity,
    required this.onStop,
    required this.onSwitch,
    this.compact = false,
    super.key,
  });

  final Activity? runningActivity;
  final VoidCallback? onStop;
  final VoidCallback? onSwitch;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: compact ? 10 : 12,
      vertical: compact ? 7 : 12,
    );
    if (runningActivity != null) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                padding: buttonPadding,
                minimumSize: Size(44, compact ? 40 : 44),
              ),
              onPressed: onStop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(l10n.stopCurrentActivity),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: buttonPadding,
                minimumSize: Size(44, compact ? 40 : 44),
              ),
              onPressed: onSwitch,
              icon: const Icon(Icons.sync_alt),
              label: Text(l10n.switchActivity),
            ),
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: buttonPadding,
          minimumSize: Size(44, compact ? 40 : 40),
        ),
        onPressed: onSwitch,
        icon: const Icon(Icons.sync_alt),
        label: Text(l10n.switchActivity),
      ),
    );
  }
}
