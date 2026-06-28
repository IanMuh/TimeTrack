import 'package:flutter/material.dart';

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
    return SegmentedButton<SortOrder>(
      segments: const [
        ButtonSegment(
          value: SortOrder.ascending,
          icon: Icon(Icons.north),
          label: Text('顺序'),
        ),
        ButtonSegment(
          value: SortOrder.descending,
          icon: Icon(Icons.south),
          label: Text('倒序'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (value) => onChanged(value.first),
    );
  }
}
