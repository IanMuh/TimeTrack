import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/date_time_ext.dart';
import '../l10n/app_localizations.dart';

class DayRangeSelector extends StatelessWidget {
  const DayRangeSelector({
    required this.selectedDay,
    required this.rangeEnd,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onDateTap,
    this.previousTooltip,
    this.nextTooltip,
    this.dense = false,
    this.shortDateLabel = false,
    super.key,
  });

  final DateTime selectedDay;
  final DateTime rangeEnd;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onDateTap;
  final String? previousTooltip;
  final String? nextTooltip;
  final bool dense;
  final bool shortDateLabel;

  @override
  Widget build(BuildContext context) {
    final dateButton = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: dense ? 92 : 104,
        maxWidth: dense ? 148 : 172,
      ),
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onDateTap();
              return null;
            },
          ),
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onDateTap,
          child: Semantics(
            button: true,
            label: AppLocalizations.of(context)!.selectDate,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: dense ? 5 : 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _formatRange(),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip:
                previousTooltip ?? AppLocalizations.of(context)!.previousDay,
            onPressed: onPreviousDay,
            constraints: BoxConstraints.tightFor(
              width: dense ? 34 : 48,
              height: dense ? 38 : 48,
            ),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_left),
          ),
          if (dense) Flexible(child: dateButton) else dateButton,
          IconButton(
            tooltip: nextTooltip ?? AppLocalizations.of(context)!.nextDay,
            onPressed: onNextDay,
            constraints: BoxConstraints.tightFor(
              width: dense ? 34 : 48,
              height: dense ? 38 : 48,
            ),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  String _formatRange() {
    if (selectedDay.isSameDate(rangeEnd)) {
      return DateFormat(shortDateLabel ? 'MM-dd' : 'yyyy-MM-dd')
          .format(selectedDay);
    }
    return '${DateFormat('MM-dd').format(selectedDay)} - '
        '${DateFormat('MM-dd').format(rangeEnd)}';
  }
}
