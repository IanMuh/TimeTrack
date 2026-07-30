import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'adaptive_layout.dart';
import 'app_shell_footer.dart';
import 'app_shell_history_menu.dart';
import 'app_shell_navigation.dart';
import 'app_shell_navigation_rail.dart';
import 'app_shell_shortcuts.dart';
import 'running_timer_bar.dart';
import 'timeline_page.dart';

class AppShellFrame extends StatelessWidget {
  const AppShellFrame({
    required this.state,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.timelineController,
    required this.pages,
    super.key,
  });

  final AppState state;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final TimelinePageController timelineController;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    final sizeClass = adaptiveSizeClassFor(MediaQuery.sizeOf(context).width);
    final showRail = sizeClass != AdaptiveSizeClass.compact;
    final contentBottomInset = shellContentBottomInset(showRail: showRail);
    final destinations = buildAppShellDestinations(context);
    final runningTimerBar = RunningTimerBar(
      state: state,
      onPressed: () => onDestinationSelected(0),
      trailing: showRail
          ? null
          : CompactHistoryMenu(
              state: state,
              dense: true,
            ),
    );

    return Shortcuts(
      shortcuts: appShellShortcuts,
      child: Actions(
        actions: {
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) {
              if (!hasFocusedEditable(context)) {
                unawaited(state.undo());
              }
              return null;
            },
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) {
              if (!hasFocusedEditable(context)) {
                unawaited(state.redo());
              }
              return null;
            },
          ),
          SelectDestinationIntent: CallbackAction<SelectDestinationIntent>(
            onInvoke: (intent) {
              onDestinationSelected(intent.index);
              return null;
            },
          ),
          TimelineAddEntryIntent: CallbackAction<TimelineAddEntryIntent>(
            onInvoke: (_) {
              if (selectedIndex == 1 && !hasFocusedEditable(context)) {
                timelineController.openEntryEditor();
              }
              return null;
            },
          ),
          TimelinePreviousRangeIntent:
              CallbackAction<TimelinePreviousRangeIntent>(
            onInvoke: (_) {
              if (selectedIndex == 1 && !hasFocusedEditable(context)) {
                timelineController.selectPreviousRange();
              }
              return null;
            },
          ),
          TimelineNextRangeIntent: CallbackAction<TimelineNextRangeIntent>(
            onInvoke: (_) {
              if (selectedIndex == 1 && !hasFocusedEditable(context)) {
                timelineController.selectNextRange();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: FocusTraversalGroup(
            child: Scaffold(
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(
                      bottom: contentBottomInset,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        child: Row(
                          children: [
                            if (showRail) ...[
                              DesktopNavigationRail(
                                selectedIndex: selectedIndex,
                                sizeClass: sizeClass,
                                destinations: destinations,
                                onDestinationSelected: onDestinationSelected,
                                historyControls: UndoRedoControls(
                                  state: state,
                                  axis: Axis.horizontal,
                                ),
                              ),
                              const VerticalDivider(width: 1),
                            ],
                            Expanded(
                              child: IndexedStack(
                                index: selectedIndex,
                                children: pages,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ShellFooter(
                        sizeClass: sizeClass,
                        showRail: showRail,
                        runningTimerBar: runningTimerBar,
                        destinations: destinations,
                        selectedIndex: selectedIndex,
                        onDestinationSelected: onDestinationSelected,
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
