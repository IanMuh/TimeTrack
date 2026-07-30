import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/app_update_service.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'interop_settings_card.dart';
import 'reminder_settings_card.dart';
import 'sync_settings_cards.dart';
import 'timeline_settings_card.dart';
import 'ui_components.dart';
import 'version_update_settings_card.dart';

export 'interop_settings_card.dart';
export 'reminder_settings_card.dart';
export 'sync_settings_cards.dart';
export 'timeline_settings_card.dart';
export 'version_update_settings_card.dart';

part 'settings_section_list.dart';

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
          maxWidth: 1040,
          children: [
            PageHeader(
              title: AppLocalizations.of(context)!.settings,
              subtitle: AppLocalizations.of(context)!.settingsSubtitle,
            ),
            const SectionGap(),
            LayoutBuilder(
              builder: (context, constraints) {
                final expanded =
                    MediaQuery.sizeOf(context).width >= expandedBreakpoint ||
                        constraints.maxWidth >= expandedBreakpoint;
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
                        child: Tooltip(
                          message:
                              AppLocalizations.of(context)!.settingsSections,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedCompactSection = null;
                                _compactSectionListRequested = true;
                              });
                            },
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: Text(
                              AppLocalizations.of(context)!.settingsSections,
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(44, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
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
                      width: 284,
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
                    const SizedBox(width: 20),
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
        hint: l10n.reminderSettingsHint,
        icon: Icons.notifications_outlined,
      ),
      _SettingsSectionInfo(
        section: _SettingsSection.timeline,
        label: l10n.timelineSettings,
        hint: l10n.timelineSettingsHint,
        icon: Icons.timeline,
      ),
      _SettingsSectionInfo(
        section: _SettingsSection.cloudSync,
        label: l10n.cloudSync,
        hint: l10n.cloudSyncHint,
        icon: Icons.cloud_sync_outlined,
      ),
      _SettingsSectionInfo(
        section: _SettingsSection.interop,
        label: l10n.deviceInterop,
        hint: l10n.deviceInteropHint,
        icon: Icons.devices_other_outlined,
      ),
      _SettingsSectionInfo(
        section: _SettingsSection.updates,
        label: l10n.versionUpdate,
        hint: l10n.versionUpdateHint,
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
