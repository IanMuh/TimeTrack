import 'package:flutter/material.dart';

class TodayMetricData {
  const TodayMetricData({
    required this.label,
    required this.value,
    required this.supportingText,
    this.positive = false,
  });

  final String label;
  final String value;
  final String supportingText;
  final bool positive;
}

class TodayMetricGrid extends StatelessWidget {
  const TodayMetricGrid({required this.metrics, super.key});

  final List<TodayMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.42,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        for (final metric in metrics) TodayMetricCard(metric: metric),
      ],
    );
  }
}

class TodayMetricCard extends StatelessWidget {
  const TodayMetricCard({required this.metric, super.key});

  final TodayMetricData metric;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = colorScheme.brightness == Brightness.dark;
    final cardColor = dark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.52)
        : colorScheme.surface;
    final borderColor = dark
        ? colorScheme.outline.withValues(alpha: 0.84)
        : colorScheme.outlineVariant;
    final supportingColor = metric.positive
        ? dark
            ? const Color(0xff22c55e)
            : const Color(0xff16a34a)
        : colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: dark ? 0.12 : 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              metric.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              metric.supportingText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: supportingColor,
                    fontWeight:
                        metric.positive ? FontWeight.w700 : FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
