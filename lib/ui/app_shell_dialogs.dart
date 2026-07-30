import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../l10n/app_localizations.dart';
import 'login_page.dart';

class ReminderDialog extends StatelessWidget {
  const ReminderDialog({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.stillDoingThis),
      content: Text(AppLocalizations.of(context)!.activityRunningMinutes(
        state.runningDuration().inMinutes,
      )),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await state.snoozeReminder();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.snooze),
          label: Text(AppLocalizations.of(context)!.remindLater),
        ),
        TextButton.icon(
          onPressed: () async {
            await state.stopCurrent();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.stop_circle_outlined),
          label: Text(AppLocalizations.of(context)!.stop),
        ),
        FilledButton.icon(
          onPressed: () async {
            await state.continueCurrent();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.play_arrow),
          label: Text(AppLocalizations.of(context)!.continueLabel),
        ),
      ],
    );
  }
}

class SuspiciousEntryDialog extends StatelessWidget {
  const SuspiciousEntryDialog({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final entry = state.runningEntry;
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.confirmPreviousPeriod),
      content: Text(
        entry == null
            ? AppLocalizations.of(context)!.noRunningActivity
            : AppLocalizations.of(context)!.suspiciousEntryContent(
                TimeOfDay.fromDateTime(entry.startAt).format(context),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            state.ignoreSuspiciousRunning();
            Navigator.pop(context);
          },
          child: Text(AppLocalizations.of(context)!.keepCurrent),
        ),
        FilledButton.icon(
          onPressed: () async {
            await state.correctSuspiciousRunning(DateTime.now());
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.check),
          label: Text(AppLocalizations.of(context)!.endToNow),
        ),
      ],
    );
  }
}

class LoginBanner extends StatelessWidget {
  const LoginBanner({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.isSignedIn) {
      return _StatusBanner(
        icon: state.isSyncing ? Icons.sync : Icons.cloud_done_outlined,
        text: state.isSyncing
            ? AppLocalizations.of(context)!.syncing
            : AppLocalizations.of(context)!.cloudSyncActive,
      );
    }
    if (state.hasLanPeer) {
      return _StatusBanner(
        icon: state.isSyncing ? Icons.sync : Icons.lan_outlined,
        text: state.isSyncing
            ? AppLocalizations.of(context)!.syncing
            : AppLocalizations.of(context)!.lanPeerPaired,
      );
    }
    if (!state.canCloudSync) {
      return _StatusBanner(
        icon: Icons.cloud_off_outlined,
        text: AppLocalizations.of(context)!.localModeHint,
      );
    }
    return LoginPage(state: state);
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
