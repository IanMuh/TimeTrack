import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/date_time_ext.dart';
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
  })  : _repository = repository,
        _syncService = syncService;

  final TimeRepository _repository;
  final SyncService _syncService;

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
  DateTime now = DateTime.now();
  DateTime? lastReminderAt;
  String? ignoredSuspiciousEntryId;

  bool get canSync => _syncService.isEnabled;

  bool get isSignedIn => _syncService.currentUser != null;

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
    final recentlyReminded = lastReminderAt != null &&
        now.difference(lastReminderAt!) < const Duration(minutes: 5);
    return entry.durationUntil(now) >= reminderDuration && !recentlyReminded;
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
    await sync();
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
    lastReminderAt = DateTime.now().add(const Duration(minutes: 10));
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
    settings = settings.copyWith(
      reminderMinutes: minutes,
      updatedAt: DateTime.now(),
    );
    await _repository.saveSettings(settings);
    await sync();
    notifyListeners();
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
    if (!_syncService.isEnabled || _syncService.currentUser == null) {
      return;
    }
    isSyncing = true;
    notifyListeners();
    try {
      await _syncService.sync();
      await refresh();
    } catch (error) {
      errorMessage = '同步失败：$error';
    } finally {
      isSyncing = false;
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
      List<TimeEntry> entries, DateTime effectiveNow) {
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
    super.dispose();
  }
}
