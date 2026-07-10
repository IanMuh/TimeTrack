import 'dart:async';

import '../domain/profile_settings.dart';
import 'settings_state.dart';

typedef SettingsNotifier = void Function();
typedef SettingsSyncRunner = Future<void> Function();

class SettingsCoordinatorState {
  const SettingsCoordinatorState({
    required SettingsState settingsState,
    required SettingsNotifier notifyListeners,
    required SettingsSyncRunner sync,
  })  : _settingsState = settingsState,
        _notifyListeners = notifyListeners,
        _sync = sync;

  final SettingsState _settingsState;
  final SettingsNotifier _notifyListeners;
  final SettingsSyncRunner _sync;

  Future<void> updateReminderMinutes(int minutes) {
    return updateReminderSettings(reminderMinutes: minutes);
  }

  Future<void> updateReminderSettings({
    int? reminderMinutes,
    int? reminderIntervalMinutes,
    ReminderMethod? reminderMethod,
    int? reminderTimeOfDayMinutes,
    int? mergeNeighborThresholdMinutes,
  }) async {
    await _settingsState.updateReminderSettings(
      reminderMinutes: reminderMinutes,
      reminderIntervalMinutes: reminderIntervalMinutes,
      reminderMethod: reminderMethod,
      reminderTimeOfDayMinutes: reminderTimeOfDayMinutes,
      mergeNeighborThresholdMinutes: mergeNeighborThresholdMinutes,
    );
    _notifyListeners();
    unawaited(_sync());
  }
}
