import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/app_update_service.dart';
import '../domain/profile_settings.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'interop_message_panel.dart';
import 'ui_components.dart';

enum _SettingsSection {
  reminders,
  timeline,
  cloudSync,
  interop,
  updates,
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.state, super.key});

  final AppState state;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  _SettingsSection? _selectedCompactSection;
  _SettingsSection _selectedExpandedSection = _SettingsSection.reminders;
  bool _compactSectionListRequested = false;
  bool _expandedSectionSelectedByUser = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return AdaptivePage(
          pageKey: const PageStorageKey('settings-page'),
          maxWidth: 920,
          children: [
            PageHeader(
              title: AppLocalizations.of(context)!.settings,
              subtitle: AppLocalizations.of(context)!.settingsSubtitle,
            ),
            const SectionGap(),
            LayoutBuilder(
              builder: (context, constraints) {
                final expanded = constraints.maxWidth >= expandedBreakpoint;
                final sections = _settingsSections(context);
                if (!expanded) {
                  final selected = _selectedCompactSection ??
                      (!_compactSectionListRequested &&
                              _shouldOpenUpdateSection(state)
                          ? _SettingsSection.updates
                          : null);
                  if (selected == null) {
                    return _SettingsSectionList(
                      sections: sections,
                      selected: null,
                      onSelected: (section) {
                        setState(() {
                          _selectedCompactSection = section;
                          _compactSectionListRequested = false;
                        });
                      },
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton.filledTonal(
                          tooltip:
                              AppLocalizations.of(context)!.settingsSections,
                          onPressed: () {
                            setState(() {
                              _selectedCompactSection = null;
                              _compactSectionListRequested = true;
                            });
                          },
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionWidget(selected, state),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 220,
                      child: _SettingsSectionList(
                        sections: sections,
                        selected: _effectiveExpandedSection(state),
                        onSelected: (section) {
                          setState(() {
                            _selectedExpandedSection = section;
                            _expandedSectionSelectedByUser = true;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _sectionWidget(
                          _effectiveExpandedSection(state), state),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  List<_SettingsSectionInfo> _settingsSections(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      _SettingsSectionInfo(
        section: _SettingsSection.reminders,
        label: l10n.reminderSettings,
        icon: Icons.notifications_outlined,
      ),
      _SettingsSectionInfo(
        section: _SettingsSection.timeline,
        label: l10n.timelineSettings,
        icon: Icons.timeline,
      ),
      _SettingsSectionInfo(
        section: _SettingsSection.cloudSync,
        label: l10n.cloudSync,
        icon: Icons.cloud_sync_outlined,
      ),
      _SettingsSectionInfo(
        section: _SettingsSection.interop,
        label: l10n.deviceInterop,
        icon: Icons.devices_other_outlined,
      ),
      _SettingsSectionInfo(
        section: _SettingsSection.updates,
        label: l10n.versionUpdate,
        icon: Icons.system_update_alt_outlined,
      ),
    ];
  }

  _SettingsSection _effectiveExpandedSection(AppState state) {
    if (!_expandedSectionSelectedByUser &&
        _selectedExpandedSection == _SettingsSection.reminders &&
        _shouldOpenUpdateSection(state)) {
      return _SettingsSection.updates;
    }
    return _selectedExpandedSection;
  }

  bool _shouldOpenUpdateSection(AppState state) {
    return state.updateStatus != AppUpdateStatus.idle ||
        state.availableUpdate != null ||
        state.updateErrorMessage != null;
  }

  Widget _sectionWidget(_SettingsSection section, AppState state) {
    return switch (section) {
      _SettingsSection.reminders => ReminderSettingsCard(state: state),
      _SettingsSection.timeline => TimelineSettingsCard(state: state),
      _SettingsSection.cloudSync => CloudSyncSettingsCard(state: state),
      _SettingsSection.interop => InteropSettingsCard(state: state),
      _SettingsSection.updates => VersionUpdateSettingsCard(state: state),
    };
  }
}

class _SettingsSectionInfo {
  const _SettingsSectionInfo({
    required this.section,
    required this.label,
    required this.icon,
  });

  final _SettingsSection section;
  final String label;
  final IconData icon;
}

class _SettingsSectionList extends StatelessWidget {
  const _SettingsSectionList({
    required this.sections,
    required this.selected,
    required this.onSelected,
  });

  final List<_SettingsSectionInfo> sections;
  final _SettingsSection? selected;
  final ValueChanged<_SettingsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return QuietPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (final info in sections)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: ListTile(
                leading: Icon(info.icon),
                title: Text(info.label),
                selected: selected == info.section,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () => onSelected(info.section),
              ),
            ),
        ],
      ),
    );
  }
}

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
          _ReminderField(
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
          _ReminderField(
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
          _ReminderField(
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
          _ReminderField(
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
          _ReminderField(
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

class _ReminderField extends StatelessWidget {
  const _ReminderField({
    required this.icon,
    required this.label,
    required this.value,
    required this.child,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
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

class CloudSyncSettingsCard extends StatelessWidget {
  const CloudSyncSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final statusTitle = state.canCloudSync
        ? AppLocalizations.of(context)!.supabaseConfigured
        : AppLocalizations.of(context)!.supabaseNotConfigured;
    final statusSubtitle = state.isSignedIn
        ? AppLocalizations.of(context)!.loggedIn
        : AppLocalizations.of(context)!.notLoggedIn;
    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: AppLocalizations.of(context)!.cloudSync,
            subtitle: AppLocalizations.of(context)!.cloudSyncHint,
            icon: Icons.cloud_sync_outlined,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: state.canCloudSync
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                color: state.canCloudSync
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(statusSubtitle),
                  ],
                ),
              ),
              if (state.isSignedIn)
                TextButton.icon(
                  onPressed: state.signOut,
                  icon: const Icon(Icons.logout),
                  label: Text(AppLocalizations.of(context)!.signOut),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _SyncStatusSummary(state: state),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                state.canCloudSync && state.isSignedIn ? state.sync : null,
            icon: const Icon(Icons.sync),
            label: Text(AppLocalizations.of(context)!.syncNow),
          ),
        ],
      ),
    );
  }
}

class VersionUpdateSettingsCard extends StatelessWidget {
  const VersionUpdateSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final update = state.availableUpdate;
    final isChecking = state.updateStatus == AppUpdateStatus.checking;
    final statusText = state.updateErrorMessage == null
        ? _formatUpdateStatus(context, state.updateStatus)
        : l10n.updateErrorLabel(state.updateErrorMessage!);
    final statusColor = _updateStatusColor(context, state.updateStatus);

    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: l10n.versionUpdate,
            subtitle: l10n.versionUpdateHint,
            icon: Icons.system_update_alt_outlined,
          ),
          const SizedBox(height: 14),
          _UpdateInfoRow(
            label: l10n.currentVersion,
            value: state.currentAppVersion.isEmpty
                ? l10n.versionUnknown
                : state.currentAppVersion,
          ),
          if (update != null) ...[
            const SizedBox(height: 10),
            _UpdateInfoRow(
              label: l10n.latestVersion,
              value: update.latestVersion.toString(),
            ),
          ],
          const SizedBox(height: 12),
          StatusPill(
            label: statusText,
            icon: _updateStatusIcon(state.updateStatus),
            color: statusColor,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: isChecking
                    ? null
                    : () {
                        unawaited(state.checkForUpdates());
                      },
                icon: const Icon(Icons.refresh_outlined),
                label: Text(l10n.checkUpdates),
              ),
              OutlinedButton.icon(
                onPressed: update == null
                    ? null
                    : () {
                        unawaited(state.openUpdateDownload());
                      },
                icon: const Icon(Icons.open_in_new_outlined),
                label: Text(l10n.openDownloadPage),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpdateInfoRow extends StatelessWidget {
  const _UpdateInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      textAlign: TextAlign.end,
      softWrap: true,
      style: Theme.of(context).textTheme.titleSmall,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerLeft, child: valueText),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(child: valueText),
          ],
        );
      },
    );
  }
}

String _formatUpdateStatus(BuildContext context, AppUpdateStatus status) {
  final l10n = AppLocalizations.of(context)!;
  return switch (status) {
    AppUpdateStatus.idle => l10n.updateStatusIdle,
    AppUpdateStatus.checking => l10n.updateStatusChecking,
    AppUpdateStatus.upToDate => l10n.updateStatusUpToDate,
    AppUpdateStatus.available => l10n.updateStatusAvailable,
    AppUpdateStatus.failed => l10n.updateStatusFailed,
  };
}

IconData _updateStatusIcon(AppUpdateStatus status) {
  return switch (status) {
    AppUpdateStatus.idle => Icons.info_outline,
    AppUpdateStatus.checking => Icons.sync,
    AppUpdateStatus.upToDate => Icons.verified_outlined,
    AppUpdateStatus.available => Icons.system_update_outlined,
    AppUpdateStatus.failed => Icons.error_outline,
  };
}

Color _updateStatusColor(BuildContext context, AppUpdateStatus status) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (status) {
    AppUpdateStatus.idle => colorScheme.onSurfaceVariant,
    AppUpdateStatus.checking => colorScheme.primary,
    AppUpdateStatus.upToDate => colorScheme.primary,
    AppUpdateStatus.available => colorScheme.tertiary,
    AppUpdateStatus.failed => colorScheme.error,
  };
}

