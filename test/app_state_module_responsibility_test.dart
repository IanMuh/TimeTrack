import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppState state and coordinator modules stay split and tested', () {
    const modules = {
      'activity': (
        'lib/app/activity_state.dart',
        'test/activity_state_test.dart'
      ),
      'activity mutation': (
        'lib/app/activity_mutation_state.dart',
        'test/activity_mutation_state_test.dart',
      ),
      'entry': ('lib/app/entry_state.dart', 'test/entry_state_test.dart'),
      'entry mutation': (
        'lib/app/entry_mutation_state.dart',
        'test/entry_mutation_state_test.dart',
      ),
      'category': (
        'lib/app/category_state.dart',
        'test/category_state_test.dart',
      ),
      'category mutation': (
        'lib/app/category_mutation_state.dart',
        'test/category_mutation_state_test.dart',
      ),
      'sync': ('lib/app/sync_state.dart', 'test/sync_state_test.dart'),
      'sync coordinator': (
        'lib/app/sync_coordinator_state.dart',
        'test/sync_coordinator_state_test.dart',
      ),
      'lan': ('lib/app/lan_state.dart', 'test/lan_state_test.dart'),
      'lan coordinator': (
        'lib/app/lan_coordinator_state.dart',
        'test/lan_coordinator_state_test.dart',
      ),
      'interop': (
        'lib/app/interop_state.dart',
        'test/interop_state_test.dart',
      ),
      'interop coordinator': (
        'lib/app/interop_coordinator_state.dart',
        'test/interop_coordinator_state_test.dart',
      ),
      'settings': (
        'lib/app/settings_state.dart',
        'test/settings_state_test.dart',
      ),
      'settings coordinator': (
        'lib/app/settings_coordinator_state.dart',
        'test/settings_coordinator_state_test.dart',
      ),
      'reminder': (
        'lib/app/reminder_state.dart',
        'test/reminder_state_test.dart',
      ),
      'reminder coordinator': (
        'lib/app/reminder_coordinator_state.dart',
        'test/reminder_coordinator_state_test.dart',
      ),
      'undo history': (
        'lib/app/undo_history_state.dart',
        'test/undo_history_state_test.dart',
      ),
      'undo coordinator': (
        'lib/app/undo_coordinator_state.dart',
        'test/undo_coordinator_state_test.dart',
      ),
      'runtime': (
        'lib/app/app_runtime_state.dart',
        'test/app_runtime_state_test.dart',
      ),
      'update': ('lib/app/update_state.dart', 'test/update_state_test.dart'),
      'lifecycle': (
        'lib/app/app_lifecycle_state.dart',
        'test/app_lifecycle_state_test.dart',
      ),
      'refresh': (
        'lib/app/app_refresh_state.dart',
        'test/app_refresh_state_test.dart',
      ),
    };

    for (final entry in modules.entries) {
      final source = File(entry.value.$1);
      final test = File(entry.value.$2);

      expect(source.existsSync(), isTrue, reason: '${entry.key} source');
      expect(test.existsSync(), isTrue, reason: '${entry.key} test');
      expect(
        _pureLineCount(source),
        lessThanOrEqualTo(250),
        reason: '${entry.key} state/coordinator exceeded module budget',
      );
    }
  });

  test('AppState shell only constructs and exposes modules', () {
    final shell = File('lib/app/app_state.dart').readAsStringSync();

    expect(shell, contains('buildAppStateModules('));
    expect(shell, contains('_bindSubStateListeners();'));
    expect(shell, contains('late final AppStateModules _modules;'));
    expect(shell, isNot(contains('Future<void> refresh(')));
    expect(shell, isNot(contains('Future<void> switchTo(')));
    expect(shell, isNot(contains('Future<void> sync(')));
    expect(shell, isNot(contains('Future<void> undo(')));
    expect(shell, isNot(contains('Future<TimeRangeStats> statsForRange(')));
    expect(
        _pureLineCount(File('lib/app/app_state.dart')), lessThanOrEqualTo(250));
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
