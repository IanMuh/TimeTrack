import 'package:flutter/material.dart';

import '../app/app_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '设置',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
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
                    Row(
                      children: [
                        const Icon(Icons.notifications_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Slider(
                            min: 15,
                            max: 180,
                            divisions: 11,
                            value: state.settings.reminderMinutes.toDouble(),
                            label: '${state.settings.reminderMinutes} 分钟',
                            onChanged: (value) =>
                                state.updateReminderMinutes(value.round()),
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: Text('${state.settings.reminderMinutes} 分钟'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
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
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        state.canSync
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                      ),
                      title: Text(state.canSync ? 'Supabase 已配置' : 'Supabase 未配置'),
                      subtitle: Text(
                        state.isSignedIn ? '已登录' : '未登录或本地模式',
                      ),
                      trailing: state.isSignedIn
                          ? TextButton.icon(
                              onPressed: state.signOut,
                              icon: const Icon(Icons.logout),
                              label: const Text('退出'),
                            )
                          : null,
                    ),
                    FilledButton.icon(
                      onPressed:
                          state.canSync && state.isSignedIn ? state.sync : null,
                      icon: const Icon(Icons.sync),
                      label: const Text('立即同步'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
