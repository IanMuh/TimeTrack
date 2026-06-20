import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../domain/profile_settings.dart';
import 'adaptive_layout.dart';
import 'app_theme.dart';
import 'interop_message_panel.dart';
import 'ui_components.dart';

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
            const PageHeader(
              title: '设置',
              subtitle: '提醒、同步和设备互通都保持本地优先。',
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

class ReminderSettingsCard extends StatefulWidget {
  const ReminderSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  State<ReminderSettingsCard> createState() => _ReminderSettingsCardState();
}

class _ReminderSettingsCardState extends State<ReminderSettingsCard> {
  double? _draftReminderMinutes;
  double? _draftIntervalMinutes;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final settings = state.settings;
    final reminderMinutes =
        (_draftReminderMinutes ?? settings.reminderMinutes.toDouble()).round();
    final intervalMinutes =
        (_draftIntervalMinutes ?? settings.reminderIntervalMinutes.toDouble())
            .round();
    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: '提醒',
            subtitle: '用轻提示确认长时间运行的事项。',
            icon: Icons.notifications_outlined,
          ),
          const SizedBox(height: 14),
          _ReminderField(
            icon: Icons.schedule_outlined,
            label: '触发时间',
            value: _formatReminderTime(
              context,
              settings.reminderTimeOfDayMinutes,
            ),
            child: _ReminderTimeButton(
              value: settings.reminderTimeOfDayMinutes,
              onChanged: (value) => state.updateReminderSettings(
                reminderTimeOfDayMinutes: value,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ReminderField(
            icon: Icons.notifications_outlined,
            label: '持续时间',
            value: '$reminderMinutes 分钟',
            child: Slider(
              min: 15,
              max: 180,
              divisions: 11,
              value: reminderMinutes.toDouble(),
              label: '$reminderMinutes 分钟',
              onChanged: (value) =>
                  setState(() => _draftReminderMinutes = value),
              onChangeEnd: (value) {
                _draftReminderMinutes = null;
                state.updateReminderSettings(reminderMinutes: value.round());
              },
            ),
          ),
          const SizedBox(height: 12),
          _ReminderField(
            icon: Icons.timelapse_outlined,
            label: '间隔',
            value: _formatInterval(intervalMinutes),
            child: Slider(
              min: 5,
              max: 60,
              divisions: 11,
              value: intervalMinutes.toDouble(),
              label: _formatInterval(intervalMinutes),
              onChanged: (value) =>
                  setState(() => _draftIntervalMinutes = value),
              onChangeEnd: (value) {
                _draftIntervalMinutes = null;
                state.updateReminderSettings(
                  reminderIntervalMinutes: value.round(),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _ReminderField(
            icon: Icons.notification_add_outlined,
            label: '方式',
            value: _formatMethod(settings.reminderMethod),
            child: SegmentedButton<ReminderMethod>(
              segments: const [
                ButtonSegment(
                  value: ReminderMethod.dialog,
                  icon: Icon(Icons.chat_bubble_outline),
                  label: Text('对话框'),
                ),
                ButtonSegment(
                  value: ReminderMethod.banner,
                  icon: Icon(Icons.drafts_outlined),
                  label: Text('横幅'),
                ),
                ButtonSegment(
                  value: ReminderMethod.silent,
                  icon: Icon(Icons.notifications_off_outlined),
                  label: Text('静默'),
                ),
              ],
              selected: {settings.reminderMethod},
              onSelectionChanged: (value) => state.updateReminderSettings(
                reminderMethod: value.first,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderField extends StatelessWidget {
  const _ReminderField({
    required this.icon,
    required this.label,
    required this.value,
    required this.child,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ReminderTimeButton extends StatelessWidget {
  const _ReminderTimeButton({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final hours = value ~/ 60;
    final minutes = value % 60;
    final text = TimeOfDay(hour: hours, minute: minutes).format(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: hours, minute: minutes),
          );
          if (picked != null) {
            onChanged(picked.hour * 60 + picked.minute);
          }
        },
        icon: const Icon(Icons.schedule),
        label: Text(text),
      ),
    );
  }
}

String _formatReminderTime(BuildContext context, int minutes) {
  final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  return time.format(context);
}

String _formatInterval(int minutes) => '$minutes 分钟';

String _formatMethod(ReminderMethod method) {
  return switch (method) {
    ReminderMethod.dialog => '对话框',
    ReminderMethod.banner => '横幅',
    ReminderMethod.silent => '静默',
  };
}

class CloudSyncSettingsCard extends StatelessWidget {
  const CloudSyncSettingsCard({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final statusTitle = state.canCloudSync ? 'Supabase 已配置' : 'Supabase 未配置';
    final statusSubtitle = state.isSignedIn ? '已登录' : '未登录或本地模式';
    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: '云同步',
            subtitle: '未配置 Supabase 时应用继续以本地模式运行。',
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
                    : TimeTrackTheme.secondary,
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

    return QuietPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: '设备互通',
            subtitle: '同一 Wi-Fi 下可通过局域网或文件互通数据。',
            icon: Icons.devices_other_outlined,
          ),
          const SizedBox(height: 14),
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
                onPressed:
                    state.hasSyncTarget && !state.isSyncing ? state.sync : null,
                icon: const Icon(Icons.sync),
                label: Text(state.isSyncing ? '同步中' : '立即同步'),
              ),
            ],
          ),
          if (state.interopMessage != null) ...[
            const SizedBox(height: 12),
            InteropMessagePanel(message: state.interopMessage!),
          ],
        ],
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
        SectionTitle(
          title: '局域网主机',
          subtitle: state.isLanServerRunning ? '正在等待同网段设备连接。' : null,
          icon: Icons.router_outlined,
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          StatusPill(
            label: '配对码：${state.lanPairingCode ?? ''}',
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
        const SectionTitle(
          title: '连接局域网主机',
          subtitle: '输入地址和配对码后会立即尝试同步。',
          icon: Icons.phone_android_outlined,
        ),
        const SizedBox(height: 8),
        if (peer != null) ...[
          StatusPill(
            label: '已配对：${peer.displayName}',
            icon: Icons.link_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
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
