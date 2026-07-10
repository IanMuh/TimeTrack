import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/app_version.dart';
import '../data/app_update_service.dart';

typedef AppVersionLoader = Future<String> Function();
typedef TargetPlatformLoader = TargetPlatform Function();
typedef UpdateStateChanged = void Function();

class UpdateState {
  UpdateState({
    AppUpdateService? updateService,
    AppVersionLoader? appVersionLoader,
    TargetPlatformLoader? targetPlatformLoader,
  })  : _updateService = updateService ?? AppUpdateService.disabled(),
        _checksEnabled = updateService != null,
        _appVersionLoader = appVersionLoader ?? _defaultAppVersionLoader,
        _targetPlatformLoader =
            targetPlatformLoader ?? _defaultTargetPlatformLoader;

  final AppUpdateService _updateService;
  final bool _checksEnabled;
  final AppVersionLoader _appVersionLoader;
  final TargetPlatformLoader _targetPlatformLoader;

  AppUpdateStatus status = AppUpdateStatus.idle;
  AppUpdateInfo? availableUpdate;
  String currentAppVersion = '';
  String? errorMessage;

  bool _startupCheckStarted = false;
  bool _promptShown = false;

  bool get shouldShowPrompt {
    return !_promptShown &&
        status == AppUpdateStatus.available &&
        availableUpdate != null;
  }

  bool beginCheck() {
    if (!_checksEnabled || status == AppUpdateStatus.checking) {
      return false;
    }
    status = AppUpdateStatus.checking;
    errorMessage = null;
    return true;
  }

  Future<void> completeCheck() async {
    try {
      final versionValue = (await _appVersionLoader()).trim();
      currentAppVersion = versionValue;
      final currentVersion = AppVersion.parse(versionValue);
      final result = await _updateService.checkForUpdate(
        currentVersion: currentVersion,
        platform: _targetPlatformLoader(),
      );
      result.when(
        onSuccess: (update) {
          availableUpdate = update;
          status = update == null
              ? AppUpdateStatus.upToDate
              : AppUpdateStatus.available;
          errorMessage = null;
        },
        onFailure: (message) {
          availableUpdate = null;
          status = AppUpdateStatus.failed;
          errorMessage = message;
        },
      );
    } on FormatException catch (error) {
      availableUpdate = null;
      status = AppUpdateStatus.failed;
      errorMessage = 'Invalid app version: ${error.source}.';
    } catch (error) {
      availableUpdate = null;
      status = AppUpdateStatus.failed;
      errorMessage = 'Update check failed: $error';
    }
  }

  Future<bool> openDownload() async {
    final update = availableUpdate;
    if (update == null) {
      return false;
    }
    final result = await _updateService.openDownload(update);
    result.when(
      onSuccess: (_) {
        errorMessage = null;
      },
      onFailure: (message) {
        errorMessage = message;
      },
    );
    return true;
  }

  bool markPromptShown() {
    if (_promptShown) {
      return false;
    }
    _promptShown = true;
    return true;
  }

  bool markStartupCheckStarted() {
    if (!_checksEnabled || _startupCheckStarted) {
      return false;
    }
    _startupCheckStarted = true;
    return true;
  }

  void markPromptShownAndNotify(UpdateStateChanged notifyListeners) {
    if (!markPromptShown()) {
      return;
    }
    notifyListeners();
  }

  Future<void> checkForUpdates({
    bool silent = false,
    UpdateStateChanged? notifyListeners,
  }) async {
    if (!beginCheck()) {
      return;
    }

    if (!silent) {
      notifyListeners?.call();
    }

    await completeCheck();
    notifyListeners?.call();
  }

  Future<void> openDownloadAndNotify(
    UpdateStateChanged notifyListeners,
  ) async {
    if (await openDownload()) {
      notifyListeners();
    }
  }

  void startStartupCheck({
    required UpdateStateChanged notifyListeners,
  }) {
    if (!markStartupCheckStarted()) {
      return;
    }
    unawaited(checkForUpdates(
      silent: true,
      notifyListeners: notifyListeners,
    ));
  }
}

Future<String> _defaultAppVersionLoader() async {
  final packageInfo = await PackageInfo.fromPlatform();
  final version = packageInfo.version.trim();
  final buildNumber = packageInfo.buildNumber.trim();
  if (buildNumber.isEmpty || version.contains('+')) {
    return version;
  }
  return '$version+$buildNumber';
}

TargetPlatform _defaultTargetPlatformLoader() => defaultTargetPlatform;
