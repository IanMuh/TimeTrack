import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../domain/profile_settings.dart';
import '../l10n/app_localizations.dart';
import 'settings_field.dart';
import 'ui_components.dart';

class ReminderSettingsCard extends StatefulWidget {
  const ReminderSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  State<ReminderSettingsCard> createState() => _ReminderSettingsCardState();
}

class _ReminderSettingsCardState extends State<ReminderSettingsCard> {
  double? _draftReminderMinutes;
  double? _draftIntervalMinutes;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final settings = state.settings;
    final reminderMinutes =
        (_draftReminderMinutes ?? settings.reminderMinutes.toDouble()).round();
    final intervalMinutes =
        (_draftIntervalMinutes ?? settings.reminderIntervalMinutes.toDouble())
            .round();
    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: AppLocalizations.of(context)!.reminderSettings,
            subtitle: AppLocalizations.of(context)!.reminderSettingsHint,
            icon: Icons.notifications_outlined,
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context)!.reminderInAppNotice,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          SettingsField(
            icon: Icons.schedule_outlined,
            label: AppLocalizations.of(context)!.triggerTime,
            value: _formatReminderTime(
              context,
              settings.reminderTimeOfDayMinutes,
            ),
            child: _ReminderTimeButton(
              value: settings.reminderTimeOfDayMinutes,
              onChanged: (value) => state.updateReminderSettings(
                reminderTimeOfDayMinutes: value,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SettingsField(
            icon: Icons.notifications_outlined,
            label: AppLocalizations.of(context)!.durationLabel,
            value: AppLocalizations.of(context)!.minutesFormat(reminderMinutes),
            child: Slider(
              min: 15,
              max: 180,
              divisions: 11,
              value: reminderMinutes.toDouble(),
              label:
                  AppLocalizations.of(context)!.minutesFormat(reminderMinutes),
              onChanged: (value) =>
                  setState(() => _draftReminderMinutes = value),
              onChangeEnd: (value) {
                _draftReminderMinutes = null;
                state.updateReminderSettings(reminderMinutes: value.round());
              },
            ),
          ),
          const SizedBox(height: 12),
          SettingsField(
            icon: Icons.timelapse_outlined,
            label: AppLocalizations.of(context)!.interval,
            value: _formatInterval(context, intervalMinutes),
            child: Slider(
              min: 5,
              max: 60,
              divisions: 11,
              value: intervalMinutes.toDouble(),
              label: _formatInterval(context, intervalMinutes),
              onChanged: (value) =>
                  setState(() => _draftIntervalMinutes = value),
              onChangeEnd: (value) {
                _draftIntervalMinutes = null;
                state.updateReminderSettings(
                  reminderIntervalMinutes: value.round(),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SettingsField(
            icon: Icons.notification_add_outlined,
            label: AppLocalizations.of(context)!.method,
            value: _formatMethod(context, settings.reminderMethod),
            child: SegmentedButton<ReminderMethod>(
              segments: [
                ButtonSegment(
                  value: ReminderMethod.dialog,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(AppLocalizations.of(context)!.methodDialog),
                ),
                ButtonSegment(
                  value: ReminderMethod.banner,
                  icon: const Icon(Icons.drafts_outlined),
                  label: Text(AppLocalizations.of(context)!.methodBanner),
                ),
                ButtonSegment(
                  value: ReminderMethod.silent,
                  icon: const Icon(Icons.notifications_off_outlined),
                  label: Text(AppLocalizations.of(context)!.methodSilent),
                ),
              ],
              selected: {settings.reminderMethod},
              onSelectionChanged: (value) => state.updateReminderSettings(
                reminderMethod: value.first,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTimeButton extends StatelessWidget {
  const _ReminderTimeButton({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final hours = value ~/ 60;
    final minutes = value % 60;
    final text = TimeOfDay(hour: hours, minute: minutes).format(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: hours, minute: minutes),
          );
          if (picked != null) {
            onChanged(picked.hour * 60 + picked.minute);
          }
        },
        icon: const Icon(Icons.schedule),
        label: Text(text),
      ),
    );
  }
}

String _formatReminderTime(BuildContext context, int minutes) {
  final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  return time.format(context);
}

String _formatInterval(BuildContext context, int minutes) =>
    AppLocalizations.of(context)!.minutesFormat(minutes);

String _formatMethod(BuildContext context, ReminderMethod method) {
  return switch (method) {
    ReminderMethod.dialog => AppLocalizations.of(context)!.methodDialog,
    ReminderMethod.banner => AppLocalizations.of(context)!.methodBanner,
    ReminderMethod.silent => AppLocalizations.of(context)!.methodSilent,
  };
}
