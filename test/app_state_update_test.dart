import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/core/app_version.dart';
import 'package:timetrack/core/result.dart';
import 'package:timetrack/data/app_update_service.dart';
import 'package:timetrack/domain/action_log.dart';

import 'test_fixtures.dart';

void main() {
  test('AppState update facade stays separate from runtime facade', () {
    final updateFacade = File('lib/app/app_state_update_facade.dart');
    final runtimeFacade = File('lib/app/app_state_runtime_facade.dart');
    final coreFacade = File('lib/app/app_state_core_facade.dart');

    expect(updateFacade.existsSync(), isTrue);

    final updateSource = updateFacade.readAsStringSync();
    final runtimeSource = runtimeFacade.readAsStringSync();
    final coreSource = coreFacade.readAsStringSync();

    expect(updateSource, contains('mixin AppStateUpdateFacade'));
    expect(updateSource, contains('AppUpdateStatus get updateStatus'));
    expect(updateSource, contains('set updateStatus(AppUpdateStatus value)'));
    expect(updateSource, contains('AppUpdateInfo? get availableUpdate'));
    expect(
      updateSource,
      contains('set availableUpdate(AppUpdateInfo? value)'),
    );
    expect(updateSource, contains('String get currentAppVersion'));
    expect(updateSource, contains('set currentAppVersion(String value)'));
    expect(updateSource, contains('String? get updateErrorMessage'));
    expect(
      updateSource,
      contains('set updateErrorMessage(String? value)'),
    );
    expect(updateSource, contains('bool get shouldShowUpdatePrompt'));
    expect(updateSource, contains('void markUpdatePromptShown()'));
    expect(updateSource, contains('Future<void> checkForUpdates'));
    expect(updateSource, contains('Future<void> openUpdateDownload()'));
    expect(updateSource, contains('void _startStartupUpdateCheck()'));
    expect(
      runtimeSource,
      isNot(contains('bool get shouldShowUpdatePrompt')),
    );
    expect(runtimeSource, isNot(contains('void markUpdatePromptShown()')));
    expect(runtimeSource, isNot(contains('Future<void> checkForUpdates')));
    expect(runtimeSource, isNot(contains('Future<void> openUpdateDownload()')));
    expect(runtimeSource, isNot(contains('void _startStartupUpdateCheck()')));
    expect(coreSource, isNot(contains('AppUpdateStatus get updateStatus')));
    expect(
        coreSource, isNot(contains('set updateStatus(AppUpdateStatus value)')));
    expect(coreSource, isNot(contains('AppUpdateInfo? get availableUpdate')));
    expect(
      coreSource,
      isNot(contains('set availableUpdate(AppUpdateInfo? value)')),
    );
    expect(coreSource, isNot(contains('String get currentAppVersion')));
    expect(coreSource, isNot(contains('set currentAppVersion(String value)')));
    expect(coreSource, isNot(contains('String? get updateErrorMessage')));
    expect(
      coreSource,
      isNot(contains('set updateErrorMessage(String? value)')),
    );
  });

  test('initialize starts update check without blocking local startup',
      () async {
    final fixture = await buildTestAppFixture(refresh: false);
    final updateCompleter = Completer<AppResult<AppUpdateInfo?>>();
    final service = _FakeUpdateService(
      check: ({
        required AppVersion currentVersion,
        required TargetPlatform platform,
      }) {
        return updateCompleter.future;
      },
    );
    final state = fixture.repositories.createAppState(
      syncService: fixture.syncService,
      lanSyncServer: fixture.lanSyncServer,
      lanSyncClient: fixture.lanSyncClient,
      fileInteropService: fixture.fileInteropService,
      updateService: service,
      appVersionLoader: () async => '0.1.0-pre',
      targetPlatformLoader: () => TargetPlatform.android,
    );
    addTearDown(() async {
      state.dispose();
      await fixture.dispose();
    });

    await state.initialize().timeout(const Duration(seconds: 2));

    await Future<void>.delayed(Duration.zero);

    expect(service.checkCount, 1);
    expect(state.isLoading, isFalse);
    expect(state.updateStatus, AppUpdateStatus.checking);

    updateCompleter.complete(AppSuccess(_updateInfo()));
    await Future<void>.delayed(Duration.zero);

    expect(state.updateStatus, AppUpdateStatus.available);
    expect(state.availableUpdate?.latestVersion, AppVersion.parse('0.2.0-pre'));
  });

  test('manual check records available update and opens download', () async {
    final fixture = await buildTestAppFixture(refresh: false);
    final service = _FakeUpdateService(
      check: ({
        required AppVersion currentVersion,
        required TargetPlatform platform,
      }) async {
        return AppSuccess(_updateInfo(currentVersion: currentVersion));
      },
    );
    final state = fixture.repositories.createAppState(
      syncService: fixture.syncService,
      lanSyncServer: fixture.lanSyncServer,
      lanSyncClient: fixture.lanSyncClient,
      fileInteropService: fixture.fileInteropService,
      updateService: service,
      appVersionLoader: () async => '0.1.0-pre',
      targetPlatformLoader: () => TargetPlatform.windows,
    );
    addTearDown(() async {
      state.dispose();
      await fixture.dispose();
    });

    await state.checkForUpdates();
    await state.openUpdateDownload();

    expect(state.currentAppVersion, '0.1.0-pre');
    expect(state.updateStatus, AppUpdateStatus.available);
    expect(service.openCount, 1);
  });

  test('failed manual check exposes error and clears stale update', () async {
    final fixture = await buildTestAppFixture(refresh: false);
    final service = _FakeUpdateService(
      check: ({
        required AppVersion currentVersion,
        required TargetPlatform platform,
      }) async {
        return const AppFailure('HTTP 500');
      },
    );
    final state = fixture.repositories.createAppState(
      syncService: fixture.syncService,
      lanSyncServer: fixture.lanSyncServer,
      lanSyncClient: fixture.lanSyncClient,
      fileInteropService: fixture.fileInteropService,
      updateService: service,
      appVersionLoader: () async => '0.1.0-pre',
      targetPlatformLoader: () => TargetPlatform.android,
    )..availableUpdate = _updateInfo();
    addTearDown(() async {
      state.dispose();
      await fixture.dispose();
    });

    await state.checkForUpdates();

    expect(state.updateStatus, AppUpdateStatus.failed);
    expect(state.updateErrorMessage, 'HTTP 500');
    expect(state.availableUpdate, isNull);
  });

  test('switch stop undo and redo refresh the AppState facade', () async {
    final fixture = await buildTestAppFixture();
    final state = fixture.state;
    addTearDown(fixture.dispose);

    final activity = state.activities.firstWhere(
      (activity) => !activity.isUnassigned,
    );
    var notifyCount = 0;
    state.addListener(() {
      notifyCount += 1;
    });
    final initialRevision = state.dataRevision;

    await state.switchTo(activity);

    final runningAfterSwitch = state.runningEntry;
    expect(runningAfterSwitch, isNotNull);
    expect(runningAfterSwitch!.activityId, activity.id);
    expect(state.runningActivity?.id, activity.id);
    expect(state.canUndo, isTrue);
    expect(state.canRedo, isFalse);
    expect(state.undoLabel, '切换到 ${activity.name}');
    expect(
      state.lastUndoChangeSetForTest?.timeEntries
          .any((change) => change.id == runningAfterSwitch.id),
      isTrue,
    );
    expect(state.dataRevision, greaterThan(initialRevision));
    expect(notifyCount, greaterThan(0));
    expect(
      state.dayActionLogs.any(
        (log) =>
            log.actionType == ActionType.switch_ &&
            log.entryId == runningAfterSwitch.id,
      ),
      isTrue,
    );

    final revisionAfterSwitch = state.dataRevision;

    await state.stopCurrent();

    final runningAfterStop = state.runningEntry;
    expect(runningAfterStop, isNotNull);
    expect(runningAfterStop!.activityId, state.unassignedActivity?.id);
    expect(state.runningActivity, isNull);
    expect(state.canUndo, isTrue);
    expect(state.canRedo, isFalse);
    expect(state.undoLabel, '停止当前事项');
    expect(state.dataRevision, greaterThan(revisionAfterSwitch));
    expect(
      state.lastUndoChangeSetForTest?.timeEntries
          .any((change) => change.id == runningAfterSwitch.id),
      isTrue,
    );
    expect(
      state.dayActionLogs.any(
        (log) =>
            log.actionType == ActionType.stop &&
            log.entryId == runningAfterSwitch.id,
      ),
      isTrue,
    );

    final entriesAfterStop =
        await fixture.repository.entriesForDay(state.selectedDay);
    final stoppedEntry = entriesAfterStop.singleWhere(
      (entry) => entry.id == runningAfterSwitch.id,
    );
    expect(stoppedEntry.endAt, isNotNull);

    await state.undo();

    expect(state.runningEntry?.id, runningAfterSwitch.id);
    expect(state.runningEntry?.activityId, activity.id);
    expect(state.runningEntry?.endAt, isNull);
    expect(state.runningActivity?.id, activity.id);
    expect(state.canRedo, isTrue);
    expect(state.redoLabel, '停止当前事项');
    expect(
      state.dayActionLogs.any(
        (log) =>
            log.actionType == ActionType.undo && log.message.contains('停止当前事项'),
      ),
      isTrue,
    );

    await state.redo();

    expect(state.runningEntry?.activityId, state.unassignedActivity?.id);
    expect(state.runningActivity, isNull);
    expect(state.canUndo, isTrue);
    expect(state.canRedo, isFalse);
    expect(state.undoLabel, '停止当前事项');
    expect(
      state.dayActionLogs.any(
        (log) =>
            log.actionType == ActionType.redo && log.message.contains('停止当前事项'),
      ),
      isTrue,
    );
  });
}

