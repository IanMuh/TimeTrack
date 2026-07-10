part of 'app_state.dart';

mixin AppStateSyncFacade on ChangeNotifier {
  SyncState get _syncState;
  SyncCoordinatorState get _syncCoordinatorState;

  bool get isSyncing => _syncState.isSyncing;

  set isSyncing(bool value) {
    _syncState.isSyncing = value;
  }

  SyncStatus get syncStatus => _syncState.status;

  set syncStatus(SyncStatus value) {
    _syncState.status = value;
  }

  bool get canSync => _syncCoordinatorState.canSync;

  bool get canCloudSync => _syncCoordinatorState.canCloudSync;

  bool get isSignedIn => _syncCoordinatorState.isSignedIn;

  bool get hasLanPeer => _syncCoordinatorState.hasLanPeer;

  bool get hasSyncTarget => _syncCoordinatorState.hasSyncTarget;

  SyncTarget get currentSyncTarget => _syncCoordinatorState.currentSyncTarget;

  Future<void> sync() => _syncCoordinatorState.sync();
}
