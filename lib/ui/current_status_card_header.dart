import 'package:flutter/material.dart';

import '../domain/activity.dart';
import '../l10n/app_localizations.dart';
import 'ui_components.dart';

class CurrentStatusHeader extends StatelessWidget {
  const CurrentStatusHeader({
    required this.runningActivity,
    required this.runningColor,
    super.key,
  });

  final Activity? runningActivity;
  final Color runningColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          runningActivity == null
              ? Icons.timer_outlined
              : Icons.radio_button_checked,
          color: runningColor,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.currentDoing,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        StatusPill(
          label:
              runningActivity == null ? l10n.notStartedRecord : l10n.recording,
          icon: runningActivity == null
              ? Icons.pause_circle_outline
              : Icons.radio_button_checked,
          color: runningColor,
        ),
      ],
    );
  }
}
