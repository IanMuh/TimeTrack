part of 'settings_page.dart';

extension _SettingsPageSections on _SettingsPageState {
  List<_SettingsSectionInfo> _settingsSections(
    BuildContext context, {
    bool includeDesktopGeneral = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return [
      if (includeDesktopGeneral)
        _SettingsSectionInfo(
          section: _SettingsSection.general,
          label: l10n.settingsDesktopGeneral,
          hint: l10n.settingsDesktopGeneralHint,
          icon: Icons.tune_outlined,
        ),
      if (includeDesktopGeneral)
        _SettingsSectionInfo(
          section: _SettingsSection.data,
          label: l10n.settingsDesktopData,
          hint: l10n.settingsDesktopDataHint,
          icon: Icons.storage_outlined,
        ),
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
      _SettingsSection.general => DesktopGeneralSettingsCard(state: state),
      _SettingsSection.data => DesktopDataSettingsCard(state: state),
      _SettingsSection.reminders => ReminderSettingsCard(state: state),
      _SettingsSection.timeline => TimelineSettingsCard(state: state),
      _SettingsSection.cloudSync => CloudSyncSettingsCard(state: state),
      _SettingsSection.interop => InteropSettingsCard(state: state),
      _SettingsSection.updates => VersionUpdateSettingsCard(state: state),
    };
  }
}
