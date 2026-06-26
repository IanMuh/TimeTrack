import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../core/app_version.dart';
import '../core/app_constants.dart';
import '../core/date_time_ext.dart';
import '../data/app_update_service.dart';
import '../data/file_interop_service.dart';
import '../data/lan_sync.dart';
import '../data/repository_interfaces.dart';
import '../data/repository_undo.dart';
import '../data/sync_peer_store.dart';
import '../data/sync_service.dart';
import '../data/sync_status_store.dart';
import '../data/time_repository.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/profile_settings.dart';
import '../domain/stats_period.dart';
import '../domain/time_entry.dart';
import 'activity_state.dart';
import 'entry_state.dart';

typedef AppVersionLoader = Future<String> Function();
typedef TargetPlatformLoader = TargetPlatform Function();

class AppState extends ChangeNotifier {
  AppState({
    required TimeRepository repository,
    required IActivityRepository activityRepository,
    required ITimeEntryRepository entryRepository,
    required SyncService syncService,
    required LanSyncServer lanSyncServer,
    required LanSyncClient lanSyncClient,
    required FileInteropService fileInteropService,
    AppUpdateService? updateService,
    AppVersionLoader? appVersionLoader,
    TargetPlatformLoader? targetPlatformLoader,
    SyncStatusStore? syncStatusStore,
  })  : _repository = repository,
        _syncService = syncService,
        _lanSyncServer = lanSyncServer,
        _lanSyncClient = lanSyncClient,
        _fileInteropService = fileInteropService,
        _updateService = updateService ?? AppUpdateService.disabled(),
        _updateChecksEnabled = updateService != null,
        _appVersionLoader = appVersionLoader ?? _defaultAppVersionLoader,
        _targetPlatformLoader =
            targetPlatformLoader ?? _defaultTargetPlatformLoader,
        _syncStatusStore = syncStatusStore ?? SyncStatusStore.memory() {
    _activityState = ActivityState(
      activityRepository: activityRepository,
      entryRepository: entryRepository,
      onFullRefresh: _onFullRefresh,
    );
    _entryState = EntryState(
      entryRepository: entryRepository,
      now: () => now,
      onFullRefresh: _onFullRefresh,
    );
    _activityState.addListener(_onSubStateChanged);
    _entryState.addListener(_onSubStateChanged);
  }

  late final ActivityState _activityState;
  late final EntryState _entryState;

  final TimeRepository _repository;
  final SyncService _syncService;
  final LanSyncServer _lanSyncServer;
  final LanSyncClient _lanSyncClient;
  final FileInteropService _fileInteropService;
  final AppUpdateService _updateService;
  final bool _updateChecksEnabled;
  final AppVersionLoader _appVersionLoader;
  final TargetPlatformLoader _targetPlatformLoader;
  final SyncStatusStore _syncStatusStore;

  Timer? _ticker;
  bool _startupUpdateCheckStarted = false;
  bool _updatePromptShown = false;

  bool isLoading = true;
  bool isSyncing = false;
  String? errorMessage;
  DateTime selectedDay = DateTime.now();
  ProfileSettings settings = ProfileSettings.defaults();
  SyncPeer? lanPeer;
  DateTime now = DateTime.now();
  final ValueNotifier<DateTime> clockNotifier = ValueNotifier(DateTime.now());
  DateTime? lastReminderAt;
  String? ignoredSuspiciousEntryId;
  String? interopMessage;
  SyncStatus syncStatus = const SyncStatus();
  AppUpdateStatus updateStatus = AppUpdateStatus.idle;
  AppUpdateInfo? availableUpdate;
  String currentAppVersion = '';
  String? updateErrorMessage;

  final List<_UndoHistoryEntry> _undoStack = [];
  final List<_UndoHistoryEntry> _redoStack = [];
  var _undoBatchDepth = 0;
  var _syncAfterUndoBatch = false;
  bool _historyBusy = false;

  void _onSubStateChanged() {
    notifyListeners();
  }

