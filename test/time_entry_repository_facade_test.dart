import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TimeEntryRepository AppResult facade stays separate from raw logic',
      () {
    final shell = File('lib/data/time_entry_repository.dart');
    final facade = File('lib/data/time_entry_repository_result_facade.dart');

    expect(facade.existsSync(), isTrue);

    final shellSource = shell.readAsStringSync();
    final facadeSource = facade.readAsStringSync();

    expect(
      shellSource,
      contains("part 'time_entry_repository_result_facade.dart';"),
    );
    expect(
      shellSource,
      contains('TimeEntryRepositoryResultFacade'),
    );
    expect(
      shellSource,
      isNot(
          contains('// Time entry repository — AppResult-wrapped public API')),
    );
    expect(shellSource, isNot(contains('AppFailure(')));
    expect(facadeSource, contains('mixin TimeEntryRepositoryResultFacade'));
    expect(
        facadeSource, contains('Future<AppResult<TimeEntry?>> runningEntry()'));
    expect(facadeSource, contains("AppFailure('Failed to get running entry:"));
    expect(facadeSource, contains('Future<TimeEntry?> _runningEntry()'));
    expect(facadeSource, contains('Future<void> _replaceEntryIfRemoteNewer('));
  });

  test('TimeEntryRepository query logic stays separate from command logic', () {
    final shell = File('lib/data/time_entry_repository.dart');
    final queryLogic = File('lib/data/time_entry_repository_query_logic.dart');

    expect(queryLogic.existsSync(), isTrue);

    final shellSource = shell.readAsStringSync();
    final querySource = queryLogic.readAsStringSync();

    expect(
      shellSource,
      contains("part 'time_entry_repository_query_logic.dart';"),
    );
    expect(
      shellSource,
      contains('TimeEntryRepositoryResultFacade'),
    );
    expect(
      shellSource,
      contains('TimeEntryRepositoryQueryLogic'),
    );
    expect(shellSource, isNot(contains('Future<TimeEntry?> _runningEntry()')));
    expect(
      shellSource,
      isNot(contains('Future<List<TimeEntry>> _allEntries()')),
    );
    expect(shellSource, isNot(contains('Future<TimeEntry?> entryById(')));
    expect(querySource, contains('mixin TimeEntryRepositoryQueryLogic'));
    expect(querySource, contains('Future<TimeEntry?> _runningEntry()'));
    expect(querySource, contains('Future<List<TimeEntry>> _entriesForRange('));
    expect(
      querySource,
      contains('Future<EntryMergeCandidate?> _mergeCandidateForEntry('),
    );
    expect(querySource, contains('Future<TimeEntry?> entryById('));
  });

  test('TimeEntryRepository storage helpers stay separate from command logic',
      () {
    final shell = File('lib/data/time_entry_repository.dart');
    final storageLogic =
        File('lib/data/time_entry_repository_storage_logic.dart');

    expect(storageLogic.existsSync(), isTrue);

    final shellSource = shell.readAsStringSync();
    final storageSource = storageLogic.readAsStringSync();

    expect(
      shellSource,
      contains("part 'time_entry_repository_storage_logic.dart';"),
    );
    expect(
      shellSource,
      contains('TimeEntryRepositoryQueryLogic'),
    );
    expect(
      shellSource,
      contains('TimeEntryRepositoryStorageLogic'),
    );
    expect(shellSource, isNot(contains('class _EntryInterval')));
    expect(
      shellSource,
      isNot(contains('List<TimeEntry> _entryRowsForStorage(')),
    );
    expect(
      shellSource,
      isNot(contains('Future<void> _cutOverlappingEntries(')),
    );
    expect(
      shellSource,
      isNot(contains('List<TimeEntry> _splitClosedEntryByLocalDay(')),
    );
    expect(storageSource, contains('class _EntryInterval'));
    expect(storageSource, contains('mixin TimeEntryRepositoryStorageLogic'));
    expect(storageSource, contains('List<TimeEntry> _entryRowsForStorage('));
    expect(storageSource, contains('Future<void> _cutOverlappingEntries('));
    expect(storageSource,
        contains('List<TimeEntry> _splitClosedEntryByLocalDay('));
  });

  test('TimeEntryRepository support helpers stay separate from command logic',
      () {
    final shell = File('lib/data/time_entry_repository.dart');
    final supportLogic =
        File('lib/data/time_entry_repository_support_logic.dart');

    expect(supportLogic.existsSync(), isTrue);

    final shellSource = shell.readAsStringSync();
    final supportSource = supportLogic.readAsStringSync();

    expect(
      shellSource,
      contains("part 'time_entry_repository_support_logic.dart';"),
    );
    expect(shellSource, contains('TimeEntryRepositorySupportLogic'));
    expect(shellSource, isNot(contains('ActionLog _buildActionLog(')));
    expect(shellSource, isNot(contains('Future<void> _insertActionLog(')));
    expect(shellSource, isNot(contains('Future<String> _currentDeviceId(')));
    expect(supportSource, contains('mixin TimeEntryRepositorySupportLogic'));
    expect(supportSource, contains('ActionLog _buildActionLog('));
    expect(supportSource, contains('Future<void> _insertActionLog('));
    expect(supportSource, contains('Future<String> _currentDeviceId('));
  });

  test('TimeEntryRepository normalization logic stays separate from commands',
      () {
    final shell = File('lib/data/time_entry_repository.dart');
    final normalizationLogic =
        File('lib/data/time_entry_repository_normalization_logic.dart');

    expect(normalizationLogic.existsSync(), isTrue);

    final shellSource = shell.readAsStringSync();
    final normalizationSource = normalizationLogic.readAsStringSync();

    expect(
      shellSource,
      contains("part 'time_entry_repository_normalization_logic.dart';"),
    );
    expect(shellSource, contains('TimeEntryRepositoryNormalizationLogic'));
    expect(
      shellSource,
      isNot(contains('Future<void> rolloverRunningEntriesIfNeeded(')),
    );
    expect(
      shellSource,
      isNot(contains('Future<void> normalizeRunningEntriesAfterMerge(')),
    );
    expect(
      shellSource,
      isNot(contains('Future<void> mergeAdjacentUnassignedEntries(')),
    );
    expect(normalizationSource,
        contains('mixin TimeEntryRepositoryNormalizationLogic'));
    expect(normalizationSource,
        contains('Future<void> rolloverRunningEntriesIfNeeded('));
    expect(normalizationSource,
        contains('Future<void> normalizeRunningEntriesAfterMerge('));
    expect(normalizationSource,
        contains('Future<void> mergeAdjacentUnassignedEntries('));
    expect(normalizationSource, contains('Future<void> _startUnassigned('));
  });

  test('TimeEntryRepository command logic stays outside the dependency shell',
      () {
    final shell = File('lib/data/time_entry_repository.dart');
    final commandLogic =
        File('lib/data/time_entry_repository_command_logic.dart');

    expect(commandLogic.existsSync(), isTrue);

    final shellSource = shell.readAsStringSync();
    final commandSource = commandLogic.readAsStringSync();

    expect(
      shellSource,
      contains("part 'time_entry_repository_command_logic.dart';"),
    );
    expect(shellSource, contains('TimeEntryRepositoryCommandLogic'));
    expect(
        shellSource, isNot(contains('Future<TimeEntry> _switchToActivity(')));
    expect(shellSource, isNot(contains('Future<void> _stopRunning(')));
    expect(
      shellSource,
      isNot(contains('Future<List<TimeEntry>> _saveEntry(')),
    );
    expect(
        shellSource, isNot(contains('Future<List<TimeEntry>> saveEntryRows(')));
    expect(commandSource, contains('mixin TimeEntryRepositoryCommandLogic'));
    expect(commandSource, contains('Future<TimeEntry> _switchToActivity('));
    expect(commandSource, contains('Future<void> _stopRunning('));
    expect(commandSource, contains('Future<List<TimeEntry>> _saveEntry('));
    expect(commandSource, contains('Future<List<TimeEntry>> saveEntryRows('));
    expect(_pureLineCount(shell), lessThanOrEqualTo(250));
  });

  test('TimeEntryRepository edit logic stays outside command orchestration',
      () {
    final shell = File('lib/data/time_entry_repository.dart');
    final commandLogic =
        File('lib/data/time_entry_repository_command_logic.dart');
    final editLogic = File('lib/data/time_entry_repository_edit_logic.dart');

    expect(editLogic.existsSync(), isTrue);

    final shellSource = shell.readAsStringSync();
    final commandSource = commandLogic.readAsStringSync();
    final editSource = editLogic.readAsStringSync();

    expect(shellSource, contains('TimeEntryRepositoryEditLogic'));
    expect(
      commandSource,
      isNot(contains('Future<List<TimeEntry>> _splitEntry')),
    );
    expect(
      commandSource,
      isNot(contains('Future<TimeEntry?> _mergeEntryWithNeighbor(')),
    );
    expect(editSource, contains('mixin TimeEntryRepositoryEditLogic'));
    expect(editSource, contains('Future<List<TimeEntry>> _splitEntry'));
    expect(editSource, contains('Future<TimeEntry?> _mergeEntryWithNeighbor('));
    expect(_pureLineCount(commandLogic), lessThanOrEqualTo(250));
    expect(_pureLineCount(editLogic), lessThanOrEqualTo(250));
  });

  test('TimeEntryRepository command/write methods stay in their parts', () {
    final shellSource =
        File('lib/data/time_entry_repository.dart').readAsStringSync();
    final commandSource =
        File('lib/data/time_entry_repository_command_logic.dart')
            .readAsStringSync();
    final editSource = File('lib/data/time_entry_repository_edit_logic.dart')
        .readAsStringSync();

    const commandMethods = [
      'Future<TimeEntry> _switchToActivity(',
      'Future<void> _stopRunning(',
      'Future<List<TimeEntry>> _saveEntry(',
      'Future<List<TimeEntry>> saveEntryRows(',
    ];
    const editMethods = [
      'Future<List<TimeEntry>> _splitEntry',
      'Future<TimeEntry> _createManualEntry',
      'Future<void> _deleteEntry',
      'Future<TimeEntry?> _mergeEntryWithNeighbor',
      'Future<void> _replaceEntryIfRemoteNewer',
    ];

    for (final method in commandMethods) {
      expect(shellSource, isNot(contains(method)));
      expect(commandSource, contains(method));
    }
    for (final method in editMethods) {
      expect(shellSource, isNot(contains(method)));
      expect(commandSource, isNot(contains(method)));
      expect(editSource, contains(method));
    }
  });

  test('TimeEntryRepository source parts stay below the LOC budget', () {
    final files = [
      File('lib/data/time_entry_repository.dart'),
      File('lib/data/time_entry_repository_result_facade.dart'),
      File('lib/data/time_entry_repository_query_logic.dart'),
      File('lib/data/time_entry_repository_storage_logic.dart'),
      File('lib/data/time_entry_repository_support_logic.dart'),
      File('lib/data/time_entry_repository_normalization_logic.dart'),
      File('lib/data/time_entry_repository_command_logic.dart'),
      File('lib/data/time_entry_repository_edit_logic.dart'),
    ];

    for (final file in files) {
      expect(file.existsSync(), isTrue);
      expect(
        _pureLineCount(file),
        lessThanOrEqualTo(250),
        reason: '${file.path} exceeded the TimeEntryRepository part budget',
      );
    }
  });

  test('TimeEntryRepository generated timestamps use an injected clock', () {
    final shell = File('lib/data/time_entry_repository.dart');
    final commandLogic =
        File('lib/data/time_entry_repository_command_logic.dart');
    final normalizationLogic =
        File('lib/data/time_entry_repository_normalization_logic.dart');
    final editLogic = File('lib/data/time_entry_repository_edit_logic.dart');

    final shellSource = shell.readAsStringSync();
    final commandSource = commandLogic.readAsStringSync();
    final normalizationSource = normalizationLogic.readAsStringSync();
    final editSource = editLogic.readAsStringSync();

    expect(
        shellSource, contains('typedef TimeEntryClock = DateTime Function();'));
    expect(shellSource, contains('TimeEntryClock? clock'));
    for (final source in [commandSource, normalizationSource, editSource]) {
      expect(source, isNot(contains('DateTime.now()')));
      expect(source, contains('_now()'));
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
