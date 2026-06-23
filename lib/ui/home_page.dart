import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../core/date_time_ext.dart';
import '../domain/activity.dart';
import 'adaptive_layout.dart';
import 'activity_colors.dart';
import 'app_shell.dart';
import 'app_theme.dart';
import 'ui_components.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.state, super.key});

  final AppState state;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _pendingActivityId;

  Future<void> _confirmOrSwitch(Activity activity) async {
    if (_pendingActivityId != activity.id) {
      setState(() => _pendingActivityId = activity.id);
      return;
    }
    setState(() => _pendingActivityId = activity.id);
    await widget.state.switchTo(activity);
    if (mounted) {
      setState(() => _pendingActivityId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final runningActivity = state.runningActivity;
        final switchableActivities = state.activities.where(
          (activity) => !activity.isUnassigned && !activity.isOneOff,
        );
        final pendingActivity = _pendingActivityId == null
            ? null
            : state.activityById(_pendingActivityId!);
        return AdaptivePage(
          pageKey: const PageStorageKey('home-page'),
          children: [
            PageHeader(
              title: 'TimeTrack',
              subtitle: '离线优先记录，按下一个事项就开始。',
              trailing: StatusPill(
                label: state.hasSyncTarget ? '可同步' : '本地模式',
                icon: state.hasSyncTarget
                    ? Icons.cloud_done_outlined
                    : Icons.offline_bolt_outlined,
                color: state.hasSyncTarget
                    ? Theme.of(context).colorScheme.primary
                    : TimeTrackTheme.secondary,
              ),
            ),
            const SectionGap(),
            LayoutBuilder(
              builder: (context, constraints) {
                final sizeClass = adaptiveSizeClassFor(constraints.maxWidth);
                final statusCard = CurrentStatusCard(
                  runningActivity: runningActivity,
                  runningDuration: state.runningDuration,
                  onStop: runningActivity == null ? null : state.stopCurrent,
                );
                if (sizeClass == AdaptiveSizeClass.compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LoginBanner(state: state),
                      const SectionGap(),
                      statusCard,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: statusCard),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: LoginBanner(state: state)),
                  ],
                );
              },
            ),
            const SectionGap(height: 18),
            PageHeader(
              title: '快捷切换',
              subtitle: pendingActivity == null ||
                      pendingActivity.id == runningActivity?.id
                  ? '轻点选择，再点一次确认切换。'
                  : '已选择 ${pendingActivity.name}，再次点击后切换。',
              trailing: IconButton.filledTonal(
                tooltip: '同步',
                onPressed: state.hasSyncTarget ? state.sync : null,
                icon: const Icon(Icons.sync),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < compactBreakpoint;
                final tileExtent = compact ? 190.0 : 250.0;
                return GridView.extent(
                  maxCrossAxisExtent: tileExtent,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: compact ? 2.1 : 3.15,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    for (final activity in switchableActivities)
                      ActivitySwitchButton(
                        activity: activity,
                        selected: runningActivity?.id == activity.id,
                        pending: _pendingActivityId == activity.id &&
                            runningActivity?.id != activity.id,
                        onTap: () => _confirmOrSwitch(activity),
                        onDoubleTap: () => _confirmOrSwitch(activity),
                        onEdit: activity.isUnassigned
                            ? null
                            : () => showActivityEditorDialog(
                                  context,
                                  state,
                                  activity: activity,
                                ),
                      ),
                    _OneOffActivityTile(
                      onPressed: () => showOneOffActivityDialog(context, state),
                    ),
                    _AddActivityTile(
                      onPressed: () => showActivityEditorDialog(context, state),
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

class CurrentStatusCard extends StatelessWidget {
  const CurrentStatusCard({
    required this.runningActivity,
    required this.runningDuration,
    required this.onStop,
    super.key,
  });

  final Activity? runningActivity;
  final Duration runningDuration;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final runningColor = runningActivity == null
        ? colorScheme.primary
        : Color(runningActivity!.color);
    return QuietPanel(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  icon: runningActivity == null
                      ? Icons.timer_outlined
                      : Icons.play_arrow_rounded,
                  color: runningColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '当前正在做',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                StatusPill(
                  label: runningActivity == null ? '未开始' : '记录中',
                  icon: runningActivity == null
                      ? Icons.pause_circle_outline
                      : Icons.radio_button_checked,
                  color: runningColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              runningActivity?.name ?? '未开始记录',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              runningActivity == null
                  ? '选择一个事项开始记录今天的时间。'
                  : '已持续 ${formatDurationCompact(runningDuration)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('停止当前事项'),
            ),
          ],
        ),
      ),
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
  final VoidCallback? onDoubleTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final color = Color(activity.color);
    final active = selected || pending;
    final foreground = selected ? Colors.white : color;
    return Material(
      color: selected ? color : color.withValues(alpha: pending ? 0.16 : 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active
              ? color.withValues(alpha: selected ? 0.0 : 0.42)
              : color.withValues(alpha: 0.18),
          width: pending ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          child: Semantics(
            button: true,
            selected: selected,
            label: pending
                ? '确认切换到${activity.name}'
                : selected
                    ? '当前事项${activity.name}'
                    : '切换到${activity.name}',
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
                    color: foreground,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      activity.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (pending)
                    Icon(
                      Icons.keyboard_double_arrow_right,
                      color: foreground,
                      size: 18,
                    ),
                  if (activity.isUnassigned)
                    SizedBox.square(
                      dimension: 40,
                      child: Tooltip(
                        message: '系统事项，不能编辑',
                        child: Icon(
                          Icons.lock_outline,
                          color: foreground.withValues(alpha: 0.72),
                          size: 18,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: '编辑事项',
                      visualDensity: VisualDensity.compact,
                      onPressed: onEdit,
                      icon: Icon(
                        Icons.edit_outlined,
                        color: foreground,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OneOffActivityTile extends StatelessWidget {
  const _OneOffActivityTile({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.flash_on_outlined),
      label: const Text('临时事项'),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _AddActivityTile extends StatelessWidget {
  const _AddActivityTile({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: const Text('新增事项'),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
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
  if (activity?.isUnassigned ?? false) {
    return activity;
  }
  final controller = TextEditingController(text: activity?.name ?? '');
  var selectedColor = activity?.color ??
      nextActivityColor(state.activities.map((activity) => activity.color));
  Activity? saved;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(activity == null ? '新增事项' : '编辑事项'),
            content: SizedBox(
              width: _dialogContentWidth(context, maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    ActivityColorPicker(
                      selectedColor: selectedColor,
                      onColorChanged: (color) =>
                          setState(() => selectedColor = color),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (activity != null && !activity.isUnassigned)
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
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    return;
                  }
                  saved = activity == null
                      ? await state.createActivity(
                          name,
                          selectedColor,
                        )
                      : await state.updateActivity(
                          activity,
                          name: name,
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

Future<Activity?> showOneOffActivityDialog(
  BuildContext context,
  AppState state,
) async {
  final suggestions = await state.oneOffActivitySuggestions();
  if (!context.mounted) {
    return null;
  }
  final controller = TextEditingController();
  var selectedColor =
      nextActivityColor(state.activities.map((activity) => activity.color));
  Activity? selectedSuggestion;
  Activity? saved;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final query = controller.text.trim().toLowerCase();
          final filteredSuggestions = query.isEmpty
              ? <Activity>[]
              : [
                  for (final activity in suggestions)
                    if (activity.name.toLowerCase().contains(query)) activity,
                ];
          return AlertDialog(
            title: const Text('临时事项'),
            content: SizedBox(
              width: _dialogContentWidth(context, maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: '名称',
                        prefixIcon: Icon(Icons.bolt_outlined),
                      ),
                      onChanged: (_) {
                        setState(() => selectedSuggestion = null);
                      },
                      autofocus: true,
                    ),
                    if (filteredSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final activity in filteredSuggestions)
                              ChoiceChip(
                                avatar: Icon(
                                  Icons.bolt_outlined,
                                  size: 18,
                                  color: Color(activity.color),
                                ),
                                label: _OneOffSuggestionLabel(
                                  name: activity.name,
                                ),
                                selected: selectedSuggestion?.id == activity.id,
                                onSelected: (_) {
                                  setState(() {
                                    selectedSuggestion = activity;
                                    selectedColor = activity.color;
                                    controller.text = activity.name;
                                    controller.selection =
                                        TextSelection.collapsed(
                                      offset: controller.text.length,
                                    );
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ActivityColorPicker(
                      selectedColor: selectedColor,
                      onColorChanged: (color) => setState(() {
                        selectedSuggestion = null;
                        selectedColor = color;
                      }),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    return;
                  }
                  saved = await state.createOneOffActivity(
                    name,
                    selectedColor,
                    reuseActivity: selectedSuggestion,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('开始'),
              ),
            ],
          );
        },
      );
    },
  );
  return saved;
}

class _OneOffSuggestionLabel extends StatelessWidget {
  const _OneOffSuggestionLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '单次',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
          ),
        ),
      ],
    );
  }
}

double _dialogContentWidth(
  BuildContext context, {
  required double maxWidth,
}) {
  final availableWidth = MediaQuery.sizeOf(context).width - 128;
  return availableWidth.clamp(0, maxWidth).toDouble();
}

class ActivityColorPicker extends StatelessWidget {
  const ActivityColorPicker({
    required this.selectedColor,
    required this.onColorChanged,
    super.key,
  });

  final int selectedColor;
  final ValueChanged<int> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final color = Color(selectedColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final colorValue in activityPalette)
              IconButton(
                tooltip: '选择颜色 ${_formatHexColor(colorValue)}',
                onPressed: () => onColorChanged(colorValue),
                icon: Icon(
                  selectedColor == colorValue
                      ? Icons.check_circle
                      : Icons.circle,
                  color: Color(colorValue),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tune),
          title: const Text('RGB 调色'),
          subtitle: Text(_formatHexColor(selectedColor)),
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatHexColor(selectedColor),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RgbChannelControl(
              label: 'R',
              value: _redOf(selectedColor),
              color: Colors.red,
              onChanged: (value) => onColorChanged(
                _withRgb(selectedColor, red: value),
              ),
            ),
            _RgbChannelControl(
              label: 'G',
              value: _greenOf(selectedColor),
              color: Colors.green,
              onChanged: (value) => onColorChanged(
                _withRgb(selectedColor, green: value),
              ),
            ),
            _RgbChannelControl(
              label: 'B',
              value: _blueOf(selectedColor),
              color: Colors.blue,
              onChanged: (value) => onColorChanged(
                _withRgb(selectedColor, blue: value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RgbChannelControl extends StatefulWidget {
  const _RgbChannelControl({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  State<_RgbChannelControl> createState() => _RgbChannelControlState();
}

class _RgbChannelControlState extends State<_RgbChannelControl> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant _RgbChannelControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value.toString()) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final slider = Slider(
          label: '${widget.label} ${widget.value}',
          min: 0,
          max: 255,
          divisions: 255,
          value: widget.value.toDouble(),
          activeColor: widget.color,
          onChanged: (value) => widget.onChanged(value.round()),
        );
        final input = SizedBox(
          width: 86,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: Icon(Icons.tag, color: widget.color),
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed == null) {
                return;
              }
              widget.onChanged(parsed.clamp(0, 255));
            },
          ),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              input,
              slider,
            ],
          );
        }
        return Row(
          children: [
            input,
            const SizedBox(width: 12),
            Expanded(child: slider),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

String _formatHexColor(int color) {
  final rgb = color & 0x00ffffff;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

int _redOf(int color) => (color >> 16) & 0xff;

int _greenOf(int color) => (color >> 8) & 0xff;

int _blueOf(int color) => color & 0xff;

int _withRgb(
  int color, {
  int? red,
  int? green,
  int? blue,
}) {
  final nextRed = (red ?? _redOf(color)).clamp(0, 255).toInt();
  final nextGreen = (green ?? _greenOf(color)).clamp(0, 255).toInt();
  final nextBlue = (blue ?? _blueOf(color)).clamp(0, 255).toInt();
  return 0xff000000 | (nextRed << 16) | (nextGreen << 8) | nextBlue;
}
