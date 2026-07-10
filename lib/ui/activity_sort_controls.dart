import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'sort_controls.dart';

enum ActivitySortMetric { name, color, primaryCategory, updatedAt }

class ActivitySortControls extends StatelessWidget {
  const ActivitySortControls({
    required this.metric,
    required this.order,
    required this.onMetricChanged,
    required this.onOrderChanged,
    super.key,
  });

  final ActivitySortMetric metric;
  final SortOrder order;
  final ValueChanged<ActivitySortMetric> onMetricChanged;
  final ValueChanged<SortOrder> onOrderChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: compact ? double.infinity : 180,
              child: DropdownButtonFormField<ActivitySortMetric>(
                initialValue: metric,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.sortBy,
                  prefixIcon: const Icon(Icons.sort),
                ),
                items: [
                  for (final value in ActivitySortMetric.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_activitySortMetricLabel(context, value)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onMetricChanged(value);
                },
              ),
            ),
            SortOrderSegmentedButton(
              value: order,
              onChanged: onOrderChanged,
            ),
          ],
        );
      },
    );
  }

  String _activitySortMetricLabel(
      BuildContext context, ActivitySortMetric value) {
    final l10n = AppLocalizations.of(context)!;
    return switch (value) {
      ActivitySortMetric.name => l10n.name,
      ActivitySortMetric.color => l10n.color,
      ActivitySortMetric.primaryCategory => l10n.primaryCategoryDimension,
      ActivitySortMetric.updatedAt => l10n.recentlyUpdated,
    };
  }
}
