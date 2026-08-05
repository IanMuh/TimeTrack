part of 'settings_page.dart';

class _MobileSettingsPage extends StatelessWidget {
  const _MobileSettingsPage({
    required this.state,
    required this.onOpenSection,
  });

  final AppState state;
  final ValueChanged<_SettingsSection> onOpenSection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileSettingsGroup(
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
              onTap: () => onOpenSection(_SettingsSection.timeline),
            ),
            _MobileSettingsRow(
              label:
                  _mobileSettingsText(context, en: 'Time Format', zh: '时间格式'),
              value: _mobileSettingsText(context, en: '12-hour', zh: '12 小时'),
              onTap: () => _showMobileInfo(
                context,
                title:
                    _mobileSettingsText(context, en: 'Time Format', zh: '时间格式'),
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
              value: l10n.minutesFormat(25),
              onTap: () => onOpenSection(_SettingsSection.timeline),
            ),
            _MobileSettingsRow(
              label: _mobileSettingsText(
                context,
                en: 'Quick Reminder',
                zh: '快速提醒',
              ),
              value:
                  _quickReminderValue(context, state.settings.reminderMethod),
              onTap: () => onOpenSection(_SettingsSection.reminders),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _MobileSettingsGroup(
          title: _mobileSettingsText(
            context,
            en: 'Backup & Export',
            zh: '备份与导出',
          ),
          rows: [
            _MobileSettingsRow(
              label:
                  _mobileSettingsText(context, en: 'Export Data', zh: '导出数据'),
              onTap: () => onOpenSection(_SettingsSection.interop),
            ),
            _MobileSettingsRow(
              label: _mobileSettingsText(context,
                  en: 'Clear All Data', zh: '清除全部数据'),
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
        ),
        const SizedBox(height: 18),
        _MobileSettingsGroup(
          title: _mobileSettingsText(context, en: 'Sync', zh: '同步'),
          rows: [
            _MobileSettingsRow(
              label: _mobileSettingsText(context, en: 'Sync Mode', zh: '同步模式'),
              value: _mobileSyncMode(context, state.currentSyncTarget),
              onTap: () => onOpenSection(_SettingsSection.cloudSync),
            ),
            _MobileSettingsRow(
              label: _mobileSettingsText(context, en: 'Last Sync', zh: '上次同步'),
              value: _mobileLastSync(
                  context, state.syncStatus.lastSuccessfulSyncAt),
              statusDot: state.syncStatus.lastSuccessfulSyncAt == null
                  ? null
                  : const Color(0xff22c55e),
              onTap: () => onOpenSection(_SettingsSection.cloudSync),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _MobileSettingsGroup(
          title: _mobileSettingsText(context, en: 'About', zh: '关于'),
          rows: [
            _MobileSettingsRow(
              label: _mobileSettingsText(
                context,
                en: 'About TimeTrack',
                zh: '关于 TimeTrack',
              ),
              value: _mobileVersion(state),
              onTap: () => onOpenSection(_SettingsSection.updates),
            ),
          ],
        ),
      ],
    );
  }
}

class _MobileSettingsGroup extends StatelessWidget {
  const _MobileSettingsGroup({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_MobileSettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Material(
          color: colorScheme.surface,
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                for (final (index, row) in rows.indexed) ...[
                  row,
                  if (index != rows.length - 1)
                    Divider(
                      height: 1,
                      indent: 14,
                      color: colorScheme.outlineVariant,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileSettingsRow extends StatelessWidget {
  const _MobileSettingsRow({
    required this.label,
    this.value,
    this.statusDot,
    this.onTap,
  });

  final String label;
  final String? value;
  final Color? statusDot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = this.value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
                if (statusDot != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _mobileSettingsText(
  BuildContext context, {
  required String en,
  required String zh,
}) {
  return Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
}

String _quickReminderValue(BuildContext context, ReminderMethod method) {
  return method == ReminderMethod.silent
      ? _mobileSettingsText(context, en: 'Off', zh: '关')
      : _mobileSettingsText(context, en: 'On', zh: '开');
}

String _mobileSyncMode(BuildContext context, SyncTarget target) {
  return switch (target) {
    SyncTarget.none => _mobileSettingsText(context, en: 'Manual', zh: '手动'),
    SyncTarget.cloud => _mobileSettingsText(context, en: 'Cloud', zh: '云同步'),
    SyncTarget.lan => _mobileSettingsText(context, en: 'LAN', zh: '局域网'),
    SyncTarget.cloudLan =>
      _mobileSettingsText(context, en: 'Cloud + LAN', zh: '云同步 + 局域网'),
  };
}

String _mobileLastSync(BuildContext context, DateTime? value) {
  if (value == null) {
    return _mobileSettingsText(context, en: 'Never', zh: '从未');
  }
  final local = value.toLocal();
  final locale = Localizations.localeOf(context).toLanguageTag();
  final pattern = Localizations.localeOf(context).languageCode == 'zh'
      ? 'M月d日 HH:mm'
      : 'MMM d, h:mm a';
  return DateFormat(pattern, locale).format(local);
}

String _mobileVersion(AppState state) {
  return state.currentAppVersion.isEmpty ? '1.0.0' : state.currentAppVersion;
}

void _showMobileInfo(
  BuildContext context, {
  required String title,
  required String message,
}) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      );
    },
  );
}
