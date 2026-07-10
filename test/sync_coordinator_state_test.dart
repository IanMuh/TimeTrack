import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/sync_coordinator_state.dart';
import 'package:timetrack/app/sync_state.dart';
import 'package:timetrack/data/sync_status_store.dart';

void main() {
  test('AppState sync facade stays separate from runtime facade', () {
    final syncFacade = File('lib/app/app_state_sync_facade.dart');
    final runtimeFacade = File('lib/app/app_state_runtime_facade.dart');
    final coreFacade = File('lib/app/app_state_core_facade.dart');

    expect(syncFacade.existsSync(), isTrue);

    final syncSource = syncFacade.readAsStringSync();
    final runtimeSource = runtimeFacade.readAsStringSync();
    final coreSource = coreFacade.readAsStringSync();

    expect(syncSource, contains('mixin AppStateSyncFacade'));
    expect(syncSource, contains('bool get isSyncing'));
    expect(syncSource, contains('set isSyncing(bool value)'));
    expect(syncSource, contains('SyncStatus get syncStatus'));
    expect(syncSource, contains('set syncStatus(SyncStatus value)'));
    expect(syncSource, contains('bool get canSync'));
    expect(syncSource, contains('bool get canCloudSync'));
    expect(syncSource, contains('bool get isSignedIn'));
    expect(syncSource, contains('bool get hasLanPeer'));
    expect(syncSource, contains('bool get hasSyncTarget'));
    expect(syncSource, contains('SyncTarget get currentSyncTarget'));
    expect(syncSource, contains('Future<void> sync()'));
    expect(runtimeSource, isNot(contains('bool get canSync')));
    expect(runtimeSource, isNot(contains('bool get canCloudSync')));
    expect(runtimeSource, isNot(contains('bool get isSignedIn')));
    expect(runtimeSource, isNot(contains('bool get hasLanPeer')));
    expect(runtimeSource, isNot(contains('bool get hasSyncTarget')));
    expect(runtimeSource, isNot(contains('SyncTarget get currentSyncTarget')));
    expect(runtimeSource, isNot(contains('Future<void> sync()')));
    expect(coreSource, isNot(contains('bool get isSyncing')));
    expect(coreSource, isNot(contains('set isSyncing(bool value)')));
    expect(coreSource, isNot(contains('SyncStatus get syncStatus')));
    expect(coreSource, isNot(contains('set syncStatus(SyncStatus value)')));
  });

  test('exposes sync capabilities and current target', () {
    var canCloudSync = true;
    var isSignedIn = false;
    var hasLanPeer = false;
    final coordinator = _buildCoordinator(
      canCloudSync: () => canCloudSync,
      isSignedIn: () => isSignedIn,
      hasLanPeer: () => hasLanPeer,
    );

    expect(coordinator.canSync, isTrue);
    expect(coordinator.hasSyncTarget, isFalse);
    expect(coordinator.currentSyncTarget, SyncTarget.none);

    isSignedIn = true;
    expect(coordinator.hasSyncTarget, isTrue);
    expect(coordinator.currentSyncTarget, SyncTarget.cloud);

    hasLanPeer = true;
    expect(coordinator.currentSyncTarget, SyncTarget.cloudLan);

    isSignedIn = false;
    canCloudSync = false;
    expect(coordinator.canSync, isTrue);
    expect(coordinator.currentSyncTarget, SyncTarget.lan);
  });

  test('sync skips work and notifications when no target exists', () async {
    String? errorMessage = 'old error';
    var notifyCount = 0;
    var refreshCount = 0;
    var lanSyncCount = 0;
    final coordinator = _buildCoordinator(
      canCloudSync: () => true,
      isSignedIn: () => false,
      hasLanPeer: () => false,
      runLanSync: () async {
        lanSyncCount += 1;
      },
      refresh: () async {
        refreshCount += 1;
      },
      setErrorMessage: (message) {
        errorMessage = message;
      },
      notifyListeners: () {
        notifyCount += 1;
      },
    );

    await coordinator.sync();

    expect(lanSyncCount, 0);
    expect(refreshCount, 0);
    expect(notifyCount, 0);
    expect(errorMessage, 'old error');
  });

  test('sync publishes partial failure message after state notifications',
      () async {
    String? errorMessage;
    var notifyCount = 0;
    var refreshCount = 0;
    final coordinator = _buildCoordinator(
      isSignedIn: () => false,
      hasLanPeer: () => true,
      runLanSync: () async {
        throw StateError('lan down');
      },
      refresh: () async {
        refreshCount += 1;
      },
      setErrorMessage: (message) {
        errorMessage = message;
      },
      notifyListeners: () {
        notifyCount += 1;
      },
    );

    await coordinator.sync();

    expect(refreshCount, 1);
    expect(errorMessage, contains('同步部分失败'));
    expect(errorMessage, contains('局域网同步'));
    expect(notifyCount, 3);
  });
}

SyncCoordinatorState _buildCoordinator({
  bool Function()? canCloudSync,
  bool Function()? isSignedIn,
  bool Function()? hasLanPeer,
  Future<void> Function()? runLanSync,
  Future<void> Function()? refresh,
  void Function(String? message)? setErrorMessage,
  void Function()? notifyListeners,
}) {
  return SyncCoordinatorState.withHandlers(
    canCloudSync: canCloudSync ?? () => false,
    isSignedIn: isSignedIn ?? () => false,
    hasLanPeer: hasLanPeer ?? () => false,
    runLanSync: runLanSync ?? () async {},
    syncState: SyncState.withHandlers(
      cloudSync: ({since}) async {},
      statusStore: SyncStatusStore.memory(),
    ),
    setErrorMessage: setErrorMessage ?? (_) {},
    notifyListeners: notifyListeners ?? () {},
    refresh: refresh ?? () async {},
  );
}
