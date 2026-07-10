import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../l10n/app_localizations.dart';
import 'settings_field.dart';
import 'ui_components.dart';

class TimelineSettingsCard extends StatefulWidget {
  const TimelineSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  State<TimelineSettingsCard> createState() => _TimelineSettingsCardState();
}

class _TimelineSettingsCardState extends State<TimelineSettingsCard> {
  double? _draftMergeThresholdMinutes;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final settings = state.settings;
    final thresholdMinutes = (_draftMergeThresholdMinutes ??
            settings.mergeNeighborThresholdMinutes.toDouble())
        .round();
    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: AppLocalizations.of(context)!.timelineSettings,
            subtitle: AppLocalizations.of(context)!.timelineSettingsHint,
            icon: Icons.timeline,
          ),
          const SizedBox(height: 14),
          SettingsField(
            icon: Icons.merge_type_outlined,
            label: AppLocalizations.of(context)!.mergeThreshold,
            value:
                AppLocalizations.of(context)!.minutesFormat(thresholdMinutes),
            child: Slider(
              min: 1,
              max: 60,
              divisions: 59,
              value: thresholdMinutes.toDouble(),
              label:
                  AppLocalizations.of(context)!.minutesFormat(thresholdMinutes),
              onChanged: (value) =>
                  setState(() => _draftMergeThresholdMinutes = value),
              onChangeEnd: (value) {
                _draftMergeThresholdMinutes = null;
                state.updateReminderSettings(
                  mergeNeighborThresholdMinutes: value.round(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
