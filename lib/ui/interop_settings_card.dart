import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/sync_status_store.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'interop_message_panel.dart';
import 'ui_components.dart';

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
      padding: const EdgeInsets.all(16),
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
              final host = QuietPanel(
                padding: const EdgeInsets.all(14),
                child: _LanHostPanel(state: state),
              );
              final client = QuietPanel(
                padding: const EdgeInsets.all(14),
                child: _LanClientPanel(
                  state: state,
                  addressController: _addressController,
                  codeController: _codeController,
                ),
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
          const SizedBox(height: 14),
          _FileInteropPanel(state: state),
          const SizedBox(height: 14),
          _InteropSyncPanel(state: state),
          if (state.interopMessage != null) ...[
            const SizedBox(height: 12),
            InteropMessagePanel(message: state.interopMessage!),
          ],
        ],
      ),
    );
  }
}

class _FileInteropPanel extends StatelessWidget {
  const _FileInteropPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return QuietPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '${l10n.importFile} / ${l10n.exportFile}',
            subtitle: l10n.deviceInteropHint,
            icon: Icons.file_upload_outlined,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: state.importInteropFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(l10n.importFile),
              ),
              OutlinedButton.icon(
                onPressed: state.exportInteropFile,
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.exportFile),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InteropSyncPanel extends StatelessWidget {
  const _InteropSyncPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return QuietPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: SectionTitle(
              title: l10n.syncNow,
              subtitle: state.hasSyncTarget
                  ? l10n.syncTargetLabel(_formatSyncTarget(context, state))
                  : null,
              icon: Icons.sync,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed:
                state.hasSyncTarget && !state.isSyncing ? state.sync : null,
            icon: const Icon(Icons.sync),
            label: Text(state.isSyncing ? l10n.syncing : l10n.syncNow),
          ),
        ],
      ),
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
