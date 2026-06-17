import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/date_time_ext.dart';
import '../data/file_interop_service.dart';
import '../data/lan_sync.dart';
import '../data/sync_peer_store.dart';
import '../data/sync_service.dart';
import '../data/time_repository.dart';
import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/profile_settings.dart';
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
    return _totalsFor(dayEntries, now);
  }

  Future<Map<String, Duration>> weekTotals() async {
    final start = selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
    final totals = <String, Duration>{};
    for (var i = 0; i < 7; i += 1) {
      final entries =
          await _repository.entriesForDay(start.add(Duration(days: i)));
      final dayTotals = _totalsFor(entries, now);
      for (final item in dayTotals.entries) {
        totals[item.key] = (totals[item.key] ?? Duration.zero) + item.value;
      }
    }
    return totals;
  }

  Duration longestBlock() {
    var longest = Duration.zero;
    for (final entry in dayEntries) {
      final duration = entry.durationUntil(now);
      if (duration > longest) {
        longest = duration;
      }
    }
    return longest;
  }

  List<TimeEntry> visibleDayEntries() {
    final start = selectedDay.startOfDay;
    final end = selectedDay.endOfDay;
    return dayEntries.where((entry) {
      final entryEnd = entry.endAt ?? now;
      return entry.startAt.isBefore(end) && entryEnd.isAfter(start);
    }).toList();
  }

  Map<String, Duration> _totalsFor(
    List<TimeEntry> entries,
    DateTime effectiveNow,
  ) {
    final totals = <String, Duration>{};
    for (final entry in entries) {
      totals[entry.activityId] = (totals[entry.activityId] ?? Duration.zero) +
          entry.durationUntil(effectiveNow);
    }
    return totals;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_lanSyncServer.stop());
    super.dispose();
  }
}
