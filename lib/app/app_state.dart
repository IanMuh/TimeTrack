import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/date_time_ext.dart';
import '../data/file_interop_service.dart';
import '../data/lan_sync.dart';
import '../data/sync_peer_store.dart';
import '../data/sync_service.dart';
import '../data/time_repository.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/profile_settings.dart';
import '../domain/stats_period.dart';
import '../domain/time_entry.dart';

class AppState extends ChangeNotifier {
  AppState({
    required TimeRepository repository,
    required SyncService syncService,
    required LanSyncServer lanSyncServer,
    required LanSyncClient lanSyncClient,
    required FileInteropService fileInteropService,
  })  : _repository = repository,
        _syncService = syncService,
        _lanSyncServer = lanSyncServer,
        _lanSyncClient = lanSyncClient,
        _fileInteropService = fileInteropService;

  final TimeRepository _repository;
  final SyncService _syncService;
  final LanSyncServer _lanSyncServer;
  final LanSyncClient _lanSyncClient;
  final FileInteropService _fileInteropService;

  Timer? _ticker;

  bool isLoading = true;
  bool isSyncing = false;
  String? errorMessage;
  DateTime selectedDay = DateTime.now();
  List<Activity> activities = const [];
  List<TimeEntry> dayEntries = const [];
  List<ActionLog> dayActionLogs = const [];
  TimeEntry? runningEntry;
  ProfileSettings settings = ProfileSettings.defaults();
  SyncPeer? lanPeer;
  DateTime now = DateTime.now();
  DateTime? lastReminderAt;
  String? ignoredSuspiciousEntryId;
  String? interopMessage;

  bool get canSync => canCloudSync || hasLanPeer;

  bool get canCloudSync => _syncService.isCloudEnabled;

  bool get isSignedIn => _syncService.isCloudSignedIn;

  bool get hasLanPeer => lanPeer != null;

  bool get hasSyncTarget => isSignedIn || hasLanPeer;

  bool get canHostLan => Platform.isWindows || Platform.isAndroid;

  bool get isLanServerRunning => _lanSyncServer.isRunning;

  String? get lanPairingCode => _lanSyncServer.pairingCode;

  List<String> get lanServerUrls => _lanSyncServer.localUrls;

  Activity? get runningActivity {
    final entry = runningEntry;
    if (entry == null) {
      return null;
    }
    return activityById(entry.activityId);
  }

  Duration get runningDuration {
    final entry = runningEntry;
    if (entry == null) {
      return Duration.zero;
    }
    return entry.durationUntil(now);
  }

