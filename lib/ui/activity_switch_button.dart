import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/activity.dart';
import '../l10n/app_localizations.dart';
import 'activity_switch_button_compact.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 150;
        final colorScheme = Theme.of(context).colorScheme;
        final baseColor = _effectiveActivityColor(
          Color(activity.color),
          colorScheme.brightness,
        );
        final background = selected
            ? baseColor.withValues(
                alpha: colorScheme.brightness == Brightness.dark ? 0.26 : 0.20)
            : pending
                ? baseColor.withValues(alpha: 0.14)
                : colorScheme.surface;
        final borderColor = selected
            ? baseColor.withValues(alpha: 0.70)
            : pending
                ? baseColor.withValues(alpha: 0.46)
                : colorScheme.outlineVariant;
        final foreground = colorScheme.onSurface;
        final compactLabel = pending
            ? AppLocalizations.of(context)!
                .confirmSwitchSemantics(activity.name)
            : selected
                ? AppLocalizations.of(context)!.currentActivitySemantics(
                    activity.name,
                  )
                : AppLocalizations.of(context)!
                    .switchToSemantics(activity.name);
        if (compact) {
          return ActivitySwitchButtonCompact(
            activity: activity,
            selected: selected,
            pending: pending,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onEdit: onEdit,
            baseColor: baseColor,
            background: background,
            borderColor: borderColor,
            foreground: foreground,
            semanticsLabel: compactLabel,
          );
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
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
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: compactLabel,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _Badge(
                          color: baseColor,
                          selected: selected,
                          pending: pending,
                        ),
                        if (pending) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.keyboard_double_arrow_right,
                            size: 16,
                            color: baseColor,
                          ),
                        ],
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            activity.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: foreground,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (activity.isUnassigned)
                          Tooltip(
                            message: AppLocalizations.of(context)!
                                .systemActivityCannotEdit,
                            child: Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: foreground.withValues(alpha: 0.72),
                            ),
                          )
                        else
                          IconButton(
                            tooltip: AppLocalizations.of(context)!.editActivity,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: onEdit,
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _effectiveActivityColor(Color color, Brightness brightness) {
    if (brightness == Brightness.light) {
      return color;
    }
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + 0.16).clamp(0.0, 1.0)).toColor();
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.color,
    required this.selected,
    required this.pending,
  });

  final Color color;
  final bool selected;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 1 : 0.14),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: pending ? 0.80 : 0.40),
        ),
      ),
      child: Icon(
        selected
            ? Icons.radio_button_checked
            : pending
                ? Icons.touch_app_outlined
                : Icons.circle,
        size: 15,
        color: selected ? Colors.white : color,
      ),
    );
  }
}
