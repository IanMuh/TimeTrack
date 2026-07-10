import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/sync_status_store.dart';
import '../l10n/app_localizations.dart';
import 'ui_components.dart';

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
    SyncTarget.cloudLan => l10n.syncTargetCloudLan,
    SyncTarget.cloud => l10n.syncTargetCloud,
    SyncTarget.lan => l10n.syncTargetLan,
    SyncTarget.none => l10n.syncTargetNone,
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
