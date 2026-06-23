import 'package:flutter/foundation.dart';

import '../data/lan_sync.dart';
import '../data/sync_service.dart';

class SyncState extends ChangeNotifier {
  SyncState({
    required SyncService syncService,
    required LanSyncClient lanSyncClient,
  })  : _syncService = syncService,
        _lanSyncClient = lanSyncClient;

  final SyncService _syncService;
  final LanSyncClient _lanSyncClient;

  bool isSyncing = false;
  bool hasLanPeer = false;

  bool get canCloudSync => _syncService.isCloudEnabled;

  bool get isSignedIn => _syncService.isCloudSignedIn;

  bool get canSync => canCloudSync || hasLanPeer;

  bool get hasSyncTarget => isSignedIn || hasLanPeer;

  Future<void> sendMagicLink(String email) async {
    await _syncService.sendMagicLink(email);
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    await _syncService.verifyEmailOtp(email: email, token: token);
  }

  Future<void> signOut() async {
    await _syncService.signOut();
  }

  /// Returns a list of error messages (empty = success, null = skipped).
  Future<List<String>?> sync() async {
    if (!hasSyncTarget) {
      return null;
    }
    isSyncing = true;
    notifyListeners();
    try {
      final errors = <String>[];
      var lanSynced = false;
      if (isSignedIn) {
        try {
          await _syncService.sync();
        } catch (error) {
          errors.add('云同步：$error');
        }
      }
      if (hasLanPeer) {
        try {
          await _lanSyncClient.syncNow();
          lanSynced = true;
        } catch (error) {
          errors.add('局域网同步：$error');
        }
      }
      if (isSignedIn && lanSynced) {
        try {
          await _syncService.sync();
        } catch (error) {
          errors.add('云同步回传：$error');
        }
      }
      return errors;
    } catch (error) {
      return ['同步失败：$error'];
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }
}
