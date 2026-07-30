import 'package:flutter/material.dart';

import 'adaptive_layout.dart';
import 'app_shell_navigation.dart';
import 'app_shell_navigation_rail.dart';

const shellDesktopFooterHeight = 52.0;
const shellCompactFooterHeight = 116.0;
const shellDesktopFooterSafeGap = 0.0;
const shellCompactFooterSafeGap = 0.0;

double shellContentBottomInset({required bool showRail}) {
  return showRail
      ? shellDesktopFooterHeight + shellDesktopFooterSafeGap
      : shellCompactFooterHeight + shellCompactFooterSafeGap;
}

class ShellFooter extends StatelessWidget {
  const ShellFooter({
    required this.sizeClass,
    required this.showRail,
    required this.runningTimerBar,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final AdaptiveSizeClass sizeClass;
  final bool showRail;
  final Widget runningTimerBar;
  final List<AppShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    if (showRail) {
      return SizedBox(
        height: shellDesktopFooterHeight,
        child: Row(
          children: [
            SizedBox(
              width: desktopRailWidth(sizeClass) + 1,
              height: shellDesktopFooterHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: runningTimerBar),
          ],
        ),
      );
    }

    return SizedBox(
      height: shellCompactFooterHeight,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: NavigationBar(
              height: 64,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
          ),
          runningTimerBar,
        ],
      ),
    );
  }
}
