import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SettingsPage card implementations live outside the page shell', () {
    final shell = File('lib/ui/settings_page.dart');
    final timelineCard = File('lib/ui/timeline_settings_card.dart');
    final reminderCard = File('lib/ui/reminder_settings_card.dart');
    final syncCards = File('lib/ui/sync_settings_cards.dart');
    final interopCard = File('lib/ui/interop_settings_card.dart');
    final settingsField = File('lib/ui/settings_field.dart');
    final sectionList = File('lib/ui/settings_section_list.dart');
    final updateCard = File('lib/ui/version_update_settings_card.dart');

    expect(timelineCard.existsSync(), isTrue);
    expect(reminderCard.existsSync(), isTrue);
    expect(syncCards.existsSync(), isTrue);
    expect(interopCard.existsSync(), isTrue);
    expect(settingsField.existsSync(), isTrue);
    expect(sectionList.existsSync(), isTrue);
    expect(updateCard.existsSync(), isTrue);

    final shellSource = shell.readAsStringSync();
    final timelineSource = timelineCard.readAsStringSync();
    final reminderSource = reminderCard.readAsStringSync();
    final syncSource = syncCards.readAsStringSync();
    final interopSource = interopCard.readAsStringSync();
    final fieldSource = settingsField.readAsStringSync();
    final sectionSource = sectionList.readAsStringSync();
    final updateSource = updateCard.readAsStringSync();

    expect(shellSource, contains("import 'timeline_settings_card.dart';"));
    expect(shellSource, contains("import 'reminder_settings_card.dart';"));
    expect(shellSource, contains("import 'sync_settings_cards.dart';"));
    expect(shellSource, contains("import 'interop_settings_card.dart';"));
    expect(
        shellSource, contains("import 'version_update_settings_card.dart';"));
    expect(shellSource, contains("export 'timeline_settings_card.dart';"));
    expect(shellSource, contains("export 'reminder_settings_card.dart';"));
    expect(shellSource, contains("export 'sync_settings_cards.dart';"));
    expect(shellSource, contains("export 'interop_settings_card.dart';"));
    expect(
        shellSource, contains("export 'version_update_settings_card.dart';"));
    expect(shellSource, contains("part 'settings_section_list.dart';"));

    expect(shellSource, isNot(contains('class TimelineSettingsCard')));
    expect(shellSource, isNot(contains('class ReminderSettingsCard')));
    expect(shellSource, isNot(contains('class CloudSyncSettingsCard')));
    expect(shellSource, isNot(contains('class VersionUpdateSettingsCard')));
    expect(shellSource, isNot(contains('class InteropSettingsCard')));
    expect(shellSource, isNot(contains('class _LanHostPanel')));
    expect(shellSource, isNot(contains('class _LanClientPanel')));
    expect(shellSource, isNot(contains('class _ReminderField')));
    expect(shellSource, isNot(contains('class _UpdateInfoRow')));
    expect(shellSource, isNot(contains('enum _SettingsSection')));
    expect(shellSource, isNot(contains('class _SettingsSectionList')));
    expect(shellSource, isNot(contains('class _SettingsSectionInfo')));

    expect(timelineSource, contains('class TimelineSettingsCard'));
    expect(reminderSource, contains('class ReminderSettingsCard'));
    expect(syncSource, contains('class CloudSyncSettingsCard'));
    expect(syncSource, isNot(contains('class VersionUpdateSettingsCard')));
    expect(interopSource, contains('class InteropSettingsCard'));
    expect(interopSource, contains('class _LanHostPanel'));
    expect(interopSource, contains('class _LanClientPanel'));
    expect(fieldSource, contains('class SettingsField'));
    expect(sectionSource, contains('enum _SettingsSection'));
    expect(sectionSource, contains('class _SettingsSectionList'));
    expect(sectionSource, contains('class _SettingsSectionInfo'));
    expect(updateSource, contains('class VersionUpdateSettingsCard'));
    expect(updateSource, contains('class _UpdateInfoRow'));
    expect(_pureLineCount(shell), lessThanOrEqualTo(250));
    expect(_pureLineCount(syncCards), lessThanOrEqualTo(250));
    expect(_pureLineCount(updateCard), lessThanOrEqualTo(250));
  });
}

int _pureLineCount(File file) {
  return file.readAsLinesSync().where((line) {
    final trimmed = line.trim();
    return trimmed.isNotEmpty &&
        !trimmed.startsWith('//') &&
        !trimmed.startsWith('#') &&
        !trimmed.startsWith('--');
  }).length;
}
