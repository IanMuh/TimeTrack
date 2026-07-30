import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/activity.dart';

class ActivitySwitchButtonCompact extends StatelessWidget {
  const ActivitySwitchButtonCompact({
    required this.activity,
    required this.selected,
    required this.pending,
    required this.onTap,
    required this.onDoubleTap,
    required this.onEdit,
    required this.baseColor,
    required this.background,
    required this.borderColor,
    required this.foreground,
    required this.semanticsLabel,
    super.key,
  });

  final Activity activity;
  final bool selected;
  final bool pending;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onEdit;
  final Color baseColor;
  final Color background;
  final Color borderColor;
  final Color foreground;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    final tintBackground = selected || pending
        ? background
        : baseColor.withValues(alpha: dark ? 0.18 : 0.11);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      constraints: const BoxConstraints(minHeight: 38),
      decoration: BoxDecoration(
        color: tintBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: selected ? 1.3 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
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
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onLongPress: activity.isUnassigned ? null : onEdit,
            child: Semantics(
              button: true,
              selected: selected,
              label: semanticsLabel,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CompactBadge(
                      color: baseColor,
                      selected: selected,
                      pending: pending,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        activity.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (pending) ...[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_double_arrow_right,
                        size: 13,
                        color: baseColor,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactBadge extends StatelessWidget {
  const _CompactBadge({
    required this.color,
    required this.selected,
    required this.pending,
  });

  final Color color;
  final bool selected;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return Icon(
      selected
          ? Icons.radio_button_checked
          : pending
              ? Icons.touch_app_outlined
              : Icons.circle,
      size: 18,
      color: color,
    );
  }
}
