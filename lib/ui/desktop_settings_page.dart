part of 'settings_page.dart';

enum DesktopSettingsSection {
  general,
  data,
  reminders,
  timeline,
  sync,
  interop,
  about,
}

class DesktopSettingsOverview extends StatelessWidget {
  const DesktopSettingsOverview({
    required this.state,
    required this.onOpenSection,
    super.key,
  });

  final AppState state;
  final ValueChanged<DesktopSettingsSection> onOpenSection;

  @override
  Widget build(BuildContext context) {
    final general = _MobileSettingsGroup(
      title: _mobileSettingsText(context, en: 'General', zh: '通用'),
      rows: [
        _MobileSettingsRow(
          label: _mobileSettingsText(context, en: 'Appearance', zh: '外观'),
          value: _mobileSettingsText(context, en: 'Light', zh: '浅色'),
          onTap: () => _showMobileInfo(
            context,
            title: _mobileSettingsText(context, en: 'Appearance', zh: '外观'),
            message: _mobileSettingsText(
              context,
              en: 'The current mobile theme follows the light reference.',
              zh: '当前移动端外观跟随浅色参考图。',
            ),
          ),
        ),
        _MobileSettingsRow(
          label: _mobileSettingsText(
            context,
            en: 'First Day of Week',
            zh: '每周起始日',
          ),
          value: _mobileSettingsText(context, en: 'Monday', zh: '周一'),
          onTap: () => onOpenSection(DesktopSettingsSection.timeline),
        ),
        _MobileSettingsRow(
          label: _mobileSettingsText(context, en: 'Time Format', zh: '时间格式'),
          value: _mobileSettingsText(context, en: '12-hour', zh: '12 小时'),
          onTap: () => _showMobileInfo(
            context,
            title: _mobileSettingsText(context, en: 'Time Format', zh: '时间格式'),
            message: _mobileSettingsText(
              context,
              en: 'Time labels use the active app locale.',
              zh: '时间标签会跟随当前应用区域设置。',
            ),
          ),
        ),
        _MobileSettingsRow(
          label: _mobileSettingsText(
            context,
            en: 'Default Session Length',
            zh: '默认记录时长',
          ),
          value: AppLocalizations.of(context)!.minutesFormat(25),
          onTap: () => onOpenSection(DesktopSettingsSection.timeline),
        ),
        _MobileSettingsRow(
          label: _mobileSettingsText(context, en: 'Quick Reminder', zh: '快速提醒'),
          value: _quickReminderValue(context, state.settings.reminderMethod),
          onTap: () => onOpenSection(DesktopSettingsSection.reminders),
        ),
      ],
    );
    final data = _MobileSettingsGroup(
      title: _mobileSettingsText(context, en: 'Backup & Export', zh: '备份与导出'),
      rows: [
        _MobileSettingsRow(
          label: _mobileSettingsText(context, en: 'Export Data', zh: '导出数据'),
          onTap: () => onOpenSection(DesktopSettingsSection.interop),
        ),
        _MobileSettingsRow(
          label: _mobileSettingsText(
            context,
            en: 'Clear All Data',
            zh: '清除全部数据',
          ),
          onTap: () => _showMobileInfo(
            context,
            title: _mobileSettingsText(
              context,
              en: 'Clear All Data',
              zh: '清除全部数据',
            ),
            message: _mobileSettingsText(
              context,
              en: 'Export a backup before removing local records.',
              zh: '清除本地记录前，请先导出备份。',
            ),
          ),
        ),
      ],
    );
    final sync = _MobileSettingsGroup(
      title: _mobileSettingsText(context, en: 'Sync', zh: '同步'),
      rows: [
        _MobileSettingsRow(
          label: _mobileSettingsText(context, en: 'Sync Mode', zh: '同步模式'),
          value: _mobileSyncMode(context, state.currentSyncTarget),
          onTap: () => onOpenSection(DesktopSettingsSection.sync),
        ),
        _MobileSettingsRow(
          label: _mobileSettingsText(context, en: 'Last Sync', zh: '上次同步'),
          value: _mobileLastSync(
            context,
            state.syncStatus.lastSuccessfulSyncAt,
          ),
          statusDot: state.syncStatus.lastSuccessfulSyncAt == null
              ? null
              : const Color(0xff22c55e),
          onTap: () => onOpenSection(DesktopSettingsSection.sync),
        ),
      ],
    );
    final about = _MobileSettingsGroup(
      title: _mobileSettingsText(context, en: 'About', zh: '关于'),
      rows: [
        _MobileSettingsRow(
          label: _mobileSettingsText(
            context,
            en: 'About TimeTrack',
            zh: '关于 TimeTrack',
          ),
          value: _mobileVersion(state),
          onTap: () => onOpenSection(DesktopSettingsSection.about),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 940;
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              general,
              const SizedBox(height: 18),
              data,
              const SizedBox(height: 18),
              sync,
              const SizedBox(height: 18),
              about,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  general,
                  const SizedBox(height: 18),
                  data,
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sync,
                  const SizedBox(height: 18),
                  about,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class DesktopGeneralSettingsCard extends StatelessWidget {
  const DesktopGeneralSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return _MobileSettingsGroup(
      title: _mobileSettingsText(context, en: 'General', zh: '通用'),
      rows: [
        _MobileSettingsRow(
          label: _mobileSettingsText(context, en: 'Appearance', zh: '外观'),
          value: _mobileSettingsText(context, en: 'Light', zh: '浅色'),
          onTap: () => _showMobileInfo(
            context,
            title: _mobileSettingsText(context, en: 'Appearance', zh: '外观'),
            message: _mobileSettingsText(
              context,
              en: 'The current mobile theme follows the light reference.',
              zh: '当前移动端外观跟随浅色参考图。',
            ),
          ),
        ),
        _MobileSettingsRow(
          label: _mobileSettingsText(
            context,
            en: 'First Day of Week',
            zh: '每周起始日',
          ),
          value: _mobileSettingsText(context, en: 'Monday', zh: '周一'),
          onTap: () => _showMobileInfo(
            context,
            title: _mobileSettingsText(
              context,
              en: 'First Day of Week',
              zh: '每周起始日',
            ),
            message: _mobileSettingsText(
              context,
              en: 'Timeline ranges start on Monday.',
              zh: '时间线范围从周一开始。',
            ),
          ),
        ),
        _MobileSettingsRow(
          label: _mobileSettingsText(context, en: 'Time Format', zh: '时间格式'),
          value: _mobileSettingsText(context, en: '12-hour', zh: '12 小时'),
          onTap: () => _showMobileInfo(
            context,
            title: _mobileSettingsText(context, en: 'Time Format', zh: '时间格式'),
            message: _mobileSettingsText(
              context,
              en: 'Time labels use the active app locale.',
              zh: '时间标签会跟随当前应用区域设置。',
            ),
          ),
        ),
        _MobileSettingsRow(
          label: _mobileSettingsText(
            context,
            en: 'Default Session Length',
            zh: '默认记录时长',
          ),
          value: AppLocalizations.of(context)!.minutesFormat(25),
          onTap: () => _showMobileInfo(
            context,
            title: _mobileSettingsText(
              context,
              en: 'Default Session Length',
              zh: '默认记录时长',
            ),
            message: _mobileSettingsText(
              context,
              en: 'Manual entry defaults stay at 25 minutes.',
              zh: '补记默认时长保持为 25 分钟。',
            ),
          ),
        ),
        _MobileSettingsRow(
          label: _mobileSettingsText(context, en: 'Quick Reminder', zh: '快速提醒'),
          value: _quickReminderValue(context, state.settings.reminderMethod),
          onTap: () => _showMobileInfo(
            context,
            title: _mobileSettingsText(
              context,
              en: 'Quick Reminder',
              zh: '快速提醒',
            ),
            message: _mobileSettingsText(
              context,
              en: 'Open Reminder Settings for full reminder controls.',
              zh: '进入提醒设置可调整完整提醒选项。',
            ),
          ),
        ),
      ],
    );
  }
}

class DesktopDataSettingsCard extends StatelessWidget {
  const DesktopDataSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _MobileSettingsGroup(
      title: _mobileSettingsText(context, en: 'Backup & Export', zh: '备份与导出'),
      rows: [
        _MobileSettingsRow(
          label: _mobileSettingsText(context, en: 'Export Data', zh: '导出数据'),
          onTap: () => state.exportInteropFile(
            exportedPrefix: l10n.interopExportedPrefix,
            canceledMessage: l10n.interopExportCanceled,
            failedPrefix: l10n.interopExportFailedPrefix,
          ),
        ),
        _MobileSettingsRow(
          label: _mobileSettingsText(context, en: 'Import Data', zh: '导入数据'),
          onTap: () => state.importInteropFile(
            importedPrefix: l10n.interopImportedPrefix,
            canceledMessage: l10n.interopImportCanceled,
            failedPrefix: l10n.interopImportFailedPrefix,
          ),
        ),
        _MobileSettingsRow(
          label: _mobileSettingsText(
            context,
            en: 'Clear All Data',
            zh: '清除全部数据',
          ),
          onTap: () => _showMobileInfo(
            context,
            title: _mobileSettingsText(
              context,
              en: 'Clear All Data',
              zh: '清除全部数据',
            ),
            message: _mobileSettingsText(
              context,
              en: 'Export a backup before removing local records.',
              zh: '清除本地记录前，请先导出备份。',
            ),
          ),
        ),
      ],
    );
  }
}
