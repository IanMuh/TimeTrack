import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/app_update_service.dart';
import '../l10n/app_localizations.dart';
import 'ui_components.dart';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final showDownloadAction = update != null || !compact;
        return QuietPanel(
          padding: EdgeInsets.all(compact ? 16 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                title: l10n.versionUpdate,
                subtitle: l10n.versionUpdateHint,
                icon: Icons.system_update_alt_outlined,
              ),
              SizedBox(height: compact ? 12 : 14),
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
              SizedBox(height: compact ? 12 : 16),
              Wrap(
                spacing: 10,
                runSpacing: compact ? 8 : 10,
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
                  if (showDownloadAction)
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
      },
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