  Future<void> _onFullRefresh() async {
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Forwarded fields (activity)
  // ---------------------------------------------------------------------------

  List<Activity> get activities => _activityState.activities;
  set activities(List<Activity> value) => _activityState.activities = value;

  Activity? activityById(String id) => _activityState.activityById(id);

  Activity? get unassignedActivity => _activityState.unassignedActivity;

  String activityNameForEntry(TimeEntry entry) =>
      _activityState.activityNameForEntry(entry);

  int activityColorForEntry(TimeEntry entry) =>
      _activityState.activityColorForEntry(entry);

  bool _entryIsUnassigned(TimeEntry entry) =>
      _activityState.entryIsUnassigned(entry);

  // ---------------------------------------------------------------------------
  // Forwarded fields (entry)
  // ---------------------------------------------------------------------------

  List<TimeEntry> get dayEntries => _entryState.dayEntries;
  set dayEntries(List<TimeEntry> value) => _entryState.dayEntries = value;

  List<ActionLog> get dayActionLogs => _entryState.dayActionLogs;
  set dayActionLogs(List<ActionLog> value) => _entryState.dayActionLogs = value;

  TimeEntry? get runningEntry => _entryState.runningEntry;
  set runningEntry(TimeEntry? value) => _entryState.runningEntry = value;

  // ---------------------------------------------------------------------------
  // Derived activity getters
  // ---------------------------------------------------------------------------

  Activity? get runningActivity {
    final entry = runningEntry;
    if (entry == null) {
      return null;
    }
    final activity = activityById(entry.activityId);
    if (activity == null || activity.isUnassigned) {
      return null;
    }
    return activity;
  }

  Duration runningDuration({DateTime? at}) {
    final entry = runningEntry;
    if (entry == null || _entryIsUnassigned(entry)) {
      return Duration.zero;
    }
    return entry.durationUntil(at ?? now);
  }

  // ---------------------------------------------------------------------------
  // Sync / LAN getters
  // ---------------------------------------------------------------------------

  bool get canSync => canCloudSync || hasLanPeer;

  bool get canCloudSync => _syncService.isCloudEnabled;

  bool get isSignedIn => _syncService.isCloudSignedIn;

  bool get hasLanPeer => lanPeer != null;

  bool get hasSyncTarget => isSignedIn || hasLanPeer;

  String get currentSyncTarget {
    if (isSignedIn && hasLanPeer) {
      return 'cloud_lan';
    }
    if (isSignedIn) {
      return 'cloud';
    }
    if (hasLanPeer) {
      return 'lan';
    }
    return 'none';
  }

  bool get canHostLan => Platform.isWindows || Platform.isAndroid;

  bool get isLanServerRunning => _lanSyncServer.isRunning;

  bool get canUndo => !_historyBusy && _undoStack.isNotEmpty;

  bool get canRedo => !_historyBusy && _redoStack.isNotEmpty;

  String? get undoLabel => _undoStack.isEmpty ? null : _undoStack.last.label;

  String? get redoLabel => _redoStack.isEmpty ? null : _redoStack.last.label;

  String? get lanPairingCode => _lanSyncServer.pairingCode;

  List<String> get lanServerUrls => _lanSyncServer.localUrls;

  @visibleForTesting
  int? get lanSyncPortForTest => _lanSyncServer.port;

  bool get shouldShowUpdatePrompt {
    return !_updatePromptShown &&
        updateStatus == AppUpdateStatus.available &&
        availableUpdate != null;
  }

  bool get shouldShowReminder {
    final entry = runningEntry;
    if (entry == null || _entryIsUnassigned(entry)) {
      return false;
    }
    final reminderDuration = Duration(minutes: settings.reminderMinutes);
    final reminderStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(minutes: settings.reminderTimeOfDayMinutes));
    final recentlyReminded = lastReminderAt != null &&
        now.difference(lastReminderAt!) <
            Duration(minutes: settings.reminderIntervalMinutes);
    return !now.isBefore(reminderStart) &&
        entry.durationUntil(now) >= reminderDuration &&
        !recentlyReminded;
  }

  bool get shouldShowReminderDialog {
    return shouldShowReminder &&
        settings.reminderMethod == ReminderMethod.dialog;
  }

  bool get shouldShowReminderBanner {
    return shouldShowReminder &&
        settings.reminderMethod == ReminderMethod.banner;
  }

  bool get hasSuspiciousRunningEntry {
    final entry = runningEntry;
    return entry != null &&
        !_entryIsUnassigned(entry) &&
        entry.id != ignoredSuspiciousEntryId &&
        entry.durationUntil(now) >
            const Duration(hours: AppConstants.suspiciousEntryHours);
  }

