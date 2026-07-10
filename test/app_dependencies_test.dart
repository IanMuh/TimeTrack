import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:timetrack/app/app_dependencies.dart';
import 'package:timetrack/app/app_state.dart';
import 'package:timetrack/data/repository_action_log_repository.dart';
import 'package:timetrack/data/repository_activity_repository.dart';
import 'package:timetrack/data/repository_category_repository.dart';
import 'package:timetrack/data/repository_entry_repository.dart';
import 'package:timetrack/data/repository_seed_repository.dart';
import 'package:timetrack/data/repository_settings_repository.dart';

void main() {
  test('wires an offline AppState when Supabase is not configured', () {
    final dependencies = buildAppDependencies(supabaseClient: null);
    final state = dependencies.appState;
    addTearDown(state.dispose);

    expect(state, isA<AppState>());
    expect(
      dependencies.actionLogRepository,
      isA<RepositoryActionLogRepository>(),
    );
    expect(
      dependencies.activityRepository,
      isA<RepositoryActivityRepository>(),
    );
    expect(
      dependencies.categoryRepository,
      isA<RepositoryCategoryRepository>(),
    );
    expect(dependencies.entryRepository, isA<RepositoryEntryRepository>());
    expect(dependencies.seedRepository, isA<RepositorySeedRepository>());
    expect(
      dependencies.settingsRepository,
      isA<RepositorySettingsRepository>(),
    );
    expect(dependencies.undoRepository, isNotNull);
    expect(dependencies.syncService.isCloudEnabled, isFalse);
    expect(dependencies.syncService.isEnabled, isFalse);
  });

  test('uses an isolated container for each dependency build', () {
    final first = buildAppDependencies(supabaseClient: null);
    final second = buildAppDependencies(supabaseClient: null);
    final firstState = first.appState;
    final secondState = second.appState;
    addTearDown(firstState.dispose);
    addTearDown(secondState.dispose);

    expect(secondState, isNot(same(firstState)));
    expect(second.repository, isNot(same(first.repository)));
    expect(
      second.actionLogRepository,
      isNot(same(first.actionLogRepository)),
    );
    expect(
      second.activityRepository,
      isNot(same(first.activityRepository)),
    );
    expect(
      second.categoryRepository,
      isNot(same(first.categoryRepository)),
    );
    expect(second.entryRepository, isNot(same(first.entryRepository)));
    expect(second.seedRepository, isNot(same(first.seedRepository)));
    expect(
      second.settingsRepository,
      isNot(same(first.settingsRepository)),
    );
    expect(second.undoRepository, isNot(same(first.undoRepository)));
    expect(second.database, isNot(same(first.database)));
  });

  test('offline dependencies write and export local data without Supabase',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'timetrack_offline_dependencies_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dependencies = buildAppDependencies(
      supabaseClient: null,
      databasePath: p.join(directory.path, 'timetrack.sqlite'),
    );
    final state = dependencies.appState;
    addTearDown(() async {
      state.dispose();
      final db = await dependencies.database.db;
      await db.close();
    });

    expect(dependencies.syncService.isCloudEnabled, isFalse);
    expect(dependencies.syncService.isEnabled, isFalse);

    await dependencies.repository.ensureSeedData();
    final activity = await dependencies.repository.createActivity(
      name: 'Offline work',
      color: 0xff2563eb,
    );
    final entry = await dependencies.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 10),
      note: 'local only',
    );

    final entries = await dependencies.repository.entriesForDay(
      DateTime(2026, 1, 1),
    );
    final bundle = await dependencies.repository.exportBundle();

    expect(entries.map((item) => item.id), contains(entry.id));
    expect(bundle.sourceDeviceId, isNotEmpty);
    expect(bundle.activities.map((item) => item.id), contains(activity.id));
    expect(bundle.timeEntries.map((item) => item.id), contains(entry.id));
  });
}
