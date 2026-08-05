import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'current_status_card_helpers.dart';
import 'today_summary.dart';

class TodayActivityList extends StatelessWidget {
  const TodayActivityList({
    required this.activities,
    super.key,
  });

  final List<TodayActivityTotal> activities;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.todayTopActivities,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        if (activities.isEmpty)
          _EmptyActivityList(colorScheme: colorScheme, message: l10n.noData)
        else
          for (final activity in activities) _ActivityRow(activity: activity),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final TodayActivityTotal activity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.circle, size: 9, color: Color(activity.color)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              activity.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatSummaryDuration(activity.duration),
            style: textStyle?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 34,
            child: Text(
              '${activity.percent}%',
              textAlign: TextAlign.right,
              style: textStyle?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivityList extends StatelessWidget {
  const _EmptyActivityList({
    required this.colorScheme,
    required this.message,
  });

  final ColorScheme colorScheme;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
