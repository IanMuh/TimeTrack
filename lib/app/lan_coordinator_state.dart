import 'lan_state.dart';

typedef LanAction = Future<void> Function();
typedef LanPairAction = Future<bool> Function({
  required String baseUrl,
  required String code,
});
typedef LanMessageReader = String? Function();
typedef LanMessageSetter = void Function(String? message);
typedef LanNotifier = void Function();
typedef LanSyncRunner = Future<void> Function();

class LanCoordinatorState {
  LanCoordinatorState({
    required LanState lanState,
    required LanMessageSetter setInteropMessage,
    required LanNotifier notifyListeners,
    required LanSyncRunner sync,
  }) : this.withHandlers(
          startServer: lanState.startServer,
          stopServer: lanState.stopServer,
          pairPeer: lanState.pairPeer,
          clearPeer: lanState.clearPeer,
          message: () => lanState.message,
          setInteropMessage: setInteropMessage,
          notifyListeners: notifyListeners,
          sync: sync,
        );

  const LanCoordinatorState.withHandlers({
    required LanAction startServer,
    required LanAction stopServer,
    required LanPairAction pairPeer,
    required LanAction clearPeer,
    required LanMessageReader message,
    required LanMessageSetter setInteropMessage,
    required LanNotifier notifyListeners,
    required LanSyncRunner sync,
  })  : _startServer = startServer,
        _stopServer = stopServer,
        _pairPeer = pairPeer,
        _clearPeer = clearPeer,
        _message = message,
        _setInteropMessage = setInteropMessage,
        _notifyListeners = notifyListeners,
        _sync = sync;

  final LanAction _startServer;
  final LanAction _stopServer;
  final LanPairAction _pairPeer;
  final LanAction _clearPeer;
  final LanMessageReader _message;
  final LanMessageSetter _setInteropMessage;
  final LanNotifier _notifyListeners;
  final LanSyncRunner _sync;

  Future<void> startServer() async {
    await _startServer();
    _publishMessage();
  }

  Future<void> stopServer() async {
    await _stopServer();
    _publishMessage();
  }

  Future<void> pairPeer({
    required String baseUrl,
    required String code,
  }) async {
    final paired = await _pairPeer(baseUrl: baseUrl, code: code);
    _publishMessage();
    if (paired) {
      await _sync();
    }
  }

  Future<void> clearPeer() async {
    await _clearPeer();
    _publishMessage();
  }

  void _publishMessage() {
    _setInteropMessage(_message());
    _notifyListeners();
  }
}
