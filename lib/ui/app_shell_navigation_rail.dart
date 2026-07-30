import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'app_shell_navigation.dart';

class DesktopNavigationRail extends StatelessWidget {
  const DesktopNavigationRail({
    required this.selectedIndex,
    required this.sizeClass,
    required this.destinations,
    required this.onDestinationSelected,
    required this.historyControls,
    super.key,
  });

  final int selectedIndex;
  final AdaptiveSizeClass sizeClass;
  final List<AppShellDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final Widget historyControls;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final railWidth = desktopRailWidth(sizeClass);
    return Container(
      width: railWidth,
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.timer,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'TimeTrack',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  for (final destination in destinations)
                    _DesktopDestinationButton(
                      selected:
                          destinations.indexOf(destination) == selectedIndex,
                      destination: destination,
                      onPressed: () => onDestinationSelected(
                        destinations.indexOf(destination),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.52,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: historyControls,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopDestinationButton extends StatelessWidget {
  const _DesktopDestinationButton({
    required this.selected,
    required this.destination,
    required this.onPressed,
  });

  final bool selected;
  final AppShellDestination destination;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final background = selected
        ? colorScheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: destination.label,
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Semantics(
              button: true,
              selected: selected,
              label: destination.label,
              child: SizedBox(
                height: 36,
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 3,
                      height: selected ? 20 : 12,
                      decoration: BoxDecoration(
                        color:
                            selected ? colorScheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      color: foreground,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              color: foreground,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                            ),
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
  }
}

class UndoRedoControls extends StatelessWidget {
  const UndoRedoControls({
    required this.state,
    this.axis = Axis.horizontal,
    super.key,
  });

  final AppState state;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final undoLabel = state.undoLabel;
        final redoLabel = state.redoLabel;
        return Flex(
          direction: axis,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              tooltip: undoLabel == null
                  ? AppLocalizations.of(context)!.undoHint
                  : AppLocalizations.of(context)!.undoWithLabel(undoLabel),
              onPressed: state.canUndo ? () => unawaited(state.undo()) : null,
              icon: const Icon(Icons.undo),
            ),
            SizedBox(
              width: axis == Axis.horizontal ? 8 : 0,
              height: axis == Axis.vertical ? 8 : 0,
            ),
            IconButton.filledTonal(
              tooltip: redoLabel == null
                  ? AppLocalizations.of(context)!.redoHint
                  : AppLocalizations.of(context)!.redoWithLabel(redoLabel),
              onPressed: state.canRedo ? () => unawaited(state.redo()) : null,
              icon: const Icon(Icons.redo),
            ),
          ],
        );
      },
    );
  }
}

double desktopRailWidth(AdaptiveSizeClass sizeClass) {
  return sizeClass == AdaptiveSizeClass.expanded ? 148.0 : 132.0;
}
