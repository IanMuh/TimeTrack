import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/core/app_version.dart';
import 'package:timetrack/core/result.dart';
import 'package:timetrack/data/app_update_service.dart';

import 'test_fixtures.dart';

void main() {
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
