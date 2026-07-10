import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/update_state.dart';
import 'package:timetrack/core/app_version.dart';
import 'package:timetrack/core/result.dart';
import 'package:timetrack/data/app_update_service.dart';

void main() {
  test('beginCheck enters checking and completeCheck records update', () async {
    final service = _FakeUpdateService(
      check: ({required currentVersion, required platform}) async {
        return AppSuccess(_updateInfo(currentVersion: currentVersion));
      },
    );
    final state = UpdateState(
      updateService: service,
      appVersionLoader: () async => '0.1.0-pre',
      targetPlatformLoader: () => TargetPlatform.windows,
    );

    expect(state.beginCheck(), isTrue);
    expect(state.status, AppUpdateStatus.checking);
    expect(state.beginCheck(), isFalse);

    await state.completeCheck();

    expect(state.currentAppVersion, '0.1.0-pre');
    expect(state.status, AppUpdateStatus.available);
    expect(state.availableUpdate?.latestVersion, AppVersion.parse('0.2.0-pre'));
    expect(state.errorMessage, isNull);
    expect(service.checkCount, 1);
  });

  test('failed check clears stale update and exposes message', () async {
    final state = UpdateState(
      updateService: _FakeUpdateService(
        check: ({required currentVersion, required platform}) async {
          return const AppFailure('HTTP 500');
        },
      ),
      appVersionLoader: () async => '0.1.0-pre',
      targetPlatformLoader: () => TargetPlatform.android,
    )..availableUpdate = _updateInfo();

    expect(state.beginCheck(), isTrue);
    await state.completeCheck();

    expect(state.status, AppUpdateStatus.failed);
    expect(state.availableUpdate, isNull);
    expect(state.errorMessage, 'HTTP 500');
  });

  test('openDownload updates error only when an update exists', () async {
    final service = _FakeUpdateService(
      check: ({required currentVersion, required platform}) async {
        return const AppSuccess(null);
      },
      openDownloadResult: const AppFailure('blocked'),
    );
    final state = UpdateState(updateService: service);

    expect(await state.openDownload(), isFalse);

    state.availableUpdate = _updateInfo();

    expect(await state.openDownload(), isTrue);
    expect(state.errorMessage, 'blocked');
    expect(service.openCount, 1);
  });

  test('checkForUpdates notifies before and after manual checks', () async {
    final notifications = <AppUpdateStatus>[];
    final state = UpdateState(
      updateService: _FakeUpdateService(
        check: ({required currentVersion, required platform}) async {
          return const AppSuccess(null);
        },
      ),
      appVersionLoader: () async => '0.1.0-pre',
      targetPlatformLoader: () => TargetPlatform.windows,
    );

    await state.checkForUpdates(
      notifyListeners: () {
        notifications.add(state.status);
      },
    );

    expect(notifications, [
      AppUpdateStatus.checking,
      AppUpdateStatus.upToDate,
    ]);
  });

  test('silent startup check notifies only after completion', () async {
    final notifications = <AppUpdateStatus>[];
    final service = _FakeUpdateService(
      check: ({required currentVersion, required platform}) async {
        return AppSuccess(_updateInfo(currentVersion: currentVersion));
      },
    );
    final state = UpdateState(
      updateService: service,
      appVersionLoader: () async => '0.1.0-pre',
      targetPlatformLoader: () => TargetPlatform.android,
    );

    state.startStartupCheck(
      notifyListeners: () {
        notifications.add(state.status);
      },
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    state.startStartupCheck(
      notifyListeners: () {
        notifications.add(state.status);
      },
    );
    await Future<void>.delayed(Duration.zero);

    expect(service.checkCount, 1);
    expect(notifications, [AppUpdateStatus.available]);
  });
}

AppUpdateInfo _updateInfo({AppVersion? currentVersion}) {
  return AppUpdateInfo(
    currentVersion: currentVersion ?? AppVersion.parse('0.1.0-pre'),
    latestVersion: AppVersion.parse('0.2.0-pre'),
    releaseName: 'TimeTrack 0.2.0-pre',
    releaseNotes: 'Release notes',
    pageUrl: Uri.parse('https://example.com/release'),
    downloadUrl: Uri.parse('https://example.com/app.exe'),
    isPrerelease: true,
  );
}

typedef _CheckHandler = Future<AppResult<AppUpdateInfo?>> Function({
  required AppVersion currentVersion,
  required TargetPlatform platform,
});

class _FakeUpdateService extends AppUpdateService {
  _FakeUpdateService({
    required _CheckHandler check,
    AppResult<bool> openDownloadResult = const AppSuccess(true),
  })  : _check = check,
        _openDownloadResult = openDownloadResult,
        super.disabled();

  final _CheckHandler _check;
  final AppResult<bool> _openDownloadResult;
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
    return _openDownloadResult;
  }
}
