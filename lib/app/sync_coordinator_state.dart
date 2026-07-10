import '../data/sync_status_store.dart';
import '../data/sync_service.dart';
import 'lan_state.dart';
import 'sync_state.dart';

typedef SyncFlagReader = bool Function();
typedef SyncErrorSetter = void Function(String? message);

class SyncCoordinatorState {
  SyncCoordinatorState({
    required SyncService syncService,
    required LanState lanState,
    required SyncState syncState,
    required SyncErrorSetter setErrorMessage,
    required SyncStateChanged notifyListeners,
    required LocalRefreshRunner refresh,
  }) : this.withHandlers(
          canCloudSync: () => syncService.isCloudEnabled,
          isSignedIn: () => syncService.isCloudSignedIn,
          hasLanPeer: () => lanState.hasPeer,
          runLanSync: lanState.syncNow,
          syncState: syncState,
          setErrorMessage: setErrorMessage,
          notifyListeners: notifyListeners,
          refresh: refresh,
        );

  const SyncCoordinatorState.withHandlers({
    required SyncFlagReader canCloudSync,
    required SyncFlagReader isSignedIn,
    required SyncFlagReader hasLanPeer,
    required LanSyncRunner runLanSync,
    required SyncState syncState,
    required SyncErrorSetter setErrorMessage,
    required SyncStateChanged notifyListeners,
    required LocalRefreshRunner refresh,
  })  : _canCloudSync = canCloudSync,
        _isSignedIn = isSignedIn,
        _hasLanPeer = hasLanPeer,
        _runLanSync = runLanSync,
        _syncState = syncState,
        _setErrorMessage = setErrorMessage,
        _notifyListeners = notifyListeners,
        _refresh = refresh;

  final SyncFlagReader _canCloudSync;
  final SyncFlagReader _isSignedIn;
  final SyncFlagReader _hasLanPeer;
  final LanSyncRunner _runLanSync;
  final SyncState _syncState;
  final SyncErrorSetter _setErrorMessage;
  final SyncStateChanged _notifyListeners;
  final LocalRefreshRunner _refresh;

  bool get canSync => canCloudSync || hasLanPeer;

  bool get canCloudSync => _canCloudSync();

  bool get isSignedIn => _isSignedIn();

  bool get hasLanPeer => _hasLanPeer();

  bool get hasSyncTarget => _syncState.hasTarget(
        isSignedIn: isSignedIn,
        hasLanPeer: hasLanPeer,
      );

  SyncTarget get currentSyncTarget => _syncState.targetFor(
        isSignedIn: isSignedIn,
        hasLanPeer: hasLanPeer,
      );

  Future<void> sync() async {
    final outcome = await _syncState.run(
      isSignedIn: isSignedIn,
      hasLanPeer: hasLanPeer,
      runLanSync: _runLanSync,
      refresh: _refresh,
      onStateChanged: _notifyListeners,
    );
    if (outcome.didRun) {
      _setErrorMessage(outcome.errorMessage);
      _notifyListeners();
    }
  }
}
