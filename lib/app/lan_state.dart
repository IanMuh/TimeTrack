import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/lan_sync.dart';
import '../data/sync_peer_store.dart';

class LanState extends ChangeNotifier {
  LanState({
    required LanSyncServer lanSyncServer,
    required LanSyncClient lanSyncClient,
  })  : _server = lanSyncServer,
        _client = lanSyncClient;

  final LanSyncServer _server;
  final LanSyncClient _client;

  SyncPeer? lanPeer;

  bool get hasLanPeer => lanPeer != null;

  bool get canHostLan => Platform.isWindows || Platform.isAndroid;

  bool get isLanServerRunning => _server.isRunning;

  String? get lanPairingCode => _server.pairingCode;

  List<String> get lanServerUrls => _server.localUrls;

  Future<void> refreshPeer() async {
    lanPeer = await _client.currentPeer();
    notifyListeners();
  }

  Future<String?> startLanServer() async {
    if (!canHostLan) {
      return '请在 Windows 端开启局域网主机，Android 作为客户端连接。';
    }
    try {
      await _server.start();
      return '局域网主机已开启。';
    } catch (error) {
      return '无法开启局域网主机：$error';
    }
  }

  Future<String> stopLanServer() async {
    await _server.stop();
    return '局域网主机已关闭。';
  }

  Future<String?> pairLanPeer({
    required String baseUrl,
    required String code,
  }) async {
    try {
      lanPeer = await _client.pair(baseUrl: baseUrl, code: code);
      notifyListeners();
      return '局域网主机配对成功。';
    } catch (error) {
      return '局域网配对失败：$error';
    }
  }

  Future<String> clearLanPeer() async {
    await _client.clearPeer();
    lanPeer = null;
    notifyListeners();
    return '已移除局域网主机配对。';
  }
}
