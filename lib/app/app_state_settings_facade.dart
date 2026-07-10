part of 'app_state.dart';

mixin AppStateSettingsFacade on ChangeNotifier {
  SettingsState get _settingsState;
  SettingsCoordinatorState get _settingsCoordinatorState;

  ProfileSettings get settings => _settingsState.settings;

  set settings(ProfileSettings value) {
    _settingsState.settings = value;
  }

  Future<void> updateReminderMinutes(int minutes) {
    return _settingsCoordinatorState.updateReminderMinutes(minutes);
  }

  Future<void> updateReminderSettings({
    int? reminderMinutes,
    int? reminderIntervalMinutes,
    ReminderMethod? reminderMethod,
    int? reminderTimeOfDayMinutes,
    int? mergeNeighborThresholdMinutes,
  }) {
    return _settingsCoordinatorState.updateReminderSettings(
      reminderMinutes: reminderMinutes,
      reminderIntervalMinutes: reminderIntervalMinutes,
      reminderMethod: reminderMethod,
      reminderTimeOfDayMinutes: reminderTimeOfDayMinutes,
      mergeNeighborThresholdMinutes: mergeNeighborThresholdMinutes,
    );
  }
}
