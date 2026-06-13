import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'timeline_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.state, super.key});

  final AppState state;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _reminderVisible = false;
  bool _suspiciousVisible = false;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_showPassivePrompts);
  }

  @override
  void dispose() {
    widget.state.removeListener(_showPassivePrompts);
    super.dispose();
  }

  void _showPassivePrompts() {
    if (!mounted) {
      return;
    }
    if (widget.state.shouldShowReminder && !_reminderVisible) {
      _reminderVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await showDialog<void>(
          context: context,
          builder: (context) => ReminderDialog(state: widget.state),
        );
        _reminderVisible = false;
      });
    }
    if (widget.state.hasSuspiciousRunningEntry && !_suspiciousVisible) {
      _suspiciousVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await showDialog<void>(
          context: context,
          builder: (context) => SuspiciousEntryDialog(state: widget.state),
        );
        _suspiciousVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = [
      HomePage(state: state),
      TimelinePage(state: state),
      StatsPage(state: state),
      SettingsPage(state: state),
    ];

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (MediaQuery.sizeOf(context).width >= 820)
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) => setState(() => _index = value),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.timer_outlined),
                    selectedIcon: Icon(Icons.timer),
                    label: Text('当前'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.view_timeline_outlined),
                    selectedIcon: Icon(Icons.view_timeline),
                    label: Text('时间轴'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: Text('统计'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: Text('设置'),
                  ),
                ],
              ),
            Expanded(child: pages[_index]),
          ],
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 820
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.timer_outlined),
                  selectedIcon: Icon(Icons.timer),
                  label: '当前',
                ),
                NavigationDestination(
                  icon: Icon(Icons.view_timeline_outlined),
                  selectedIcon: Icon(Icons.view_timeline),
                  label: '时间轴',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: '统计',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '设置',
                ),
              ],
            )
          : null,
    );
  }
}

class ReminderDialog extends StatelessWidget {
  const ReminderDialog({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('还在做这件事吗？'),
      content: Text('当前事项已持续 ${state.runningDuration.inMinutes} 分钟。'),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await state.snoozeReminder();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.snooze),
          label: const Text('稍后提醒'),
        ),
        TextButton.icon(
          onPressed: () async {
            await state.stopCurrent();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('停止'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await state.continueCurrent();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('继续'),
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
      title: const Text('需要确认上一段时间'),
      content: Text(
        entry == null
            ? '没有正在进行的事项。'
            : '当前事项从 ${TimeOfDay.fromDateTime(entry.startAt).format(context)} 开始，持续时间偏长。可以先结束到当前时间，再补记中间内容。',
      ),
      actions: [
        TextButton(
          onPressed: () {
            state.ignoreSuspiciousRunning();
            Navigator.pop(context);
          },
          child: const Text('继续保留'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await state.correctSuspiciousRunning(DateTime.now());
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.check),
          label: const Text('结束到现在'),
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
    if (!state.canSync) {
      return const _StatusBanner(
        icon: Icons.cloud_off_outlined,
        text: '本地模式：配置 Supabase 后可开启多设备同步',
      );
    }
    if (!state.isSignedIn) {
      return LoginPage(state: state);
    }
    return _StatusBanner(
      icon: state.isSyncing ? Icons.sync : Icons.cloud_done_outlined,
      text: state.isSyncing ? '正在同步' : '已登录并开启云同步',
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
