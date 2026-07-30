import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

enum SortOrder { ascending, descending }

class SortOrderSegmentedButton extends StatelessWidget {
  const SortOrderSegmentedButton({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final SortOrder value;
  final ValueChanged<SortOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SegmentedButton<SortOrder>(
      segments: [
        ButtonSegment(
          value: SortOrder.ascending,
          icon: const Icon(Icons.north),
          label: Text(l10n.sortAscending),
        ),
        ButtonSegment(
          value: SortOrder.descending,
          icon: const Icon(Icons.south),
          label: Text(l10n.sortDescending),
        ),
      ],
      selected: {value},
      onSelectionChanged: (value) => onChanged(value.first),
    );
  }
}
