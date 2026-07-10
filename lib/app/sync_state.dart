import '../data/sync_service.dart';
import '../data/sync_status_store.dart';

typedef CloudSyncRunner = Future<void> Function({DateTime? since});
typedef LanSyncRunner = Future<void> Function();
typedef LocalRefreshRunner = Future<void> Function();
typedef SyncStateChanged = void Function();
typedef SyncClock = DateTime Function();

class SyncRunOutcome {
  const SyncRunOutcome({
    required this.didRun,
    this.errorMessage,
  });

  final bool didRun;
  final String? errorMessage;
}

class SyncState {
  SyncState({
    required SyncService syncService,
    required SyncStatusStore statusStore,
    SyncClock? now,
  }) : this.withHandlers(
          cloudSync: syncService.sync,
          statusStore: statusStore,
          now: now,
        );

  SyncState.withHandlers({
    required CloudSyncRunner cloudSync,
    required SyncStatusStore statusStore,
    SyncClock? now,
  })  : _cloudSync = cloudSync,
        _statusStore = statusStore,
        _now = now ?? DateTime.now;

  final CloudSyncRunner _cloudSync;
  final SyncStatusStore _statusStore;
  final SyncClock _now;

  SyncStatusStore get statusStore => _statusStore;

  bool isSyncing = false;
  SyncStatus status = const SyncStatus();

  Future<SyncStatus> loadStatus() async {
    status = await _statusStore.load();
    return status;
  }

  bool hasTarget({
    required bool isSignedIn,
    required bool hasLanPeer,
  }) {
    return targetFor(
          isSignedIn: isSignedIn,
          hasLanPeer: hasLanPeer,
        ) !=
        SyncTarget.none;
  }

  SyncTarget targetFor({
    required bool isSignedIn,
    required bool hasLanPeer,
  }) {
    if (isSignedIn && hasLanPeer) {
      return SyncTarget.cloudLan;
    }
    if (isSignedIn) {
      return SyncTarget.cloud;
    }
    if (hasLanPeer) {
      return SyncTarget.lan;
    }
    return SyncTarget.none;
  }

  Future<SyncRunOutcome> run({
    required bool isSignedIn,
    required bool hasLanPeer,
    required LanSyncRunner runLanSync,
    required LocalRefreshRunner refresh,
    SyncStateChanged? onStateChanged,
  }) async {
    final target = targetFor(
      isSignedIn: isSignedIn,
      hasLanPeer: hasLanPeer,
    );
    if (target == SyncTarget.none) {
      return const SyncRunOutcome(didRun: false);
    }

    final cloudSince = _cloudSyncSince();
    isSyncing = true;
    onStateChanged?.call();
    try {
      final errors = <String>[];
      var lanSynced = false;
      if (isSignedIn) {
        try {
          await _cloudSync(since: cloudSince);
        } catch (error) {
          errors.add('云同步：$error');
        }
      }
      if (hasLanPeer) {
        try {
          await runLanSync();
          lanSynced = true;
        } catch (error) {
          errors.add('局域网同步：$error');
        }
      }
      if (isSignedIn && lanSynced) {
        try {
          await _cloudSync();
        } catch (error) {
          errors.add('云同步回传：$error');
        }
      }
      await refresh();
      if (errors.isEmpty) {
        status = await _statusStore.markSuccess(
          at: _now(),
          target: target,
        );
        return const SyncRunOutcome(didRun: true);
      }

      final message = '同步部分失败：${errors.join('；')}';
      status = await _statusStore.markFailure(
        error: message,
        target: target,
      );
      return SyncRunOutcome(didRun: true, errorMessage: message);
    } catch (error) {
      final message = '同步失败：$error';
      status = await _statusStore.markFailure(
        error: message,
        target: target,
      );
      return SyncRunOutcome(didRun: true, errorMessage: message);
    } finally {
      isSyncing = false;
      onStateChanged?.call();
    }
  }

  DateTime? _cloudSyncSince() {
    final lastTarget = status.lastTarget;
    if (lastTarget != null && lastTarget.includesCloud) {
      return status.lastSuccessfulSyncAt;
    }
    return null;
  }
}
