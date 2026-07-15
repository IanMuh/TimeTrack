import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/activity.dart';
import '../l10n/app_localizations.dart';

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
        borderRadius: BorderRadius.circular(10),
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
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          child: Semantics(
            button: true,
            selected: selected,
            label: pending
                ? AppLocalizations.of(context)!
                    .confirmSwitchSemantics(activity.name)
                : selected
                    ? AppLocalizations.of(context)!
                        .currentActivitySemantics(activity.name)
                    : AppLocalizations.of(context)!
                        .switchToSemantics(activity.name),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      dimension: 36,
                      child: Tooltip(
                        message: AppLocalizations.of(context)!
                            .systemActivityCannotEdit,
                        child: Icon(
                          Icons.lock_outline,
                          color: foreground.withValues(alpha: 0.72),
                          size: 18,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.editActivity,
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
