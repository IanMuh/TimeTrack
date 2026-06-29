import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../core/date_time_ext.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'timeline_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.state, super.key});

  final AppState state;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _reminderVisible = false;
  bool _reminderBannerVisible = false;
  bool _suspiciousVisible = false;
  final _timelineController = TimelinePageController();
  late final List<Widget> _pages;

  List<_AppDestination> _buildDestinations(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      _AppDestination(
        label: l10n.navCurrent,
        icon: Icons.timer_outlined,
        selectedIcon: Icons.timer,
      ),
      _AppDestination(
        label: l10n.navTimeline,
        icon: Icons.view_timeline_outlined,
        selectedIcon: Icons.view_timeline,
      ),
      _AppDestination(
        label: l10n.navStats,
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
      ),
      _AppDestination(
        label: l10n.navSettings,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(state: widget.state),
      TimelinePage(state: widget.state, controller: _timelineController),
      StatsPage(state: widget.state),
      SettingsPage(state: widget.state),
    ];
    widget.state.addListener(_showPassivePrompts);
  }

  @override
  void dispose() {
    widget.state.removeListener(_showPassivePrompts);
    super.dispose();
  }

  void _showPassivePrompts() {
    if (!mounted) {
      return;
    }
    if (widget.state.shouldShowReminderDialog && !_reminderVisible) {
      _reminderVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await showDialog<void>(
          context: context,
          builder: (context) => ReminderDialog(state: widget.state),
        );
        _reminderVisible = false;
      });
    }
    if (widget.state.shouldShowUpdatePrompt) {
      final update = widget.state.availableUpdate!;
      widget.state.markUpdatePromptShown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .updateAvailablePrompt(update.latestVersion.toString()),
            ),
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.viewInSettings,
              onPressed: () => _selectDestination(3),
            ),
          ),
        );
      });
    }
    if (widget.state.shouldShowReminderBanner && !_reminderBannerVisible) {
      _reminderBannerVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        messenger
            .showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.activityRunningMinutes(
                      widget.state.runningDuration().inMinutes),
                ),
                action: SnackBarAction(
                  label: AppLocalizations.of(context)!.remindLater,
                  onPressed: () => widget.state.snoozeReminder(),
                ),
              ),
            )
            .closed
            .whenComplete(() {
          if (mounted) {
            _reminderBannerVisible = false;
          }
        });
      });
    }
    if (widget.state.hasSuspiciousRunningEntry && !_suspiciousVisible) {
      _suspiciousVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await showDialog<void>(
          context: context,
          builder: (context) => SuspiciousEntryDialog(state: widget.state),
        );
        _suspiciousVisible = false;
      });
    }
  }

  void _selectDestination(int value) {
    setState(() => _index = value);
    if (value != 1) {
      return;
    }
    final today = widget.state.now.startOfDay;
    if (!widget.state.selectedDay.isSameDate(today)) {
      unawaited(widget.state.selectDay(today));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final sizeClass = adaptiveSizeClassFor(MediaQuery.sizeOf(context).width);
    final showRail = sizeClass != AdaptiveSizeClass.compact;

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: {
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) {
              if (!_focusedEditable(context)) {
                unawaited(state.undo());
              }
              return null;
            },
          ),
          _RedoIntent: CallbackAction<_RedoIntent>(
            onInvoke: (_) {
              if (!_focusedEditable(context)) {
                unawaited(state.redo());
              }
              return null;
            },
          ),
          _SelectDestinationIntent: CallbackAction<_SelectDestinationIntent>(
            onInvoke: (intent) {
              _selectDestination(intent.index);
              return null;
            },
          ),
          _TimelineAddEntryIntent: CallbackAction<_TimelineAddEntryIntent>(
            onInvoke: (_) {
              if (_index == 1 && !_focusedEditable(context)) {
                _timelineController.openEntryEditor();
              }
              return null;
            },
          ),
          _TimelinePreviousRangeIntent:
              CallbackAction<_TimelinePreviousRangeIntent>(
            onInvoke: (_) {
              if (_index == 1 && !_focusedEditable(context)) {
                _timelineController.selectPreviousRange();
              }
              return null;
            },
          ),
          _TimelineNextRangeIntent: CallbackAction<_TimelineNextRangeIntent>(
            onInvoke: (_) {
              if (_index == 1 && !_focusedEditable(context)) {
                _timelineController.selectNextRange();
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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: Row(
                    children: [
                      if (showRail) ...[
                        _DesktopNavigationRail(
                          selectedIndex: _index,
                          destinations: _buildDestinations(context),
                          onDestinationSelected: _selectDestination,
                          historyControls: UndoRedoControls(
                            state: state,
                            axis: Axis.vertical,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                      ],
                      Expanded(
                        child: IndexedStack(
                          index: _index,
                          children: _pages,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              floatingActionButton:
                  showRail ? null : _CompactHistoryMenu(state: state),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
              bottomNavigationBar: showRail
                  ? null
                  : SafeArea(
                      top: false,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border(
                            top: BorderSide(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        child: NavigationBar(
                          height: 72,
                          labelBehavior: NavigationDestinationLabelBehavior
                              .onlyShowSelected,
                          selectedIndex: _index,
                          onDestinationSelected: _selectDestination,
                          destinations: [
                            for (final destination
                                in _buildDestinations(context))
                              NavigationDestination(
                                icon: Icon(destination.icon),
                                selectedIcon: Icon(destination.selectedIcon),
                                label: destination.label,
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _HistoryAction { undo, redo }

class _CompactHistoryMenu extends StatelessWidget {
  const _CompactHistoryMenu({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final undoLabel = state.undoLabel;
        final redoLabel = state.redoLabel;
        return Material(
          elevation: 3,
          color: colorScheme.primaryContainer,
          shape: const CircleBorder(),
          child: PopupMenuButton<_HistoryAction>(
            tooltip:
                '${AppLocalizations.of(context)!.undoHint} / ${AppLocalizations.of(context)!.redoHint}',
            icon: Icon(
              Icons.history,
              color: colorScheme.onPrimaryContainer,
            ),
            onSelected: (action) {
              switch (action) {
                case _HistoryAction.undo:
                  unawaited(state.undo());
                case _HistoryAction.redo:
                  unawaited(state.redo());
              }
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem(
                  value: _HistoryAction.undo,
                  enabled: state.canUndo,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.undo),
                    title: Text(
                      undoLabel == null
                          ? AppLocalizations.of(context)!.undoHint
                          : AppLocalizations.of(context)!
                              .undoWithLabel(undoLabel),
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: _HistoryAction.redo,
                  enabled: state.canRedo,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.redo),
                    title: Text(
                      redoLabel == null
                          ? AppLocalizations.of(context)!.redoHint
                          : AppLocalizations.of(context)!
                              .redoWithLabel(redoLabel),
                    ),
                  ),
                ),
              ];
            },
          ),
        );
      },
    );
  }
}

class _DesktopNavigationRail extends StatelessWidget {
  const _DesktopNavigationRail({
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.historyControls,
  });

  final int selectedIndex;
  final List<_AppDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final Widget historyControls;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 96,
      color: colorScheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 18),
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.timer,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              minWidth: 96,
              groupAlignment: -0.95,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
            child: historyControls,
          ),
        ],
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

final Map<ShortcutActivator, Intent> _shortcuts = {
  const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
      const _UndoIntent(),
  const SingleActivator(LogicalKeyboardKey.keyY, control: true):
      const _RedoIntent(),
  const SingleActivator(
    LogicalKeyboardKey.keyZ,
    control: true,
    shift: true,
  ): const _RedoIntent(),
  const SingleActivator(LogicalKeyboardKey.digit1, control: true):
      const _SelectDestinationIntent(0),
  const SingleActivator(LogicalKeyboardKey.digit2, control: true):
      const _SelectDestinationIntent(1),
  const SingleActivator(LogicalKeyboardKey.digit3, control: true):
      const _SelectDestinationIntent(2),
  const SingleActivator(LogicalKeyboardKey.digit4, control: true):
      const _SelectDestinationIntent(3),
  const SingleActivator(LogicalKeyboardKey.keyN, control: true):
      const _TimelineAddEntryIntent(),
  const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
      const _TimelinePreviousRangeIntent(),
  const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
      const _TimelineNextRangeIntent(),
};

bool _focusedEditable(BuildContext context) {
  final focus = FocusManager.instance.primaryFocus;
  final focusedContext = focus?.context;
  if (focusedContext == null) {
    return false;
  }
  return focusedContext.widget is EditableText ||
      focusedContext.findAncestorWidgetOfExactType<EditableText>() != null;
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _SelectDestinationIntent extends Intent {
  const _SelectDestinationIntent(this.index);

  final int index;
}

class _TimelineAddEntryIntent extends Intent {
  const _TimelineAddEntryIntent();
}

class _TimelinePreviousRangeIntent extends Intent {
  const _TimelinePreviousRangeIntent();
}

class _TimelineNextRangeIntent extends Intent {
  const _TimelineNextRangeIntent();
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class ReminderDialog extends StatelessWidget {
  const ReminderDialog({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.stillDoingThis),
      content: Text(AppLocalizations.of(context)!
          .activityRunningMinutes(state.runningDuration().inMinutes)),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await state.snoozeReminder();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.snooze),
          label: Text(AppLocalizations.of(context)!.remindLater),
        ),
        TextButton.icon(
          onPressed: () async {
            await state.stopCurrent();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.stop_circle_outlined),
          label: Text(AppLocalizations.of(context)!.stop),
        ),
        FilledButton.icon(
          onPressed: () async {
            await state.continueCurrent();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.play_arrow),
          label: Text(AppLocalizations.of(context)!.continueLabel),
        ),
      ],
    );
  }
}

class SuspiciousEntryDialog extends StatelessWidget {
  const SuspiciousEntryDialog({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final entry = state.runningEntry;
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.confirmPreviousPeriod),
      content: Text(
        entry == null
            ? AppLocalizations.of(context)!.noRunningActivity
            : AppLocalizations.of(context)!.suspiciousEntryContent(
                TimeOfDay.fromDateTime(entry.startAt).format(context)),
      ),
      actions: [
        TextButton(
          onPressed: () {
            state.ignoreSuspiciousRunning();
            Navigator.pop(context);
          },
          child: Text(AppLocalizations.of(context)!.keepCurrent),
        ),
        FilledButton.icon(
          onPressed: () async {
            await state.correctSuspiciousRunning(DateTime.now());
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.check),
          label: Text(AppLocalizations.of(context)!.endToNow),
        ),
      ],
    );
  }
}

class LoginBanner extends StatelessWidget {
  const LoginBanner({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.isSignedIn) {
      return _StatusBanner(
        icon: state.isSyncing ? Icons.sync : Icons.cloud_done_outlined,
        text: state.isSyncing
            ? AppLocalizations.of(context)!.syncing
            : AppLocalizations.of(context)!.cloudSyncActive,
      );
    }
    if (state.hasLanPeer) {
      return _StatusBanner(
        icon: state.isSyncing ? Icons.sync : Icons.lan_outlined,
        text: state.isSyncing
            ? AppLocalizations.of(context)!.syncing
            : AppLocalizations.of(context)!.lanPeerPaired,
      );
    }
    if (!state.canCloudSync) {
      return _StatusBanner(
        icon: Icons.cloud_off_outlined,
        text: AppLocalizations.of(context)!.localModeHint,
      );
    }
    return LoginPage(state: state);
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
