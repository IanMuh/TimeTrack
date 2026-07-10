import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/settings_state.dart';
import 'package:timetrack/domain/profile_settings.dart';

void main() {
  test('refresh loads persisted settings', () async {
    final loaded = ProfileSettings.defaults().copyWith(
      reminderMinutes: 75,
    );
    final state = SettingsState.withHandlers(
      loadSettings: () async => loaded,
      saveSettings: (_) async {},
    );

    await state.refresh();

    expect(state.settings.reminderMinutes, 75);
  });

  test('updateReminderSettings saves merged settings with current timestamp',
      () async {
    final now = DateTime(2026, 1, 2, 12);
    ProfileSettings? saved;
    final state = SettingsState.withHandlers(
      loadSettings: () async => ProfileSettings.defaults(),
      saveSettings: (settings) async {
        saved = settings;
      },
      now: () => now,
    );

    await state.updateReminderSettings(
      reminderIntervalMinutes: 20,
      reminderMethod: ReminderMethod.banner,
      reminderTimeOfDayMinutes: 10 * 60,
      mergeNeighborThresholdMinutes: 5,
    );

    expect(state.settings.reminderMinutes, 45);
    expect(state.settings.reminderIntervalMinutes, 20);
    expect(state.settings.reminderMethod, ReminderMethod.banner);
    expect(state.settings.reminderTimeOfDayMinutes, 10 * 60);
    expect(state.settings.mergeNeighborThresholdMinutes, 5);
    expect(state.settings.updatedAt, now);
    expect(saved, same(state.settings));
  });

  test('updateReminderMinutes saves only reminder duration', () async {
    ProfileSettings? saved;
    final state = SettingsState.withHandlers(
      loadSettings: () async => ProfileSettings.defaults(),
      saveSettings: (settings) async {
        saved = settings;
      },
      now: () => DateTime(2026, 1, 2),
    );

    await state.updateReminderMinutes(90);

    expect(state.settings.reminderMinutes, 90);
    expect(state.settings.reminderIntervalMinutes, 10);
    expect(saved?.reminderMinutes, 90);
  });
}