AppUpdateInfo _updateInfo({AppVersion? currentVersion}) {
  return AppUpdateInfo(
    currentVersion: currentVersion ?? AppVersion.parse('0.1.0-pre'),
    latestVersion: AppVersion.parse('0.2.0-pre'),
    releaseName: 'TimeTrack 0.2.0-pre',
    releaseNotes: 'Release notes',
    pageUrl: Uri.parse('https://example.com/release'),
    downloadUrl: Uri.parse('https://example.com/app.apk'),
    isPrerelease: true,
  );
}

typedef _CheckHandler = Future<AppResult<AppUpdateInfo?>> Function({
  required AppVersion currentVersion,
  required TargetPlatform platform,
});

class _FakeUpdateService extends AppUpdateService {
  _FakeUpdateService({required _CheckHandler check})
      : _check = check,
        super.disabled();

  final _CheckHandler _check;
  var checkCount = 0;
  var openCount = 0;

  @override
  Future<AppResult<AppUpdateInfo?>> checkForUpdate({
    required AppVersion currentVersion,
    required TargetPlatform platform,
  }) {
    checkCount += 1;
    return _check(currentVersion: currentVersion, platform: platform);
  }

  @override
  Future<AppResult<bool>> openDownload(AppUpdateInfo update) async {
    openCount += 1;
    return const AppSuccess(true);
  }
}
