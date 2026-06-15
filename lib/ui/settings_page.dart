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
                final cloudSync = CloudSyncSettingsCard(state: state);
                final interop = InteropSettingsCard(state: state);
                if (!expanded) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      reminder,
                      const SectionGap(),
                      cloudSync,
                      const SectionGap(),
                      interop,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: reminder),
                        const SizedBox(width: 16),
                        Expanded(child: cloudSync),
                      ],
                    ),
                    const SectionGap(),
                    interop,
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
              '提醒',
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

class CloudSyncSettingsCard extends StatelessWidget {
  const CloudSyncSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final statusTitle = state.canCloudSync ? 'Supabase 已配置' : 'Supabase 未配置';
    final statusSubtitle = state.isSignedIn ? '已登录' : '未登录或本地模式';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '云同步',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  state.canCloudSync
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
              onPressed:
                  state.canCloudSync && state.isSignedIn ? state.sync : null,
              icon: const Icon(Icons.sync),
              label: const Text('立即同步'),
            ),
          ],
        ),
      ),
    );
  }
}

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设备互通',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final expanded = constraints.maxWidth >= expandedBreakpoint;
                final host = _LanHostPanel(state: state);
                final client = _LanClientPanel(
                  state: state,
                  addressController: _addressController,
                  codeController: _codeController,
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: state.importInteropFile,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('导入文件'),
                ),
                OutlinedButton.icon(
                  onPressed: state.exportInteropFile,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('导出文件'),
                ),
                FilledButton.icon(
                  onPressed: state.hasSyncTarget && !state.isSyncing
                      ? state.sync
                      : null,
                  icon: const Icon(Icons.sync),
                  label: Text(state.isSyncing ? '同步中' : '立即同步'),
                ),
              ],
            ),
            if (state.interopMessage != null) ...[
              const SizedBox(height: 12),
              Text(state.interopMessage!),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanHostPanel extends StatelessWidget {
  const _LanHostPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.router_outlined),
            const SizedBox(width: 8),
            Text(
              '局域网主机',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          !state.canHostLan
              ? 'v1 默认 Windows 作为局域网主机；Android 作为客户端连接电脑。'
              : state.isLanServerRunning
                  ? '在 Android 上输入下方地址和配对码。'
                  : '开启后，其他设备可在同一 Wi-Fi 内配对。',
        ),
        if (state.isLanServerRunning) ...[
          const SizedBox(height: 10),
          SelectableText(
            state.lanServerUrls.isEmpty
                ? 'http://127.0.0.1'
                : state.lanServerUrls.join('\n'),
          ),
          const SizedBox(height: 10),
          Text(
            '配对码：${state.lanPairingCode ?? ''}',
            style: Theme.of(context).textTheme.titleMedium,
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
                ? '仅 Windows 可开启'
                : state.isLanServerRunning
                    ? '关闭主机'
                    : '开启主机',
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
        Row(
          children: [
            const Icon(Icons.phone_android_outlined),
            const SizedBox(width: 8),
            Text(
              '连接局域网主机',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (peer != null) ...[
          Text('已配对：${peer.displayName}'),
          if (peer.baseUrl != null) Text(peer.baseUrl!),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: state.clearLanPeer,
            icon: const Icon(Icons.link_off_outlined),
            label: const Text('移除配对'),
          ),
        ] else ...[
          TextField(
            controller: addressController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '主机地址',
              hintText: '192.168.1.10:8787',
              prefixIcon: Icon(Icons.link_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '配对码',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => state.pairLanPeer(
              baseUrl: addressController.text,
              code: codeController.text,
            ),
            icon: const Icon(Icons.link_outlined),
            label: const Text('配对并同步'),
          ),
        ],
      ],
    );
  }
}
