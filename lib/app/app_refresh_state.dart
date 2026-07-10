import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/date_time_ext.dart';
import '../data/time_repository.dart';
import '../domain/action_log.dart';
import '../domain/time_entry.dart';
import 'activity_state.dart';
import 'category_state.dart';
import 'entry_state.dart';
import 'lan_state.dart';
import 'settings_state.dart';
import 'sync_state.dart';

typedef RolloverRunningEntries = Future<void> Function({DateTime? at});
typedef ActivityRefreshRunner = Future<void> Function({bool notify});
typedef EntryRefreshRunner = Future<void> Function(
  DateTime day, {
  bool notify,
});
typedef SimpleRefreshRunner = Future<void> Function();
typedef ActionLogLoader = Future<List<ActionLog>> Function(DateTime day);
typedef RunningEntryLoader = Future<TimeEntry?> Function();
typedef ActionLogSetter = void Function(List<ActionLog> logs);
typedef RunningEntrySetter = void Function(TimeEntry? entry);
typedef RunningEntryReader = TimeEntry? Function();
typedef AppRefreshNotifier = void Function();

class AppRefreshState {
  AppRefreshState({
    required TimeRepository repository,
    required ActivityState activityState,
    required CategoryState categoryState,
    required SettingsState settingsState,
    required LanState lanState,
    required SyncState syncState,
    required EntryState entryState,
    required AppRefreshNotifier notifyListeners,
  }) : this.withHandlers(
          rolloverRunningEntriesIfNeeded:
              repository.rolloverRunningEntriesIfNeeded,
          refreshActivities: activityState.refresh,
          refreshCategories: categoryState.refresh,
          refreshSettings: settingsState.refresh,
          loadLanPeer: () async {
            await lanState.loadPeer();
          },
          loadSyncStatus: () async {
            await syncState.loadStatus();
          },
          refreshEntries: entryState.refresh,
          loadActionLogsForDay: repository.actionLogsForDay,
          setActionLogs: entryState.setActionLogs,
          loadRunningEntry: repository.runningEntry,
          setRunningEntry: entryState.setRunningEntry,
          runningEntry: () => entryState.runningEntry,
          notifyListeners: notifyListeners,
        );

  AppRefreshState.withHandlers({
    required RolloverRunningEntries rolloverRunningEntriesIfNeeded,
    required ActivityRefreshRunner refreshActivities,
    required SimpleRefreshRunner refreshCategories,
    required SimpleRefreshRunner refreshSettings,
    required SimpleRefreshRunner loadLanPeer,
    required SimpleRefreshRunner loadSyncStatus,
    required EntryRefreshRunner refreshEntries,
    required ActionLogLoader loadActionLogsForDay,
    required ActionLogSetter setActionLogs,
    required RunningEntryLoader loadRunningEntry,
    required RunningEntrySetter setRunningEntry,
    required RunningEntryReader runningEntry,
    required AppRefreshNotifier notifyListeners,
    DateTime? initialSelectedDay,
    DateTime? initialNow,
    ValueNotifier<DateTime>? clockNotifier,
  })  : _rolloverRunningEntriesIfNeeded = rolloverRunningEntriesIfNeeded,
        _refreshActivities = refreshActivities,
        _refreshCategories = refreshCategories,
        _refreshSettings = refreshSettings,
        _loadLanPeer = loadLanPeer,
        _loadSyncStatus = loadSyncStatus,
        _refreshEntries = refreshEntries,
        _loadActionLogsForDay = loadActionLogsForDay,
        _setActionLogs = setActionLogs,
        _loadRunningEntry = loadRunningEntry,
        _setRunningEntry = setRunningEntry,
        _runningEntry = runningEntry,
        _notifyListeners = notifyListeners,
        selectedDay = initialSelectedDay ?? DateTime.now(),
        now = initialNow ?? DateTime.now(),
        clockNotifier =
            clockNotifier ?? ValueNotifier(initialNow ?? DateTime.now());

  final RolloverRunningEntries _rolloverRunningEntriesIfNeeded;
  final ActivityRefreshRunner _refreshActivities;
  final SimpleRefreshRunner _refreshCategories;
  final SimpleRefreshRunner _refreshSettings;
  final SimpleRefreshRunner _loadLanPeer;
  final SimpleRefreshRunner _loadSyncStatus;
  final EntryRefreshRunner _refreshEntries;
  final ActionLogLoader _loadActionLogsForDay;
  final ActionLogSetter _setActionLogs;
  final RunningEntryLoader _loadRunningEntry;
  final RunningEntrySetter _setRunningEntry;
  final RunningEntryReader _runningEntry;
  final AppRefreshNotifier _notifyListeners;

  DateTime selectedDay;
  DateTime now;
  int dataRevision = 0;
  final ValueNotifier<DateTime> clockNotifier;

  Future<void> refresh() async {
    await _rolloverRunningEntriesIfNeeded(at: now);
    await _refreshActivities(notify: false);
    await _refreshCategories();
    await _refreshSettings();
    await _loadLanPeer();
    await _loadSyncStatus();
    await _refreshDailyEntries();
    _markDataChanged();
    _notifyListeners();
  }

  Future<void> selectDay(DateTime day) async {
    selectedDay = day;
    await refreshDailyData();
  }

  Future<void> refreshDailyData() async {
    await _rolloverRunningEntriesIfNeeded(at: now);
    await _refreshDailyEntries();
    _markDataChanged();
    _notifyListeners();
  }

  void tick(DateTime currentTime) {
    now = currentTime;
    clockNotifier.value = currentTime;
    unawaited(rolloverRunningEntryIfNeeded());
  }

  Future<void> rolloverRunningEntryIfNeeded() async {
    final entry = _runningEntry();
    if (entry == null || !entry.startAt.startOfDay.isBefore(now.startOfDay)) {
      return;
    }
    await refresh();
  }

  void dispose() {
    clockNotifier.dispose();
  }

  Future<void> _refreshDailyEntries() async {
    await _refreshEntries(selectedDay, notify: false);
    _setActionLogs(await _loadActionLogsForDay(selectedDay));
    _setRunningEntry(await _loadRunningEntry());
  }

  void _markDataChanged() {
    dataRevision += 1;
  }
}
