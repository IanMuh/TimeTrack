import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'adaptive_layout.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return AdaptivePage(
          pageKey: const PageStorageKey('settings-page'),
          maxWidth: 920,
          children: [
            Text(
              '设置',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SectionGap(),
            LayoutBuilder(
              builder: (context, constraints) {
                final expanded = constraints.maxWidth >= expandedBreakpoint;
                final reminder = ReminderSettingsCard(state: state);
                final sync = SyncSettingsCard(state: state);
                if (!expanded) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      reminder,
                      const SectionGap(),
                      sync,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: reminder),
                    const SizedBox(width: 16),
                    Expanded(child: sync),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class ReminderSettingsCard extends StatelessWidget {
  const ReminderSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '轻提醒',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final slider = Slider(
                  min: 15,
                  max: 180,
                  divisions: 11,
                  value: state.settings.reminderMinutes.toDouble(),
                  label: '${state.settings.reminderMinutes} 分钟',
                  onChanged: (value) =>
                      state.updateReminderMinutes(value.round()),
                );
                final label = Text(
                  '${state.settings.reminderMinutes} 分钟',
                  style: Theme.of(context).textTheme.titleMedium,
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications_outlined),
                          const SizedBox(width: 12),
                          label,
                        ],
                      ),
                      slider,
                    ],
                  );
                }
                return Row(
                  children: [
                    const Icon(Icons.notifications_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: slider),
                    SizedBox(width: 80, child: label),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SyncSettingsCard extends StatelessWidget {
  const SyncSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final statusTitle = state.canSync ? 'Supabase 已配置' : 'Supabase 未配置';
    final statusSubtitle = state.isSignedIn ? '已登录' : '未登录或本地模式';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '同步',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  state.canSync
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
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
                    label: const Text('退出'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: state.canSync && state.isSignedIn ? state.sync : null,
              icon: const Icon(Icons.sync),
              label: const Text('立即同步'),
            ),
          ],
        ),
      ),
    );
  }
}
