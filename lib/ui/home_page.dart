import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../core/date_time_ext.dart';
import '../domain/activity.dart';
import 'activity_colors.dart';
import 'app_shell.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.state, super.key});

  final AppState state;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _pendingActivityId;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final runningActivity = state.runningActivity;
        final pendingActivity = _pendingActivityId == null
            ? null
            : state.activityById(_pendingActivityId!);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TimeTrack',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: '同步',
                  onPressed: state.canSync && state.isSignedIn ? state.sync : null,
                  icon: const Icon(Icons.sync),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LoginBanner(state: state),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前正在做',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      runningActivity?.name ?? '未开始记录',
                      style:
                          Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      runningActivity == null
                          ? '选择一个事项开始记录今天的时间。'
                          : '已持续 ${formatDurationCompact(state.runningDuration)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed:
                          runningActivity == null ? null : state.stopCurrent,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('停止当前事项'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '切换',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (pendingActivity != null &&
                pendingActivity.id != runningActivity?.id) ...[
              const SizedBox(height: 6),
              Text(
                '已选择 ${pendingActivity.name}，双击事项按钮后切换。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: constraints.maxWidth >= 760 ? 3.4 : 2.4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    for (final activity in state.activities)
                      ActivitySwitchButton(
                        activity: activity,
                        selected: runningActivity?.id == activity.id,
                        pending: _pendingActivityId == activity.id &&
                            runningActivity?.id != activity.id,
                        onTap: () {
                          setState(() => _pendingActivityId = activity.id);
                        },
                        onDoubleTap: () async {
                          setState(() => _pendingActivityId = activity.id);
                          await state.switchTo(activity);
                        },
                        onEdit: () => showActivityEditorDialog(
                          context,
                          state,
                          activity: activity,
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => showActivityEditorDialog(context, state),
                      icon: const Icon(Icons.add),
                      label: const Text('新增事项'),
                    ),
                  ],
                );
              },
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 18),
              Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        );
      },
    );
  }
}

class ActivitySwitchButton extends StatelessWidget {
  const ActivitySwitchButton({
    required this.activity,
    required this.selected,
    required this.pending,
    required this.onTap,
    required this.onDoubleTap,
    required this.onEdit,
    super.key,
  });

  final Activity activity;
  final bool selected;
  final bool pending;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final color = Color(activity.color);
    final active = selected || pending;
    return Material(
      color: selected ? color : color.withValues(alpha: pending ? 0.20 : 0.10),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : pending
                        ? Icons.touch_app_outlined
                        : Icons.circle,
                color: selected ? Colors.white : color,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activity.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (pending)
                Icon(
                  Icons.keyboard_double_arrow_right,
                  color: color,
                  size: 18,
                ),
              IconButton(
                tooltip: '编辑事项',
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit_outlined,
                  color: active && selected ? Colors.white : color,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<Activity?> showActivityEditorDialog(
  BuildContext context,
  AppState state, {
  Activity? activity,
}) async {
  final controller = TextEditingController(text: activity?.name ?? '');
  var selectedColor = activity?.color ?? 0xff2563eb;
  Activity? saved;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(activity == null ? '新增事项' : '编辑事项'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final color in activityPalette)
                      IconButton(
                        tooltip: '选择颜色',
                        onPressed: () => setState(() => selectedColor = color),
                        icon: Icon(
                          selectedColor == color
                              ? Icons.check_circle
                              : Icons.circle,
                          color: Color(color),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              if (activity != null)
                TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('删除事项'),
                        content: Text(
                          '确定删除“${activity.name}”吗？已有时间记录会保留，但之后不能再选择这个事项。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          FilledButton.icon(
                            onPressed: () => Navigator.pop(context, true),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) {
                      return;
                    }
                    await state.deleteActivity(activity);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) {
                    return;
                  }
                  saved = activity == null
                      ? await state.createActivity(controller.text, selectedColor)
                      : await state.updateActivity(
                          activity,
                          name: controller.text,
                          color: selectedColor,
                        );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: Icon(activity == null ? Icons.add : Icons.save_outlined),
                label: Text(activity == null ? '创建' : '保存'),
              ),
            ],
          );
        },
      );
    },
  );
  return saved;
}
