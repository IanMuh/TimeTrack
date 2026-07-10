import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/settings_coordinator_state.dart';
import 'package:timetrack/app/settings_state.dart';
import 'package:timetrack/domain/profile_settings.dart';

void main() {
  test('AppState settings facade stays separate from runtime facade', () {
    final settingsFacade = File('lib/app/app_state_settings_facade.dart');
    final runtimeFacade = File('lib/app/app_state_runtime_facade.dart');
    final coreFacade = File('lib/app/app_state_core_facade.dart');

    expect(settingsFacade.existsSync(), isTrue);

    final settingsSource = settingsFacade.readAsStringSync();
    final runtimeSource = runtimeFacade.readAsStringSync();
    final coreSource = coreFacade.readAsStringSync();

    expect(settingsSource, contains('mixin AppStateSettingsFacade'));
    expect(settingsSource, contains('SettingsState get _settingsState'));
    expect(settingsSource, contains('ProfileSettings get settings'));
    expect(settingsSource, contains('set settings(ProfileSettings value)'));
    expect(settingsSource, contains('Future<void> updateReminderMinutes'));
    expect(settingsSource, contains('Future<void> updateReminderSettings'));
    expect(
      runtimeSource,
      isNot(contains('Future<void> updateReminderMinutes')),
    );
    expect(
      runtimeSource,
      isNot(contains('Future<void> updateReminderSettings')),
    );
    expect(coreSource, isNot(contains('SettingsState get _settingsState')));
    expect(coreSource, isNot(contains('ProfileSettings get settings')));
    expect(coreSource, isNot(contains('set settings(ProfileSettings value)')));
  });

  test('updateReminderMinutes saves, notifies, and schedules sync', () async {
    final harness = _SettingsHarness();

    await harness.coordinator.updateReminderMinutes(90);
    await Future<void>.delayed(Duration.zero);

    expect(harness.settingsState.settings.reminderMinutes, 90);
    expect(harness.saved?.reminderMinutes, 90);
    expect(harness.notifyCount, 1);
    expect(harness.syncCount, 1);
  });

  test('updateReminderSettings preserves unchanged settings', () async {
    final harness = _SettingsHarness(
      initialSettings: ProfileSettings.defaults().copyWith(
        reminderMinutes: 30,
        reminderIntervalMinutes: 5,
      ),
    );

    await harness.coordinator.updateReminderSettings(
      reminderMethod: ReminderMethod.banner,
    );
    await Future<void>.delayed(Duration.zero);

    expect(harness.settingsState.settings.reminderMinutes, 30);
    expect(harness.settingsState.settings.reminderIntervalMinutes, 5);
    expect(
        harness.settingsState.settings.reminderMethod, ReminderMethod.banner);
    expect(harness.notifyCount, 1);
    expect(harness.syncCount, 1);
  });
}

class _SettingsHarness {
  _SettingsHarness({
    ProfileSettings? initialSettings,
  }) {
    settingsState = SettingsState.withHandlers(
      loadSettings: () async => initialSettings ?? ProfileSettings.defaults(),
      saveSettings: (settings) async {
        saved = settings;
      },
      now: () => DateTime(2026, 1, 2, 12),
    )..settings = initialSettings ?? ProfileSettings.defaults();
    coordinator = SettingsCoordinatorState(
      settingsState: settingsState,
      notifyListeners: () {
        notifyCount += 1;
      },
      sync: () async {
        syncCount += 1;
      },
    );
  }

  late final SettingsState settingsState;
  late final SettingsCoordinatorState coordinator;
  ProfileSettings? saved;
  var notifyCount = 0;
  var syncCount = 0;
}