class _SyncStatusSummary extends StatelessWidget {
  const _SyncStatusSummary({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = state.syncStatus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.syncStatus,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(l10n.syncTargetLabel(_formatSyncTarget(context, state))),
        const SizedBox(height: 2),
        Text(_formatLastSync(context, status.lastSuccessfulSyncAt)),
        if (status.hasError) ...[
          const SizedBox(height: 2),
          Text(
            l10n.lastSyncError(status.lastError!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

String _formatSyncTarget(BuildContext context, AppState state) {
  final l10n = AppLocalizations.of(context)!;
  return switch (state.currentSyncTarget) {
    'cloud_lan' => l10n.syncTargetCloudLan,
    'cloud' => l10n.syncTargetCloud,
    'lan' => l10n.syncTargetLan,
    _ => l10n.syncTargetNone,
  };
}

String _formatLastSync(BuildContext context, DateTime? value) {
  final l10n = AppLocalizations.of(context)!;
  if (value == null) {
    return l10n.lastSyncNever;
  }
  final local = value.toLocal();
  final date = MaterialLocalizations.of(context).formatShortDate(local);
  final time = TimeOfDay.fromDateTime(local).format(context);
  return l10n.lastSyncAt('$date $time');
}

class InteropSettingsCard extends StatefulWidget {
  const InteropSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  State<InteropSettingsCard> createState() => _InteropSettingsCardState();
}

class _InteropSettingsCardState extends State<InteropSettingsCard> {
  final _addressController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (_addressController.text.isEmpty && state.lanPeer?.baseUrl != null) {
      _addressController.text = state.lanPeer!.baseUrl!;
    }

    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: AppLocalizations.of(context)!.deviceInterop,
            subtitle: AppLocalizations.of(context)!.deviceInteropHint,
            icon: Icons.devices_other_outlined,
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context)!.interopSecurityNotice,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final expanded = constraints.maxWidth >= expandedBreakpoint;
              final host = _LanHostPanel(state: state);
              final client = _LanClientPanel(
                state: state,
                addressController: _addressController,
                codeController: _codeController,
              );
              if (!expanded) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    host,
                    const SizedBox(height: 16),
                    client,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: host),
                  const SizedBox(width: 16),
                  Expanded(child: client),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: state.importInteropFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(AppLocalizations.of(context)!.importFile),
              ),
              OutlinedButton.icon(
                onPressed: state.exportInteropFile,
                icon: const Icon(Icons.download_outlined),
                label: Text(AppLocalizations.of(context)!.exportFile),
              ),
              FilledButton.icon(
                onPressed:
                    state.hasSyncTarget && !state.isSyncing ? state.sync : null,
                icon: const Icon(Icons.sync),
                label: Text(state.isSyncing
                    ? AppLocalizations.of(context)!.syncing
                    : AppLocalizations.of(context)!.syncNow),
              ),
            ],
          ),
          if (state.interopMessage != null) ...[
            const SizedBox(height: 12),
            InteropMessagePanel(message: state.interopMessage!),
          ],
        ],
      ),
    );
  }
}