  // ---------------------------------------------------------------------------
  // Initialize / Refresh / Select
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();
    try {
      await _repository.ensureSeedData();
      await refresh();
      if (Platform.isWindows && !isLanServerRunning) {
        await startLanServer();
      }
      _startStartupUpdateCheck();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        now = DateTime.now();
        clockNotifier.value = now;
        unawaited(_rolloverRunningEntryIfNeeded());
      });
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void markUpdatePromptShown() {
    if (_updatePromptShown) {
      return;
    }
    _updatePromptShown = true;
    notifyListeners();
  }

  Future<void> checkForUpdates({bool silent = false}) async {
    if (!_updateChecksEnabled || updateStatus == AppUpdateStatus.checking) {
      return;
    }

    updateStatus = AppUpdateStatus.checking;
    updateErrorMessage = null;
    if (!silent) {
      notifyListeners();
    }

    try {
      final versionValue = (await _appVersionLoader()).trim();
      currentAppVersion = versionValue;
      final currentVersion = AppVersion.parse(versionValue);
      final result = await _updateService.checkForUpdate(
        currentVersion: currentVersion,
        platform: _targetPlatformLoader(),
      );
      result.when(
        onSuccess: (update) {
          availableUpdate = update;
          updateStatus = update == null
              ? AppUpdateStatus.upToDate
              : AppUpdateStatus.available;
          updateErrorMessage = null;
        },
        onFailure: (message) {
          availableUpdate = null;
          updateStatus = AppUpdateStatus.failed;
          updateErrorMessage = message;
        },
      );
    } on FormatException catch (error) {
      availableUpdate = null;
      updateStatus = AppUpdateStatus.failed;
      updateErrorMessage = 'Invalid app version: ${error.source}.';
    } catch (error) {
      availableUpdate = null;
      updateStatus = AppUpdateStatus.failed;
      updateErrorMessage = 'Update check failed: $error';
    } finally {
      notifyListeners();
    }
  }

  Future<void> openUpdateDownload() async {
    final update = availableUpdate;
    if (update == null) {
      return;
    }
    final result = await _updateService.openDownload(update);
    result.when(
      onSuccess: (_) {
        updateErrorMessage = null;
      },
      onFailure: (message) {
        updateErrorMessage = message;
      },
    );
    notifyListeners();
  }

  void _startStartupUpdateCheck() {
    if (!_updateChecksEnabled || _startupUpdateCheckStarted) {
      return;
    }
    _startupUpdateCheckStarted = true;
    unawaited(checkForUpdates(silent: true));
  }

  Future<void> refresh() async {
    await _repository.rolloverRunningEntriesIfNeeded(at: now);
    await _activityState.refresh();
    settings = await _repository.settings();
    lanPeer = await _lanSyncClient.currentPeer();
    syncStatus = await _syncStatusStore.load();
    await _entryState.refresh(selectedDay);
    final logs = await _repository.actionLogsForDay(selectedDay);
    _entryState.setActionLogs(logs);
    // Also update running entry from TimeRepository to ensure consistency
    final repoRunning = await _repository.runningEntry();
    _entryState.setRunningEntry(repoRunning);
    notifyListeners();
  }

  Future<void> selectDay(DateTime day) async {
    selectedDay = day;
    await refresh();
  }

  Future<void> _rolloverRunningEntryIfNeeded() async {
    final entry = runningEntry;
    if (entry == null || !entry.startAt.startOfDay.isBefore(now.startOfDay)) {
      return;
    }
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Activity mutation forwarding (with undo)
  // ---------------------------------------------------------------------------

  Future<void> switchTo(Activity activity) async {
    await _recordUndoable('切换到 ${activity.name}', () async {
      await _activityState.switchTo(activity);
    });
  }

  Future<void> stopCurrent() async {
    await _recordUndoable('停止当前事项', () async {
      await _activityState.stopCurrent();
    });
  }

  Future<void> continueCurrent() async {
    lastReminderAt = DateTime.now();
    notifyListeners();
  }

  Future<void> snoozeReminder() async {
    lastReminderAt = DateTime.now();
    notifyListeners();
  }

  Future<void> ignoreSuspiciousRunning() async {
    ignoredSuspiciousEntryId = runningEntry?.id;
    await continueCurrent();
  }

  Future<Activity> createActivity(String name, int color) async {
    return _recordUndoable('新增事项', () async {
      return _activityState.createActivity(name, color);
    });
  }

  Future<List<Activity>> oneOffActivitySuggestions() {
    return _activityState.oneOffActivitySuggestions();
  }

  Future<Activity> createOneOffActivity(
    String name,
    int color, {
    Activity? reuseActivity,
  }) async {
    return _recordUndoable('开始临时事项', () async {
      return _activityState.createOneOffActivity(
        name,
        color,
        reuseActivity: reuseActivity,
      );
    });
  }

  Future<Activity> createEntryActivity(
    String name,
    int color, {
    required bool isOneOff,
    Activity? reuseActivity,
  }) async {
    return _recordUndoable('新增事项', () async {
      return _activityState.createEntryActivity(
        name,
        color,
        isOneOff: isOneOff,
        reuseActivity: reuseActivity,
      );
    });
  }

  Future<Activity> updateActivity(
    Activity activity, {
    required String name,
    required int color,
  }) async {
    return _recordUndoable('编辑事项', () async {
      return _activityState.updateActivity(
        activity,
        name: name,
        color: color,
      );
    });
  }

  Future<void> deleteActivity(Activity activity) async {
    await _recordUndoable('删除事项', () async {
      await _activityState.deleteActivity(activity);
    });
  }

  Future<List<Activity>> entryActivityChoices() async {
    return _activityState.entryActivityChoices();
  }

  // ---------------------------------------------------------------------------
  // Entry mutation forwarding (with undo)
  // ---------------------------------------------------------------------------

  Future<void> saveEntry(TimeEntry entry) async {
    await _recordUndoable('编辑时间段', () async {
      await _entryState.saveEntry(entry);
    });
  }

  Future<void> splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) async {
    await _recordUndoable('切割时间段', () async {
      await _entryState.splitEntry(entryId: entryId, splitAt: splitAt);
    });
  }

  Future<void> extendEntryToNow(TimeEntry entry) async {
    if (entry.isRunning || !entry.startAt.isBefore(now)) {
      return;
    }
    await _recordUndoable('延续时间段到现在', () async {
      await _entryState.extendEntryToNow(entry);
    });
  }

  Future<void> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
  }) async {
    await _recordUndoable('补记时间段', () async {
      await _entryState.createManualEntry(
        activityId: activityId,
        startAt: startAt,
        endAt: endAt,
        note: note,
      );
    });
  }

  Future<void> deleteEntry(TimeEntry entry) async {
    await _recordUndoable('删除时间段', () async {
      await _entryState.deleteEntry(entry);
    });
  }

  Future<void> correctSuspiciousRunning(DateTime endAt) async {
    final entry = runningEntry;
    if (entry == null) {
      return;
    }
    await _recordUndoable('修正运行记录', () async {
      await _entryState.correctSuspiciousRunning(endAt);
    });
  }

  Future<List<TimeEntry>> overlaps(TimeEntry entry) {
    return _entryState.overlaps(entry);
  }

  Future<EntryMergeCandidate?> mergeCandidate(
    String entryId,
    EntryMergeDirection direction,
  ) {
    return _entryState.mergeCandidate(entryId, direction);
  }

  Future<void> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) async {
    await _recordUndoable('合并时间段', () async {
      await _entryState.mergeEntryWithNeighbor(
        entryId: entryId,
        direction: direction,
        confirmed: confirmed,
      );
    });
  }

  Future<List<TimeEntry>> entriesForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final entries = await _entryState.entriesForRange(start: start, end: end);
    return _entriesWithUnassignedGaps(entries, start, end);
  }

  // ---------------------------------------------------------------------------
  // Undo / Redo
  // ---------------------------------------------------------------------------

  Future<T> runUndoBatch<T>(
    Future<T> Function() action, {
    String? label,
  }) async {
    final isOuterBatch = _undoBatchDepth == 0;
    final before = isOuterBatch ? await _repository.undoSnapshot() : null;
    var succeeded = false;
    _undoBatchDepth += 1;
    try {
      final result = await action();
      succeeded = true;
      return result;
    } finally {
      _undoBatchDepth -= 1;
      if (isOuterBatch && succeeded) {
        final after = await _repository.undoSnapshot();
        final mergedLabel = label ?? '编辑时间段';
        final changeSet = before!.diff(label: mergedLabel, after: after);
        if (!changeSet.isEmpty) {
          _undoStack.add(
            _UndoHistoryEntry(label: mergedLabel, changeSet: changeSet),
          );
          _redoStack.clear();
          notifyListeners();
        }
        if (_syncAfterUndoBatch) {
          _syncAfterUndoBatch = false;
          unawaited(sync());
        }
      } else if (isOuterBatch) {
        _syncAfterUndoBatch = false;
      }
    }
  }

  Future<void> undo() async {
    if (!canUndo) {
      return;
    }
    final entry = _undoStack.removeLast();
    if (await _applyHistoryEntry(entry, RepositoryUndoDirection.undo)) {
      _redoStack.add(entry);
      notifyListeners();
    }
  }

  Future<void> redo() async {
    if (!canRedo) {
      return;
    }
    final entry = _redoStack.removeLast();
    if (await _applyHistoryEntry(entry, RepositoryUndoDirection.redo)) {
      _undoStack.add(entry);
      notifyListeners();
    }
  }

  Future<T> _recordUndoable<T>(
    String label,
    Future<T> Function() action, {
    bool syncAfter = true,
  }) async {
    final before = await _repository.undoSnapshot();
    final result = await action();
    final after = await _repository.undoSnapshot();
    final changeSet = before.diff(label: label, after: after);
    if (!changeSet.isEmpty) {
      final historyEntry = _UndoHistoryEntry(
        label: label,
        changeSet: changeSet,
      );
      if (_undoBatchDepth > 0) {
        _syncAfterUndoBatch = _syncAfterUndoBatch || syncAfter;
      } else {
        _undoStack.add(historyEntry);
        _redoStack.clear();
        notifyListeners();
      }
    }
    if (syncAfter) {
      if (_undoBatchDepth > 0) {
        _syncAfterUndoBatch = true;
      } else {
        unawaited(sync());
      }
    }
    return result;
  }

  Future<bool> _applyHistoryEntry(
    _UndoHistoryEntry entry,
    RepositoryUndoDirection direction,
  ) async {
    _historyBusy = true;
    notifyListeners();
    try {
      await _repository.applyUndoChangeSet(
        entry.changeSet,
        direction: direction,
      );
      await refresh();
      await sync();
      errorMessage = null;
      return true;
    } on RepositoryUndoConflictException catch (error) {
      errorMessage = error.message;
      if (direction == RepositoryUndoDirection.undo) {
        _undoStack.add(entry);
      } else {
        _redoStack.add(entry);
      }
      await refresh();
      return false;
    } catch (error) {
      errorMessage = '操作失败：$error';
      if (direction == RepositoryUndoDirection.undo) {
        _undoStack.add(entry);
      } else {
        _redoStack.add(entry);
      }
      await refresh();
      return false;
    } finally {
      _historyBusy = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------

  Future<List<ActionLog>> actionLogsForRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _repository.actionLogsForRange(start, end);
  }

  Future<TimeRangeStats> statsForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final entries = await entriesForRange(start: start, end: end);
    return TimeRangeStats.fromEntries(
      entries: entries,
      start: start,
      end: end,
      effectiveNow: now,
    );
  }

  Map<String, Duration> todayTotals() {
    final start = selectedDay.startOfDay;
    final end = start.add(const Duration(days: 1));
    return _totalsInWindow(
        _entriesWithUnassignedGaps(dayEntries, start, end), start, end, now);
  }

  Future<Map<String, Duration>> weekTotals() async {
    return totalsForPeriod(StatsPeriod.week);
  }

  Future<Map<String, Duration>> totalsForPeriod(StatsPeriod period) async {
    final (start, end) = period.windowFor(selectedDay);
    if (period == StatsPeriod.day) {
      return _totalsInWindow(
        _entriesWithUnassignedGaps(dayEntries, start, end),
        start,
        end,
        now,
      );
    }
    List<TimeEntry> entries;
    if (period == StatsPeriod.all) {
      entries = await _repository.allEntries();
      entries = _visibleStoredEntries(entries);
    } else {
      entries = await entriesForRange(start: start, end: end);
    }
    return _totalsInWindow(entries, start, end, now);
  }

  Duration longestBlock() {
    final dayStart = selectedDay.startOfDay;
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _longestInWindow(
      _entriesWithUnassignedGaps(dayEntries, dayStart, dayEnd),
      dayStart,
      dayEnd,
      now,
    );
  }

  Future<Duration> longestBlockForPeriod(StatsPeriod period) async {
    final (start, end) = period.windowFor(selectedDay);
    if (period == StatsPeriod.day) {
      return _longestInWindow(
        _entriesWithUnassignedGaps(dayEntries, start, end),
        start,
        end,
        now,
      );
    }
    List<TimeEntry> entries;
    if (period == StatsPeriod.all) {
      entries = await _repository.allEntries();
      var longest = Duration.zero;
      for (final entry in _visibleStoredEntries(entries)) {
        final duration = entry.durationUntil(now);
        if (duration > longest) {
          longest = duration;
        }
      }
      return longest;
    }
    entries = await entriesForRange(start: start, end: end);
    return _longestInWindow(entries, start, end, now);
  }

  List<TimeEntry> _visibleStoredEntries(List<TimeEntry> entries) {
    final unassigned = unassignedActivity;
    return [
      for (final entry in entries)
        if (!entry.isDeleted &&
            (unassigned == null || entry.activityId != unassigned.id))
          entry,
    ];
  }

  Map<String, Duration> _totalsInWindow(
    List<TimeEntry> entries,
    DateTime windowStart,
    DateTime windowEnd,
    DateTime effectiveNow,
  ) {
    final totals = <String, Duration>{};
    for (final entry in entries) {
      final duration = entry.durationInWindow(
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: effectiveNow,
      );
      if (duration == Duration.zero) {
        continue;
      }
      totals[entry.activityId] =
          (totals[entry.activityId] ?? Duration.zero) + duration;
    }
    return totals;
  }

  Duration _longestInWindow(
    List<TimeEntry> entries,
    DateTime windowStart,
    DateTime windowEnd,
    DateTime effectiveNow,
  ) {
    var longest = Duration.zero;
    for (final entry in entries) {
      final duration = entry.durationInWindow(
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: effectiveNow,
      );
      if (duration > longest) {
        longest = duration;
      }
    }
    return longest;
  }

  List<TimeEntry> visibleDayEntries() {
    final start = selectedDay.startOfDay;
    final end = start.add(const Duration(days: 1));
    final visible = dayEntries.where((entry) {
      final entryEnd = entry.endAt ?? now;
      return entry.startAt.isBefore(end) && entryEnd.isAfter(start);
    }).toList();
    return _entriesWithUnassignedGaps(visible, start, end);
  }

  // ---------------------------------------------------------------------------
  // Reminder settings
  // ---------------------------------------------------------------------------

  Future<void> updateReminderMinutes(int minutes) async {
    await updateReminderSettings(reminderMinutes: minutes);
  }

  Future<void> updateReminderSettings({
    int? reminderMinutes,
    int? reminderIntervalMinutes,
    ReminderMethod? reminderMethod,
    int? reminderTimeOfDayMinutes,
    int? mergeNeighborThresholdMinutes,
  }) async {
    settings = settings.copyWith(
      reminderMinutes: reminderMinutes,
      reminderIntervalMinutes: reminderIntervalMinutes,
      reminderMethod: reminderMethod,
      reminderTimeOfDayMinutes: reminderTimeOfDayMinutes,
      mergeNeighborThresholdMinutes: mergeNeighborThresholdMinutes,
      updatedAt: DateTime.now(),
    );
    await _repository.saveSettings(settings);
    notifyListeners();
    unawaited(sync());
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  Future<void> sendMagicLink(String email) async {
    await _syncService.sendMagicLink(email);
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    await _syncService.verifyEmailOtp(email: email, token: token);
    await refresh();
    await sync();
  }

  Future<void> signOut() async {
    await _syncService.signOut();
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  Future<void> sync() async {
    if (!hasSyncTarget) {
      return;
    }
    final target = currentSyncTarget;
    final cloudSince = _cloudSyncSince();
    isSyncing = true;
    notifyListeners();
    try {
      final errors = <String>[];
      var lanSynced = false;
      if (isSignedIn) {
        try {
          await _syncService.sync(since: cloudSince);
        } catch (error) {
          errors.add('云同步：$error');
        }
      }
      if (hasLanPeer) {
        try {
          await _lanSyncClient.syncNow();
          lanSynced = true;
        } catch (error) {
          errors.add('局域网同步：$error');
        }
      }
      if (isSignedIn && lanSynced) {
        try {
          await _syncService.sync();
        } catch (error) {
          errors.add('云同步回传：$error');
        }
      }
      await refresh();
      if (errors.isEmpty) {
        errorMessage = null;
        syncStatus = await _syncStatusStore.markSuccess(
          at: DateTime.now(),
          target: target,
        );
      } else {
        errorMessage = '同步部分失败：${errors.join('；')}';
        syncStatus = await _syncStatusStore.markFailure(
          error: errorMessage!,
          target: target,
        );
      }
    } catch (error) {
      errorMessage = '同步失败：$error';
      syncStatus = await _syncStatusStore.markFailure(
        error: errorMessage!,
        target: target,
      );
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  DateTime? _cloudSyncSince() {
    final lastTarget = syncStatus.lastTarget;
    if (lastTarget == 'cloud' || lastTarget == 'cloud_lan') {
      return syncStatus.lastSuccessfulSyncAt;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // LAN
  // ---------------------------------------------------------------------------

  Future<void> startLanServer() async {
    if (!canHostLan) {
      interopMessage = '请在 Windows 端开启局域网主机，Android 作为客户端连接。';
      notifyListeners();
      return;
    }
    try {
      await _lanSyncServer.start();
      interopMessage = '局域网主机已开启。';
      notifyListeners();
    } catch (error) {
      interopMessage = '无法开启局域网主机：$error';
      notifyListeners();
    }
  }

  Future<void> stopLanServer() async {
    await _lanSyncServer.stop();
    interopMessage = '局域网主机已关闭。';
    notifyListeners();
  }

  Future<void> pairLanPeer({
    required String baseUrl,
    required String code,
  }) async {
    try {
      lanPeer = await _lanSyncClient.pair(baseUrl: baseUrl, code: code);
      interopMessage = '局域网主机配对成功。';
      notifyListeners();
      await sync();
    } catch (error) {
      interopMessage = '局域网配对失败：$error';
      notifyListeners();
    }
  }

  Future<void> clearLanPeer() async {
    await _lanSyncClient.clearPeer();
    lanPeer = null;
    interopMessage = '已移除局域网主机配对。';
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Import / Export
  // ---------------------------------------------------------------------------

  Future<void> exportInteropFile() async {
    try {
      final path = await _fileInteropService.exportToFile();
      interopMessage = path == null ? '已取消导出。' : '已导出：$path';
      notifyListeners();
    } catch (error) {
      interopMessage = '导出失败：$error';
      notifyListeners();
    }
  }

  Future<void> importInteropFile() async {
    try {
      final path = await _fileInteropService.importFromFile();
      if (path == null) {
        interopMessage = '已取消导入。';
      } else {
        interopMessage = '已导入：$path';
        await refresh();
      }
      notifyListeners();
    } catch (error) {
      interopMessage = '导入失败：$error';
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Unassigned gap helpers
  // ---------------------------------------------------------------------------

  List<TimeEntry> _entriesWithUnassignedGaps(
    List<TimeEntry> entries,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    final unassigned = unassignedActivity;
    final effectiveEnd = _earlier(windowEnd, now);
    final visibleEntries = [
      for (final entry in entries)
        if (unassigned == null || entry.activityId != unassigned.id) entry,
    ];
    if (unassigned == null || !windowStart.isBefore(effectiveEnd)) {
      return visibleEntries;
    }

    final coverage = [
      for (final entry in visibleEntries)
        if (!entry.isDeleted &&
            entry.startAt.isBefore(effectiveEnd) &&
            (entry.endAt ?? now).isAfter(windowStart))
          entry,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));

    final gaps = <TimeEntry>[];
    var cursor = windowStart;
    for (final entry in coverage) {
      final entryStart = _later(entry.startAt, windowStart);
      final entryEnd = _earlier(entry.endAt ?? now, effectiveEnd);
      if (!entryEnd.isAfter(entryStart)) {
        continue;
      }
      if (cursor.isBefore(entryStart)) {
        gaps.add(_unassignedEntry(unassigned, cursor, entryStart));
      }
      if (cursor.isBefore(entryEnd)) {
        cursor = entryEnd;
      }
    }
    if (cursor.isBefore(effectiveEnd)) {
      gaps.add(_unassignedEntry(unassigned, cursor, effectiveEnd));
    }

    final combined = [...visibleEntries, ...gaps]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return combined;
  }

  TimeEntry _unassignedEntry(
    Activity activity,
    DateTime start,
    DateTime end,
  ) {
    final id = const Uuid().v5(
      Namespace.url.value,
      'timetrack:unassigned:${activity.id}:'
      '${start.toUtc().toIso8601String()}:'
      '${end.toUtc().toIso8601String()}',
    );
    return TimeEntry(
      id: id,
      userId: activity.userId,
      activityId: activity.id,
      activityNameSnapshot: activity.name,
      activityColorSnapshot: activity.color,
      startAt: start,
      endAt: end,
      note: '',
      deviceId: 'unassigned-gap',
      updatedAt: now,
      isDeleted: false,
    );
  }

  DateTime _later(DateTime first, DateTime second) {
    return first.isAfter(second) ? first : second;
  }

  DateTime _earlier(DateTime first, DateTime second) {
    return first.isBefore(second) ? first : second;
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _ticker?.cancel();
    clockNotifier.dispose();
    _activityState.removeListener(_onSubStateChanged);
    _entryState.removeListener(_onSubStateChanged);
    _activityState.dispose();
    _entryState.dispose();
    unawaited(_lanSyncServer.stop());
    super.dispose();
  }
}

Future<String> _defaultAppVersionLoader() async {
  final packageInfo = await PackageInfo.fromPlatform();
  final version = packageInfo.version.trim();
  final buildNumber = packageInfo.buildNumber.trim();
  if (buildNumber.isEmpty || version.contains('+')) {
    return version;
  }
  return '$version+$buildNumber';
}

TargetPlatform _defaultTargetPlatformLoader() => defaultTargetPlatform;

class _UndoHistoryEntry {
  const _UndoHistoryEntry({
    required this.label,
    required this.changeSet,
  });

  final String label;
  final RepositoryUndoChangeSet changeSet;
}

class TimeRangeStats {
  const TimeRangeStats({
    required this.totalsByActivity,
    required this.totalsByDay,
    required this.totalDuration,
    required this.longestBlock,
    this.activitySnapshots = const {},
  });

  final Map<String, Duration> totalsByActivity;
  final Map<DateTime, Duration> totalsByDay;
  final Duration totalDuration;
  final Duration longestBlock;
  final Map<String, ActivityStatsSnapshot> activitySnapshots;

  static TimeRangeStats fromEntries({
    required List<TimeEntry> entries,
    required DateTime start,
    required DateTime end,
    required DateTime effectiveNow,
  }) {
    if (end.isBefore(start)) {
      return const TimeRangeStats(
        totalsByActivity: {},
        totalsByDay: {},
        totalDuration: Duration.zero,
        longestBlock: Duration.zero,
      );
    }

    final totalsByActivity = <String, Duration>{};
    final totalsByDay = <DateTime, Duration>{};
    final activitySnapshots = <String, ActivityStatsSnapshot>{};
    var totalDuration = Duration.zero;
    var longestBlock = Duration.zero;

    for (final entry in entries) {
      final clippedStart = _later(entry.startAt, start);
      final clippedEnd = _earlier(entry.endAt ?? effectiveNow, end);
      if (!clippedEnd.isAfter(clippedStart)) {
        continue;
      }

      final clippedDuration = clippedEnd.difference(clippedStart);
      totalsByActivity[entry.activityId] =
          (totalsByActivity[entry.activityId] ?? Duration.zero) +
              clippedDuration;
      if (entry.activityNameSnapshot.trim().isNotEmpty ||
          entry.activityColorSnapshot != null) {
        activitySnapshots[entry.activityId] = ActivityStatsSnapshot(
          name: entry.activityNameSnapshot.trim(),
          color: entry.activityColorSnapshot,
        );
      }
      totalDuration += clippedDuration;
      if (clippedDuration > longestBlock) {
        longestBlock = clippedDuration;
      }

      var cursor = clippedStart;
      while (cursor.isBefore(clippedEnd)) {
        final day = cursor.startOfDay;
        final nextDay = day.add(const Duration(days: 1));
        final segmentEnd = _earlier(nextDay, clippedEnd);
        final duration = segmentEnd.difference(cursor);
        totalsByDay[day] = (totalsByDay[day] ?? Duration.zero) + duration;
        cursor = segmentEnd;
      }
    }

    return TimeRangeStats(
      totalsByActivity: totalsByActivity,
      totalsByDay: totalsByDay,
      totalDuration: totalDuration,
      longestBlock: longestBlock,
      activitySnapshots: activitySnapshots,
    );
  }

  static DateTime _later(DateTime first, DateTime second) {
    return first.isAfter(second) ? first : second;
  }

  static DateTime _earlier(DateTime first, DateTime second) {
    return first.isBefore(second) ? first : second;
  }
}

class ActivityStatsSnapshot {
  const ActivityStatsSnapshot({
    required this.name,
    required this.color,
  });

  final String name;
  final int? color;
}
