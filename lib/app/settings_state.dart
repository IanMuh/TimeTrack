import '../data/time_repository.dart';
import '../domain/profile_settings.dart';

typedef SettingsLoader = Future<ProfileSettings> Function();
typedef SettingsSaver = Future<void> Function(ProfileSettings settings);
typedef SettingsClock = DateTime Function();

class SettingsState {
  SettingsState({
    required TimeRepository repository,
    SettingsClock? now,
  }) : this.withHandlers(
          loadSettings: repository.settings,
          saveSettings: repository.saveSettings,
          now: now,
        );

  SettingsState.withHandlers({
    required SettingsLoader loadSettings,
    required SettingsSaver saveSettings,
    SettingsClock? now,
  })  : _loadSettings = loadSettings,
        _saveSettings = saveSettings,
        _now = now ?? DateTime.now;

  final SettingsLoader _loadSettings;
  final SettingsSaver _saveSettings;
  final SettingsClock _now;

  ProfileSettings settings = ProfileSettings.defaults();

  Future<void> refresh() async {
    settings = await _loadSettings();
  }

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
    settings = settings.copyWith(
      reminderMinutes: reminderMinutes,
      reminderIntervalMinutes: reminderIntervalMinutes,
      reminderMethod: reminderMethod,
      reminderTimeOfDayMinutes: reminderTimeOfDayMinutes,
      mergeNeighborThresholdMinutes: mergeNeighborThresholdMinutes,
      updatedAt: _now(),
    );
    await _saveSettings(settings);
  }
}