  bool get shouldShowReminder {
    final entry = runningEntry;
    if (entry == null) {
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
        entry.id != ignoredSuspiciousEntryId &&
        entry.durationUntil(now) > const Duration(hours: 12);
  }

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();
    try {
      await _repository.ensureSeedData();
      await refresh();
      if (Platform.isWindows && !isLanServerRunning) {
        await startLanServer();
      }
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        now = DateTime.now();
        notifyListeners();
      });
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    activities = await _repository.activities();
    settings = await _repository.settings();
    lanPeer = await _lanSyncClient.currentPeer();
    runningEntry = await _repository.runningEntry();
    dayEntries = await _repository.entriesForDay(selectedDay);
    dayActionLogs = await _repository.actionLogsForDay(selectedDay);
    notifyListeners();
  }

  Future<void> selectDay(DateTime day) async {
    selectedDay = day;
    await refresh();
  }

  Activity? activityById(String id) {
    for (final activity in activities) {
      if (activity.id == id) {
        return activity;
      }
    }
    return null;
  }

  Activity? get unassignedActivity {
    for (final activity in activities) {
      if (activity.isUnassigned) {
        return activity;
      }
    }
    return null;
  }

  Future<void> switchTo(Activity activity) async {
    await _repository.switchToActivity(activity.id);
    await refresh();
    unawaited(sync());
  }

  Future<void> stopCurrent() async {
    await _repository.stopRunning();
    await refresh();
    await sync();
  }

  Future<void> continueCurrent() async {
    lastReminderAt = DateTime.now();
    notifyListeners();
  }

  Future<void> snoozeReminder() async {
    lastReminderAt = DateTime.now();
    notifyListeners();
  }

  Future<void> correctSuspiciousRunning(DateTime endAt) async {
    final entry = runningEntry;
    if (entry == null) {
      return;
    }
    await _repository.saveEntry(
      entry.copyWith(endAt: endAt, updatedAt: now),
      logEdit: true,
    );
    await refresh();
    await sync();
  }

  Future<void> ignoreSuspiciousRunning() async {
    ignoredSuspiciousEntryId = runningEntry?.id;
    await continueCurrent();
  }

  Future<void> saveEntry(TimeEntry entry) async {
    await _repository.saveEntry(
      entry.copyWith(updatedAt: DateTime.now()),
      logEdit: true,
    );
    await refresh();
    await sync();
  }

  Future<void> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
  }) async {
    await _repository.createManualEntry(
      activityId: activityId,
      startAt: startAt,
      endAt: endAt,
      note: note,
    );
    await refresh();
    await sync();
  }

  Future<void> deleteEntry(TimeEntry entry) async {
    await _repository.deleteEntry(entry);
    await refresh();
    await sync();
  }

  Future<Activity> createActivity(String name, int color) async {
    final activity = await _repository.createActivity(name: name, color: color);
    await refresh();
    await sync();
    return activity;
  }

  Future<Activity> updateActivity(
    Activity activity, {
    required String name,
    required int color,
  }) async {
    if (activity.isUnassigned) {
      return unassignedActivity ?? activity;
    }
    final updated = await _repository.updateActivity(
      activity: activity,
      name: name,
      color: color,
    );
    await refresh();
    await sync();
    return updated;
  }

  Future<void> deleteActivity(Activity activity) async {
    await _repository.deleteActivity(activity);
    await refresh();
    await sync();
  }

  Future<List<TimeEntry>> overlaps(TimeEntry entry) {
    return _repository.overlappingEntries(entry);
  }

  Future<List<TimeEntry>> entriesForRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final entries = await _repository.entriesForRange(start, end);
    return _entriesWithUnassignedGaps(entries, start, end);
  }

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

  Future<void> updateReminderMinutes(int minutes) async {
    await updateReminderSettings(reminderMinutes: minutes);
  }

  Future<void> updateReminderSettings({
    int? reminderMinutes,
    int? reminderIntervalMinutes,
    ReminderMethod? reminderMethod,
    int? reminderTimeOfDayMinutes,
  }) async {
    settings = settings.copyWith(
      reminderMinutes: reminderMinutes,
      reminderIntervalMinutes: reminderIntervalMinutes,
      reminderMethod: reminderMethod,
      reminderTimeOfDayMinutes: reminderTimeOfDayMinutes,
      updatedAt: DateTime.now(),
    );
    await _repository.saveSettings(settings);
    notifyListeners();
    unawaited(sync());
  }

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

  Future<void> sync() async {
    if (!hasSyncTarget) {
      return;
    }
    isSyncing = true;
    notifyListeners();
    try {
      final errors = <String>[];
      var lanSynced = false;
      if (isSignedIn) {
        try {
          await _syncService.sync();
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
      } else {
        errorMessage = '同步部分失败：${errors.join('；')}';
      }
    } catch (error) {
      errorMessage = '同步失败：$error';
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

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
      // For "all", don't clip — use full durations.
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

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_lanSyncServer.stop());
    super.dispose();
  }
}

class TimeRangeStats {
  const TimeRangeStats({
    required this.totalsByActivity,
    required this.totalsByDay,
    required this.totalDuration,
    required this.longestBlock,
  });

  final Map<String, Duration> totalsByActivity;
  final Map<DateTime, Duration> totalsByDay;
  final Duration totalDuration;
  final Duration longestBlock;

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
    );
  }

  static DateTime _later(DateTime first, DateTime second) {
    return first.isAfter(second) ? first : second;
  }

  static DateTime _earlier(DateTime first, DateTime second) {
    return first.isBefore(second) ? first : second;
  }
}