class _LanHostPanel extends StatelessWidget {
  const _LanHostPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: AppLocalizations.of(context)!.lanHost,
          subtitle: state.isLanServerRunning
              ? AppLocalizations.of(context)!.lanHostWaiting
              : null,
          icon: Icons.router_outlined,
        ),
        const SizedBox(height: 8),
        Text(
          !state.canHostLan
              ? AppLocalizations.of(context)!.lanHostWindowsNote
              : state.isLanServerRunning
                  ? AppLocalizations.of(context)!.lanHostAndroidNote
                  : AppLocalizations.of(context)!.lanHostStartNote,
        ),
        if (state.isLanServerRunning) ...[
          const SizedBox(height: 10),
          SelectableText(
            state.lanServerUrls.isEmpty
                ? 'http://127.0.0.1'
                : state.lanServerUrls.join('\n'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          StatusPill(
            label: AppLocalizations.of(context)!
                .pairingCodeLabel(state.lanPairingCode ?? ''),
            icon: Icons.pin_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: !state.canHostLan
              ? null
              : state.isLanServerRunning
                  ? state.stopLanServer
                  : state.startLanServer,
          icon: Icon(
            state.isLanServerRunning
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline,
          ),
          label: Text(
            !state.canHostLan
                ? AppLocalizations.of(context)!.windowsOnly
                : state.isLanServerRunning
                    ? AppLocalizations.of(context)!.stopHost
                    : AppLocalizations.of(context)!.startHost,
          ),
        ),
      ],
    );
  }
}

