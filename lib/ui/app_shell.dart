import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'adaptive_layout.dart';
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
  bool _reminderBannerVisible = false;
  bool _suspiciousVisible = false;

  static const _destinations = [
    _AppDestination(
      label: '当前',
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer,
    ),
    _AppDestination(
      label: '时间线',
      icon: Icons.view_timeline_outlined,
      selectedIcon: Icons.view_timeline,
    ),
    _AppDestination(
      label: '统计',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
    ),
    _AppDestination(
      label: '设置',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

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
    if (widget.state.shouldShowReminderDialog && !_reminderVisible) {
      _reminderVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await showDialog<void>(
          context: context,
          builder: (context) => ReminderDialog(state: widget.state),
        );
        _reminderVisible = false;
      });
    }
    if (widget.state.shouldShowReminderBanner && !_reminderBannerVisible) {
      _reminderBannerVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        messenger
            .showSnackBar(
              SnackBar(
                content: Text(
                  '当前事项已持续 ${widget.state.runningDuration.inMinutes} 分钟。',
                ),
                action: SnackBarAction(
                  label: '稍后提醒',
                  onPressed: () => widget.state.snoozeReminder(),
                ),
              ),
            )
            .closed
            .whenComplete(() {
          if (mounted) {
            _reminderBannerVisible = false;
          }
        });
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

    final sizeClass = adaptiveSizeClassFor(MediaQuery.sizeOf(context).width);
    final showRail = sizeClass == AdaptiveSizeClass.expanded;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (showRail) ...[
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                labelType: NavigationRailLabelType.all,
                minWidth: 88,
                groupAlignment: -0.85,
                destinations: [
                  for (final destination in _destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: Text(destination.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
            ],
            Expanded(child: pages[_index]),
          ],
        ),
      ),
      bottomNavigationBar: showRail
          ? null
          : SafeArea(
              top: false,
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: [
                  for (final destination in _destinations)
                    NavigationDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: destination.label,
                    ),
                ],
              ),
            ),
    );
  }
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
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
    if (state.isSignedIn) {
      return _StatusBanner(
        icon: state.isSyncing ? Icons.sync : Icons.cloud_done_outlined,
        text: state.isSyncing ? '正在同步' : '已登录并开启云同步',
      );
    }
    if (state.hasLanPeer) {
      return _StatusBanner(
        icon: state.isSyncing ? Icons.sync : Icons.lan_outlined,
        text: state.isSyncing ? '正在同步' : '已配对局域网主机',
      );
    }
    if (!state.canCloudSync) {
      return const _StatusBanner(
        icon: Icons.cloud_off_outlined,
        text: '本地模式：可在设置中开启局域网互通或导入导出',
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
