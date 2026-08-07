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
          label: _mobileSettingsText(context, en: 'General', zh: '通用'),
          hint: _mobileSettingsText(
            context,
            en: 'Appearance, time format, and quick reminder.',
            zh: '外观、时间格式和快速提醒。',
          ),
          icon: Icons.tune_outlined,
        ),
      if (includeDesktopGeneral)
        _SettingsSectionInfo(
          section: _SettingsSection.data,
          label:
              _mobileSettingsText(context, en: 'Backup & Export', zh: '备份与导出'),
          hint: _mobileSettingsText(
            context,
            en: 'Backup, import, and clear data actions.',
            zh: '备份、导入和清除数据操作。',
          ),
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