class _LanClientPanel extends StatelessWidget {
  const _LanClientPanel({
    required this.state,
    required this.addressController,
    required this.codeController,
  });

  final AppState state;
  final TextEditingController addressController;
  final TextEditingController codeController;

  @override
  Widget build(BuildContext context) {
    final peer = state.lanPeer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: AppLocalizations.of(context)!.connectLanHost,
          subtitle: AppLocalizations.of(context)!.connectLanHostHint,
          icon: Icons.phone_android_outlined,
        ),
        const SizedBox(height: 8),
        if (peer != null) ...[
          StatusPill(
            label: AppLocalizations.of(context)!.pairedWith(peer.displayName),
            icon: Icons.link_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          if (peer.baseUrl != null) Text(peer.baseUrl!),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: state.clearLanPeer,
            icon: const Icon(Icons.link_off_outlined),
            label: Text(AppLocalizations.of(context)!.removePairing),
          ),
        ] else ...[
          TextField(
            controller: addressController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.hostAddress,
              hintText: AppLocalizations.of(context)!.hostHint,
              prefixIcon: const Icon(Icons.link_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.pairingCodeInput,
              prefixIcon: const Icon(Icons.pin_outlined),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => state.pairLanPeer(
              baseUrl: addressController.text,
              code: codeController.text,
            ),
            icon: const Icon(Icons.link_outlined),
            label: Text(AppLocalizations.of(context)!.pairAndSync),
          ),
        ],
      ],
    );
  }
}
