part of 'settings_page.dart';

enum DesktopSettingsSection {
  general,
  data,
  sync,
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
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.settings,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DesktopSettingsGroup(
                    title: l10n.settingsDesktopGeneral,
                    children: [
                      _DesktopSettingsRow(
                        label: l10n.settingsDesktopAppearance,
                        value: l10n.settingsDesktopLight,
                        onTap: () =>
                            onOpenSection(DesktopSettingsSection.general),
                      ),
                      _DesktopSettingsRow(
                        label: l10n.settingsDesktopFirstDayOfWeek,
                        value: l10n.settingsDesktopMonday,
                        onTap: () =>
                            onOpenSection(DesktopSettingsSection.general),
                      ),
                      _DesktopSettingsRow(
                        label: l10n.settingsDesktopTimeFormat,
                        value: l10n.settingsDesktopTimeFormat12Hour,
                        onTap: () =>
                            onOpenSection(DesktopSettingsSection.general),
                      ),
                      _DesktopSettingsRow(
                        label: l10n.settingsDesktopDefaultSessionLength,
                        value: l10n.minutesFormat(25),
                        onTap: () =>
                            onOpenSection(DesktopSettingsSection.general),
                      ),
                      _DesktopSettingsRow(
                        label: l10n.settingsDesktopBreakReminder,
                        value: state.settings.reminderMethod !=
                                ReminderMethod.silent
                            ? l10n.settingsDesktopOn
                            : l10n.settingsDesktopOff,
                        trailing: Switch(
                          value: state.settings.reminderMethod !=
                              ReminderMethod.silent,
                          onChanged: (enabled) {
                            state.updateReminderSettings(
                              reminderMethod: enabled
                                  ? ReminderMethod.dialog
                                  : ReminderMethod.silent,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _DesktopSettingsGroup(
                        title: l10n.settingsDesktopData,
                        children: [
                          _DesktopSettingsRow(
                            label: l10n.settingsDesktopBackupExport,
                            onTap: () =>
                                onOpenSection(DesktopSettingsSection.data),
                          ),
                          _DesktopSettingsRow(
                            label: l10n.settingsDesktopImportData,
                            onTap: () =>
                                onOpenSection(DesktopSettingsSection.data),
                          ),
                          _DesktopSettingsRow(
                            label: l10n.settingsDesktopClearAllData,
                            labelColor: Theme.of(context).colorScheme.error,
                            onTap: () =>
                                onOpenSection(DesktopSettingsSection.data),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DesktopSettingsGroup(
                        title: l10n.settingsDesktopSync,
                        children: [
                          _DesktopSettingsRow(
                            label: l10n.settingsDesktopSyncMode,
                            value: _desktopSyncMode(context, state),
                            onTap: () =>
                                onOpenSection(DesktopSettingsSection.sync),
                          ),
                          _DesktopSettingsRow(
                            label: l10n.settingsDesktopLastSync,
                            value: _desktopLastSync(context, state),
                            statusDot:
                                state.syncStatus.lastSuccessfulSyncAt == null
                                    ? null
                                    : const Color(0xff22c55e),
                            onTap: () =>
                                onOpenSection(DesktopSettingsSection.sync),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DesktopSettingsGroup(
                        title: l10n.settingsDesktopAbout,
                        children: [
                          _DesktopSettingsRow(
                            label: l10n.settingsDesktopProduct,
                            value: _desktopVersion(state),
                            onTap: () =>
                                onOpenSection(DesktopSettingsSection.about),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
                            child: Row(
                              children: [
                                Text(
                                  l10n.settingsDesktopMadeWith,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.favorite,
                                  size: 11,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    l10n.settingsDesktopMadeForFocusedPeople,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSettingsGroup extends StatelessWidget {
  const _DesktopSettingsGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                child,
                if (index != children.length - 1)
                  Divider(
                    height: 1,
                    indent: 12,
                    endIndent: 12,
                    color: colorScheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopSettingsRow extends StatelessWidget {
  const _DesktopSettingsRow({
    required this.label,
    this.value,
    this.labelColor,
    this.statusDot,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String? value;
  final Color? labelColor;
  final Color? statusDot;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 128),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
                if (statusDot != null) ...[
                  const SizedBox(width: 7),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: statusDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: trailing!,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopGeneralSettingsCard extends StatelessWidget {
  const DesktopGeneralSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: l10n.settingsDesktopGeneral,
            subtitle: l10n.settingsDesktopGeneralHint,
            icon: Icons.tune_outlined,
          ),
          const SizedBox(height: 14),
          _DesktopGeneralField(
            label: l10n.settingsDesktopAppearance,
            value: l10n.settingsDesktopLight,
          ),
          const SizedBox(height: 10),
          _DesktopGeneralField(
            label: l10n.settingsDesktopFirstDayOfWeek,
            value: l10n.settingsDesktopMonday,
          ),
          const SizedBox(height: 10),
          _DesktopGeneralField(
            label: l10n.settingsDesktopTimeFormat,
            value: l10n.settingsDesktopTimeFormat12Hour,
          ),
          const SizedBox(height: 10),
          _DesktopGeneralField(
            label: l10n.settingsDesktopDefaultSessionLength,
            value: l10n.minutesFormat(25),
          ),
          const SizedBox(height: 10),
          _DesktopGeneralField(
            label: l10n.settingsDesktopBreakReminder,
            value: state.settings.reminderMethod == ReminderMethod.silent
                ? l10n.settingsDesktopOff
                : l10n.settingsDesktopOn,
            trailing: Switch(
              value: state.settings.reminderMethod != ReminderMethod.silent,
              onChanged: (enabled) {
                state.updateReminderSettings(
                  reminderMethod:
                      enabled ? ReminderMethod.dialog : ReminderMethod.silent,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopGeneralField extends StatelessWidget {
  const _DesktopGeneralField({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class DesktopDataSettingsCard extends StatelessWidget {
  const DesktopDataSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: l10n.settingsDesktopData,
            subtitle: l10n.settingsDesktopDataHint,
            icon: Icons.storage_outlined,
          ),
          const SizedBox(height: 14),
          _DesktopDataAction(
            title: l10n.settingsDesktopBackupExport,
            subtitle: l10n.settingsDesktopBackupExportHint,
            icon: Icons.download_outlined,
            onPressed: () => state.exportInteropFile(
              exportedPrefix: l10n.interopExportedPrefix,
              canceledMessage: l10n.interopExportCanceled,
              failedPrefix: l10n.interopExportFailedPrefix,
            ),
          ),
          const SizedBox(height: 10),
          _DesktopDataAction(
            title: l10n.settingsDesktopImportData,
            subtitle: l10n.settingsDesktopImportDataHint,
            icon: Icons.upload_file_outlined,
            onPressed: () => state.importInteropFile(
              importedPrefix: l10n.interopImportedPrefix,
              canceledMessage: l10n.interopImportCanceled,
              failedPrefix: l10n.interopImportFailedPrefix,
            ),
          ),
          const SizedBox(height: 10),
          _DesktopDataAction(
            title: l10n.settingsDesktopClearAllData,
            subtitle: l10n.settingsDesktopClearAllDataHint,
            icon: Icons.delete_outline,
            color: colorScheme.error,
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

class _DesktopDataAction extends StatelessWidget {
  const _DesktopDataAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = color ?? colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconBadge(icon: icon, color: accent, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(onPressed == null ? Icons.lock_outline : icon),
              label: Text(
                onPressed == null
                    ? AppLocalizations.of(context)!.settingsDesktopDisabled
                    : AppLocalizations.of(context)!.settingsDesktopOpen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _desktopSyncMode(BuildContext context, AppState state) {
  final l10n = AppLocalizations.of(context)!;
  return switch (state.currentSyncTarget) {
    SyncTarget.none => l10n.settingsDesktopManual,
    SyncTarget.cloud => l10n.syncTargetCloud,
    SyncTarget.lan => l10n.syncTargetLan,
    SyncTarget.cloudLan => l10n.syncTargetCloudLan,
  };
}

String _desktopLastSync(BuildContext context, AppState state) {
  final value = state.syncStatus.lastSuccessfulSyncAt;
  if (value == null) {
    return AppLocalizations.of(context)!.settingsDesktopNever;
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat('MMM d, h:mm a', locale).format(value.toLocal());
}

String _desktopVersion(AppState state) {
  return state.currentAppVersion.isEmpty ? '1.0.0' : state.currentAppVersion;
}
