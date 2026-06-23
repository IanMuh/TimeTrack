import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:uuid/uuid.dart';

import 'repository_interfaces.dart';
import 'sync_bundle.dart';
import 'sync_peer_store.dart';
import 'time_repository.dart';

class LanSyncException implements Exception {
  const LanSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LanSyncServer {
  LanSyncServer({
    required TimeRepository repository,
    required IActivityRepository activityRepository,
    required IDeviceIdStore deviceIdStore,
    required ITimeEntryRepository timeEntryRepository,
    required SyncPeerStore peerStore,
    List<int>? portCandidates,
    InternetAddress? bindAddress,
  })  : _repository = repository,
        _activityRepository = activityRepository,
        _deviceIdStore = deviceIdStore,
        _timeEntryRepository = timeEntryRepository,
        _peerStore = peerStore,
        _portCandidates =
            portCandidates ?? List<int>.generate(11, (index) => 8787 + index),
        _bindAddress = bindAddress ?? InternetAddress.anyIPv4;

  final TimeRepository _repository;
  // ignore: unused_field
  final IActivityRepository _activityRepository;
  final IDeviceIdStore _deviceIdStore;
  // ignore: unused_field
  final ITimeEntryRepository _timeEntryRepository;
  final SyncPeerStore _peerStore;
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
        await _writeJson(request, {
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

      await _writeJson(
        request,
        {'error': 'Not found.'},
        statusCode: HttpStatus.notFound,
      );
    } catch (error) {
      await _writeJson(
        request,
        {'error': error.toString()},
        statusCode: HttpStatus.internalServerError,
      );
    }
  }

  Future<void> _handlePair(HttpRequest request) async {
    final clientIp =
        request.connectionInfo?.remoteAddress.address ?? 'unknown';

    // Rate limiting: clean old entries and check threshold
    _pairAttempts[clientIp]
        ?.removeWhere((t) => DateTime.now().difference(t) > _pairAttemptWindow);
    final attempts = _pairAttempts.putIfAbsent(clientIp, () => []);
    if (attempts.length >= _maxPairAttempts) {
      await _writeJson(
        request,
        {'error': '尝试次数过多，请稍后再试。'},
        statusCode: 429,
      );
      return;
    }
    attempts.add(DateTime.now());

    // Pairing code TTL check
    final generatedAt = _pairingCodeGeneratedAt;
    if (generatedAt != null &&
        DateTime.now().difference(generatedAt) > _pairingCodeTtl) {
      await _writeJson(
        request,
        {'error': '配对码已过期，请重启局域网同步服务。'},
        statusCode: HttpStatus.unauthorized,
      );
      return;
    }

    final body = await _readJson(request);
    final code = body['code'] as String?;
    if (code?.trim() != _pairingCode) {
      await _writeJson(
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

    await _writeJson(request, {
      'token': token,
      'server_device_id': await _deviceIdStore.currentDeviceId(),
      'server_name': Platform.localHostname,
    });
  }

  Future<void> _handleSync(HttpRequest request) async {
    final token = _bearerToken(request);
    if (token == null || !await _peerStore.isAuthorizedLanToken(token)) {
      await _writeJson(
        request,
        {'error': '未授权的局域网同步请求。'},
        statusCode: HttpStatus.unauthorized,
      );
      return;
    }

    final body = await _readJson(request);
    final bundle = _codec.fromJson(_requiredMap(body['bundle'], 'bundle'));
    await _repository.mergeBundle(bundle);
    await _writeJson(request, {
      'bundle': (await _repository.exportBundle()).toJson(),
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

class LanSyncClient {
  LanSyncClient({
    required TimeRepository repository,
    required IActivityRepository activityRepository,
    required IDeviceIdStore deviceIdStore,
    required ITimeEntryRepository timeEntryRepository,
    required SyncPeerStore peerStore,
    Duration timeout = const Duration(seconds: 8),
  })  : _repository = repository,
        _activityRepository = activityRepository,
        _deviceIdStore = deviceIdStore,
        _timeEntryRepository = timeEntryRepository,
        _peerStore = peerStore,
        _timeout = timeout;

  final TimeRepository _repository;
  // ignore: unused_field
  final IActivityRepository _activityRepository;
  final IDeviceIdStore _deviceIdStore;
  // ignore: unused_field
  final ITimeEntryRepository _timeEntryRepository;
  final SyncPeerStore _peerStore;
  final Duration _timeout;
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
      {'bundle': (await _repository.exportBundle()).toJson()},
      token: peer.token,
    );
    final bundle = _codec.fromJson(_requiredMap(response['bundle'], 'bundle'));
    await _repository.mergeBundle(bundle);
  }

  Future<void> clearPeer() {
    return _peerStore.clearLanClientPeer();
  }

  Future<Map<String, Object?>> _postJson(
    Uri uri,
    Map<String, Object?> body, {
    String? token,
  }) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.postUrl(uri).timeout(_timeout);
      request.headers.contentType = ContentType.json;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      request.write(jsonEncode(body));

      final response = await request.close().timeout(_timeout);
      final responseBody = await utf8.decoder.bind(response).join();
      final decoded =
          responseBody.isEmpty ? <String, Object?>{} : jsonDecode(responseBody);
      final responseMap = _requiredMap(decoded, 'response');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LanSyncException(
          (responseMap['error'] as String?) ?? '局域网同步请求失败。',
        );
      }
      return responseMap;
    } on LanSyncException {
      rethrow;
    } on SocketException {
      throw const LanSyncException(
        '无法连接局域网主机，请确认两台设备在同一 Wi-Fi，并允许 Windows 防火墙访问专用网络。',
      );
    } on TimeoutException {
      throw const LanSyncException('局域网同步请求超时，请检查主机地址和网络连接。');
    } on FormatException catch (error) {
      throw LanSyncException('局域网同步响应格式不正确：$error');
    } finally {
      client.close(force: true);
    }
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
    return uri
        .replace(path: '', query: null, fragment: null)
        .toString()
        .replaceFirst(RegExp(r'/$'), '');
  }
}

Future<Map<String, Object?>> _readJson(HttpRequest request) async {
  final body = await utf8.decoder.bind(request).join();
  if (body.trim().isEmpty) {
    return <String, Object?>{};
  }
  final decoded = jsonDecode(body);
  return _requiredMap(decoded, 'request');
}

Future<void> _writeJson(
  HttpRequest request,
  Map<String, Object?> body, {
  int statusCode = HttpStatus.ok,
}) async {
  request.response.statusCode = statusCode;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

Map<String, Object?> _requiredMap(Object? value, String label) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  throw FormatException('Missing or invalid object field: $label.');
}
