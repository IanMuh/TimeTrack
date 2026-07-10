import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/lan_state.dart';
import 'package:timetrack/data/lan_sync.dart';
import 'package:timetrack/data/sync_peer_store.dart';

import 'test_fixtures.dart';

void main() {
  test('startServer records unsupported host message without starting',
      () async {
    final fixture = await buildTestRepositoryFixture();
    addTearDown(fixture.close);
    final server = _FakeLanSyncServer(fixture);
    final state = LanState(
      server: server,
      client: _FakeLanSyncClient(fixture),
      canHost: () => false,
    );

    await state.startServer();

    expect(server.startCount, 0);
    expect(state.message, '请在 Windows 端开启局域网主机，Android 作为客户端连接。');
  });

  test('startServer and stopServer update host state messages', () async {
    final fixture = await buildTestRepositoryFixture();
    addTearDown(fixture.close);
    final server = _FakeLanSyncServer(fixture);
    final state = LanState(
      server: server,
      client: _FakeLanSyncClient(fixture),
      canHost: () => true,
    );

    await state.startServer();

    expect(server.startCount, 1);
    expect(state.isServerRunning, isTrue);
    expect(state.pairingCode, '123456');
    expect(state.serverUrls, ['http://127.0.0.1:8787']);
    expect(state.serverPort, 8787);
    expect(state.message, '局域网主机已开启。');

    await state.stopServer();

    expect(server.stopCount, 1);
    expect(state.isServerRunning, isFalse);
    expect(state.message, '局域网主机已关闭。');
  });

  test('pairPeer stores peer and clearPeer removes it', () async {
    final fixture = await buildTestRepositoryFixture();
    addTearDown(fixture.close);
    final client = _FakeLanSyncClient(fixture);
    final state = LanState(
      server: _FakeLanSyncServer(fixture),
      client: client,
      canHost: () => true,
    );

    expect(
        await state.pairPeer(baseUrl: 'http://host', code: '123456'), isTrue);

    expect(state.hasPeer, isTrue);
    expect(state.peer?.id, 'host');
    expect(state.message, '局域网主机配对成功。');

    await state.clearPeer();

    expect(client.clearCount, 1);
    expect(state.hasPeer, isFalse);
    expect(state.message, '已移除局域网主机配对。');
  });

  test('pairPeer records failure and does not replace existing peer', () async {
    final fixture = await buildTestRepositoryFixture();
    addTearDown(fixture.close);
    final existing = _peer(id: 'existing');
    final state = LanState(
      server: _FakeLanSyncServer(fixture),
      client: _FakeLanSyncClient(
        fixture,
        pairError: const LanSyncException('bad code'),
      ),
      canHost: () => true,
    )..peer = existing;

    expect(await state.pairPeer(baseUrl: 'http://host', code: 'bad'), isFalse);

    expect(state.peer, same(existing));
    expect(state.message, '局域网配对失败：bad code');
  });
}

SyncPeer _peer({String id = 'host'}) {
  return SyncPeer(
    id: id,
    kind: SyncPeerKind.lanClient,
    displayName: 'Host',
    baseUrl: 'http://127.0.0.1:8787',
    token: 'token',
    updatedAt: DateTime(2026, 1, 1),
  );
}

class _FakeLanSyncServer extends LanSyncServer {
  _FakeLanSyncServer(TestRepositoryFixture fixture)
      : super(
          bundleStore: fixture.syncBundleRepository,
          deviceIdStore: fixture.deviceIdStore,
          peerStore: fixture.peerStore,
        );

  var startCount = 0;
  var stopCount = 0;
  var _running = false;

  @override
  bool get isRunning => _running;

  @override
  int? get port => _running ? 8787 : null;

  @override
  String? get pairingCode => _running ? '123456' : null;

  @override
  List<String> get localUrls =>
      _running ? const ['http://127.0.0.1:8787'] : const [];

  @override
  Future<void> start() async {
    startCount += 1;
    _running = true;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    _running = false;
  }
}

class _FakeLanSyncClient extends LanSyncClient {
  _FakeLanSyncClient(
    TestRepositoryFixture fixture, {
    SyncPeer? currentPeer,
    Object? pairError,
  })  : _currentPeer = currentPeer,
        _pairError = pairError,
        super(
          bundleStore: fixture.syncBundleRepository,
          deviceIdStore: fixture.deviceIdStore,
          peerStore: fixture.peerStore,
        );

  SyncPeer? _currentPeer;
  final Object? _pairError;
  var clearCount = 0;

  @override
  Future<SyncPeer?> currentPeer() async => _currentPeer;

  @override
  Future<SyncPeer> pair({
    required String baseUrl,
    required String code,
  }) async {
    final error = _pairError;
    if (error != null) {
      throw error;
    }
    _currentPeer = _peer();
    return _currentPeer!;
  }

  @override
  Future<void> clearPeer() async {
    clearCount += 1;
    _currentPeer = null;
  }

  @override
  Future<void> syncNow() async {}
}
