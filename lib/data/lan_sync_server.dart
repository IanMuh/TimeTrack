import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:uuid/uuid.dart';

import 'lan_sync_protocol.dart';
import 'repository_interfaces.dart';
import 'sync_bundle.dart';
import 'sync_bundle_store.dart';
import 'sync_peer_store.dart';

class LanSyncServer {
  LanSyncServer({
    required SyncBundleStore bundleStore,
    required IDeviceIdStore deviceIdStore,
    required SyncPeerStore peerStore,
    List<int>? portCandidates,
    InternetAddress? bindAddress,
  })  : _bundleStore = bundleStore,
        _deviceIdStore = deviceIdStore,
        _peerStore = peerStore,
        _portCandidates =
            portCandidates ?? List<int>.generate(11, (index) => 8787 + index),
        _bindAddress = bindAddress ?? InternetAddress.anyIPv4;

  final SyncBundleStore _bundleStore;
  final IDeviceIdStore _deviceIdStore;
  final SyncPeerStore _peerStore;
  final LanSyncJsonProtocol _json = const LanSyncJsonProtocol();
  final List<int> _portCandidates;
  final InternetAddress _bindAddress;
  final SyncBundleCodec _codec = const SyncBundleCodec();
  final Uuid _uuid = const Uuid();
  final Random _random = Random.secure();

  HttpServer? _server;
  String? _pairingCode;
  DateTime? _pairingCodeGeneratedAt;
  List<String> _localUrls = const [];
  final Map<String, List<DateTime>> _pairAttempts = {};

  static const _maxPairAttempts = 5;
  static const _pairAttemptWindow = Duration(minutes: 1);
  static const _pairingCodeTtl = Duration(minutes: 5);

  bool get isRunning => _server != null;

  int? get port => _server?.port;

  String? get pairingCode => _pairingCode;

  List<String> get localUrls => _localUrls;

  Future<void> start() async {
    if (_server != null) {
      return;
    }

    Object? lastError;
    for (final port in _portCandidates) {
      try {
        final server = await HttpServer.bind(_bindAddress, port);
        _server = server;
        _pairingCode = _generatePairingCode();
        _pairingCodeGeneratedAt = DateTime.now();
        _pairAttempts.clear();
        _localUrls = await _buildLocalUrls(server.port);
        server.listen((request) {
          unawaited(_handleRequest(request));
        });
        return;
      } catch (error) {
        lastError = error;
      }
    }
    throw LanSyncException('无法启动局域网同步服务：$lastError');
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _pairingCode = null;
    _pairingCodeGeneratedAt = null;
    _localUrls = const [];
    _pairAttempts.clear();
    await server?.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/health') {
        await _json.writeResponse(request, {
          'ok': true,
          'device_id': await _deviceIdStore.currentDeviceId(),
        });
        return;
      }

      if (request.method == 'POST' && request.uri.path == '/pair') {
        await _handlePair(request);
        return;
      }

      if (request.method == 'POST' && request.uri.path == '/sync') {
        await _handleSync(request);
        return;
      }

      await _json.writeResponse(
        request,
        {'error': 'Not found.'},
        statusCode: HttpStatus.notFound,
      );
    } catch (error) {
      await _json.writeResponse(
        request,
        {'error': error.toString()},
        statusCode: HttpStatus.internalServerError,
      );
    }
  }

  Future<void> _handlePair(HttpRequest request) async {
    final clientIp = request.connectionInfo?.remoteAddress.address ?? 'unknown';

    _pairAttempts[clientIp]
        ?.removeWhere((t) => DateTime.now().difference(t) > _pairAttemptWindow);
    final attempts = _pairAttempts.putIfAbsent(clientIp, () => []);
    if (attempts.length >= _maxPairAttempts) {
      await _json.writeResponse(
        request,
        {'error': '尝试次数过多，请稍后再试。'},
        statusCode: 429,
      );
      return;
    }
    attempts.add(DateTime.now());

    final generatedAt = _pairingCodeGeneratedAt;
    if (generatedAt != null &&
        DateTime.now().difference(generatedAt) > _pairingCodeTtl) {
      await _json.writeResponse(
        request,
        {'error': '配对码已过期，请重启局域网同步服务。'},
        statusCode: HttpStatus.unauthorized,
      );
      return;
    }

    final body = await _json.readRequest(request);
    final code = body['code'] as String?;
    if (code?.trim() != _pairingCode) {
      await _json.writeResponse(
        request,
        {'error': '配对码不正确。'},
        statusCode: HttpStatus.unauthorized,
      );
      return;
    }

    final sourceDeviceId = (body['source_device_id'] as String?)?.trim();
    final displayName = (body['device_name'] as String?)?.trim();
    final peerId = sourceDeviceId?.isNotEmpty == true
        ? sourceDeviceId!
        : 'lan-client-${_uuid.v4()}';
    final token = _newToken();
    await _peerStore.savePeer(
      SyncPeer(
        id: peerId,
        kind: SyncPeerKind.lanAuthorizedClient,
        displayName: displayName?.isNotEmpty == true ? displayName! : peerId,
        baseUrl: null,
        token: token,
        updatedAt: DateTime.now(),
      ),
    );

    await _json.writeResponse(request, {
      'token': token,
      'server_device_id': await _deviceIdStore.currentDeviceId(),
      'server_name': Platform.localHostname,
    });
  }

  Future<void> _handleSync(HttpRequest request) async {
    final token = _bearerToken(request);
    if (token == null || !await _peerStore.isAuthorizedLanToken(token)) {
      await _json.writeResponse(
        request,
        {'error': '未授权的局域网同步请求。'},
        statusCode: HttpStatus.unauthorized,
      );
      return;
    }

    final body = await _json.readRequest(request);
    final bundle =
        _codec.fromJson(requireLanJsonObject(body['bundle'], 'bundle'));
    await _bundleStore.mergeBundle(bundle);
    await _json.writeResponse(request, {
      'bundle': (await _bundleStore.exportBundle()).toJson(),
    });
  }

  String? _bearerToken(HttpRequest request) {
    final value = request.headers.value(HttpHeaders.authorizationHeader);
    if (value == null || !value.startsWith('Bearer ')) {
      return null;
    }
    return value.substring('Bearer '.length).trim();
  }

  Future<List<String>> _buildLocalUrls(int port) async {
    final urls = <String>{'http://127.0.0.1:$port'};
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) {
          urls.add('http://${address.address}:$port');
        }
      }
    }
    return urls.toList()..sort();
  }

  String _generatePairingCode() {
    return List<int>.generate(6, (_) => _random.nextInt(10)).join();
  }

  String _newToken() {
    return '${_uuid.v4()}-${_uuid.v4()}';
  }
}
