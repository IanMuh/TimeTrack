import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TimeRepository delegation facades live outside the shell', () {
    final shell = File('lib/data/time_repository.dart');
    final facadeFiles = {
      'activity': File('lib/data/time_repository_activity_facade.dart'),
      'category': File('lib/data/time_repository_category_facade.dart'),
      'entry': File('lib/data/time_repository_entry_facade.dart'),
      'actionLog': File('lib/data/time_repository_action_log_facade.dart'),
      'undo': File('lib/data/time_repository_undo_facade.dart'),
      'settings': File('lib/data/time_repository_settings_facade.dart'),
    };

    final shellSource = shell.readAsStringSync();
    for (final file in facadeFiles.values) {
      expect(file.existsSync(), isTrue);
    }

    expect(
        shellSource, contains("part 'time_repository_activity_facade.dart';"));
    expect(
        shellSource, contains("part 'time_repository_category_facade.dart';"));
    expect(shellSource, contains("part 'time_repository_entry_facade.dart';"));
    expect(
      shellSource,
      contains("part 'time_repository_action_log_facade.dart';"),
    );
    expect(shellSource, contains("part 'time_repository_undo_facade.dart';"));
    expect(
        shellSource, contains("part 'time_repository_settings_facade.dart';"));
    expect(_pureLineCount(shell), lessThanOrEqualTo(250));
    expect(
      shellSource,
      isNot(contains('// Activity delegation (unwrap AppResult)')),
    );
    expect(
      shellSource,
      isNot(contains('// Entry delegation (unwrap AppResult)')),
    );
    expect(shellSource, contains('Future<SyncBundle> exportBundle()'));
    expect(
        shellSource, contains('Future<void> mergeBundle(SyncBundle bundle)'));

    expect(
      facadeFiles['activity']!.readAsStringSync(),
      contains('mixin TimeRepositoryActivityFacade'),
    );
    expect(
      facadeFiles['entry']!.readAsStringSync(),
      contains('mixin TimeRepositoryEntryFacade'),
    );
    expect(
      facadeFiles['settings']!.readAsStringSync(),
      contains('mixin TimeRepositorySettingsFacade'),
    );
  });

  test('TimeRepository shell and facade parts avoid AppResult unwrapping', () {
    final files = [
      File('lib/data/time_repository.dart'),
      File('lib/data/time_repository_activity_facade.dart'),
      File('lib/data/time_repository_category_facade.dart'),
      File('lib/data/time_repository_entry_facade.dart'),
      File('lib/data/time_repository_action_log_facade.dart'),
      File('lib/data/time_repository_undo_facade.dart'),
      File('lib/data/time_repository_settings_facade.dart'),
    ];

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('.fold(')));
      expect(source, isNot(contains('throw StateError')));
      expect(source, isNot(contains('AppFailure(')));
      expect(source, isNot(contains('unwrapRepositoryResult(')));
    }
  });

  test('TimeRepository adapters centralize AppResult failure conversion', () {
    final resultSource =
        File('lib/data/repository_result.dart').readAsStringSync();
    final adapterFiles = [
      File('lib/data/repository_action_log_repository.dart'),
      File('lib/data/repository_activity_repository.dart'),
      File('lib/data/repository_category_repository.dart'),
      File('lib/data/repository_entry_repository.dart'),
      File('lib/data/repository_settings_repository.dart'),
      File('lib/data/repository_undo_repository.dart'),
      File('lib/data/sync_bundle_repository.dart'),
    ];

    expect(resultSource, contains('final class RepositoryFailure'));
    expect(
      resultSource,
      contains('final class RepositoryException extends StateError'),
    );
    expect(resultSource, contains('AppFailure(:final message)'));

    for (final file in adapterFiles) {
      expect(file.existsSync(), isTrue);
      expect(
        file.readAsStringSync(),
        contains('unwrapRepositoryResult'),
        reason: '${file.path} should use the shared AppResult boundary',
      );
    }
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
