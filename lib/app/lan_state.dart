import 'dart:io';

import '../data/lan_sync.dart';
import '../data/sync_peer_store.dart';

typedef CanHostLan = bool Function();

class LanState {
  LanState({
    required LanSyncServer server,
    required LanSyncClient client,
    CanHostLan? canHost,
  })  : _server = server,
        _client = client,
        _canHost = canHost ?? _defaultCanHostLan;

  final LanSyncServer _server;
  final LanSyncClient _client;
  final CanHostLan _canHost;

  SyncPeer? peer;
  String? message;

  bool get hasPeer => peer != null;

  bool get canHost => _canHost();

  bool get isServerRunning => _server.isRunning;

  String? get pairingCode => _server.pairingCode;

  List<String> get serverUrls => _server.localUrls;

  int? get serverPort => _server.port;

  Future<void> loadPeer() async {
    peer = await _client.currentPeer();
  }

  Future<void> startServer() async {
    if (!canHost) {
      message = '请在 Windows 端开启局域网主机，Android 作为客户端连接。';
      return;
    }
    try {
      await _server.start();
      message = '局域网主机已开启。';
    } catch (error) {
      message = '无法开启局域网主机：$error';
    }
  }

  Future<void> stopServer() async {
    await _server.stop();
    message = '局域网主机已关闭。';
  }

  Future<bool> pairPeer({
    required String baseUrl,
    required String code,
  }) async {
    try {
      peer = await _client.pair(baseUrl: baseUrl, code: code);
      message = '局域网主机配对成功。';
      return true;
    } catch (error) {
      message = '局域网配对失败：$error';
      return false;
    }
  }

  Future<void> clearPeer() async {
    await _client.clearPeer();
    peer = null;
    message = '已移除局域网主机配对。';
  }

  Future<void> syncNow() {
    return _client.syncNow();
  }

  Future<void> stopServerForDispose() {
    return _server.stop();
  }
}

bool _defaultCanHostLan() => Platform.isWindows || Platform.isAndroid;
