import 'dart:io';

import 'lan_sync_protocol.dart';
import 'repository_interfaces.dart';
import 'sync_bundle.dart';
import 'sync_bundle_store.dart';
import 'sync_peer_store.dart';

class LanSyncClient {
  LanSyncClient({
    required SyncBundleStore bundleStore,
    required IDeviceIdStore deviceIdStore,
    required SyncPeerStore peerStore,
    Duration timeout = const Duration(seconds: 8),
  })  : _bundleStore = bundleStore,
        _deviceIdStore = deviceIdStore,
        _peerStore = peerStore,
        _timeout = timeout;

  final SyncBundleStore _bundleStore;
  final IDeviceIdStore _deviceIdStore;
  final SyncPeerStore _peerStore;
  final Duration _timeout;
  late final LanSyncJsonProtocol _json = LanSyncJsonProtocol(
    timeout: _timeout,
  );
  final SyncBundleCodec _codec = const SyncBundleCodec();

  Future<SyncPeer?> currentPeer() {
    return _peerStore.currentLanClientPeer();
  }

  Future<SyncPeer> pair({
    required String baseUrl,
    required String code,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    final response = await _postJson(
      Uri.parse('$normalizedBaseUrl/pair'),
      {
        'code': code.trim(),
        'source_device_id': await _deviceIdStore.currentDeviceId(),
        'device_name': Platform.localHostname,
      },
    );

    final token = response['token'] as String?;
    final serverDeviceId = response['server_device_id'] as String?;
    if (token == null || token.isEmpty || serverDeviceId == null) {
      throw const LanSyncException('局域网主机返回了无效的配对响应。');
    }

    final peer = SyncPeer(
      id: serverDeviceId,
      kind: SyncPeerKind.lanClient,
      displayName: (response['server_name'] as String?) ?? 'TimeTrack 主机',
      baseUrl: normalizedBaseUrl,
      token: token,
      updatedAt: DateTime.now(),
    );
    await _peerStore.savePeer(peer);
    return peer;
  }

  Future<void> syncNow() async {
    final peer = await currentPeer();
    if (peer == null || peer.baseUrl == null) {
      throw const LanSyncException('还没有配对局域网主机。');
    }

    final response = await _postJson(
      Uri.parse('${peer.baseUrl}/sync'),
      {'bundle': (await _bundleStore.exportBundle()).toJson()},
      token: peer.token,
    );
    final bundle =
        _codec.fromJson(requireLanJsonObject(response['bundle'], 'bundle'));
    await _bundleStore.mergeBundle(bundle);
  }

  Future<void> clearPeer() {
    return _peerStore.clearLanClientPeer();
  }

  Future<Map<String, Object?>> _postJson(
    Uri uri,
    Map<String, Object?> body, {
    String? token,
  }) async {
    return _json.postJson(uri, body, token: token);
  }

  String _normalizeBaseUrl(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      throw const LanSyncException('请输入局域网主机地址。');
    }
    if (!normalized.contains('://')) {
      normalized = 'http://$normalized';
    }
    final uri = Uri.parse(normalized);
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw const LanSyncException('局域网主机地址格式不正确。');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const LanSyncException('局域网主机地址仅支持 HTTP 或 HTTPS。');
    }
    if (uri.scheme == 'http' && !_isLocalNetworkHost(uri.host)) {
      throw const LanSyncException('HTTP 局域网同步仅支持本机或私有局域网地址。');
    }
    return uri
        .replace(path: '', query: null, fragment: null)
        .toString()
        .replaceFirst(RegExp(r'/$'), '');
  }

  bool _isLocalNetworkHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' ||
        normalized.endsWith('.local') ||
        !normalized.contains('.')) {
      return true;
    }

    final address = InternetAddress.tryParse(host);
    if (address == null) {
      return false;
    }
    if (address.isLoopback || address.isLinkLocal) {
      return true;
    }
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4 && bytes.length == 4) {
      return bytes[0] == 10 ||
          (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
          (bytes[0] == 192 && bytes[1] == 168);
    }
    if (address.type == InternetAddressType.IPv6 && bytes.isNotEmpty) {
      return bytes[0] == 0xfc || bytes[0] == 0xfd;
    }
    return false;
  }
}
