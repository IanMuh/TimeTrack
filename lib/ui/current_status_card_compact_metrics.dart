import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'current_status_card_helpers.dart';

class CurrentStatusCompactMetrics extends StatelessWidget {
  const CurrentStatusCompactMetrics({
    required this.todayDuration,
    required this.sessions,
    super.key,
  });

  final Duration todayDuration;
  final int sessions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _CompactMetric(
            label: l10n.today,
            value: formatSummaryDuration(todayDuration),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CompactMetric(
            label: l10n.sessions,
            value: '$sessions',
          ),
        ),
      ],
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
