import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../core/date_time_ext.dart';
import '../l10n/app_localizations.dart';
import 'app_shell_dialogs.dart';
import 'app_shell_frame.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'snackbar_helper.dart';
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
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!
              .updateAvailablePrompt(update.latestVersion.toString()),
          actionLabel: AppLocalizations.of(context)!.viewInSettings,
          onAction: () => _selectDestination(3),
        );
      });
    }
    if (widget.state.shouldShowReminderBanner && !_reminderBannerVisible) {
      _reminderBannerVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.activityRunningMinutes(
            widget.state.runningDuration().inMinutes,
          ),
          actionLabel: AppLocalizations.of(context)!.remindLater,
          onAction: () => widget.state.snoozeReminder(),
        ).closed.whenComplete(() {
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

    return AppShellFrame(
      state: state,
      selectedIndex: _index,
      onDestinationSelected: _selectDestination,
      timelineController: _timelineController,
      pages: _pages,
    );
  }
}
