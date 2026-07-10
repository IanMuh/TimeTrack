part of 'app_state.dart';

mixin AppStateLanFacade on ChangeNotifier {
  LanCoordinatorState get _lanCoordinatorState;
  LanState get _lanState;

  SyncPeer? get lanPeer => _lanState.peer;

  set lanPeer(SyncPeer? value) {
    _lanState.peer = value;
  }

  bool get canHostLan => _lanState.canHost;

  bool get isLanServerRunning => _lanState.isServerRunning;

  String? get lanPairingCode => _lanState.pairingCode;

  List<String> get lanServerUrls => _lanState.serverUrls;

  @visibleForTesting
  int? get lanSyncPortForTest => _lanState.serverPort;

  Future<void> startLanServer() => _lanCoordinatorState.startServer();

  Future<void> stopLanServer() => _lanCoordinatorState.stopServer();

  Future<void> pairLanPeer({
    required String baseUrl,
    required String code,
  }) {
    return _lanCoordinatorState.pairPeer(baseUrl: baseUrl, code: code);
  }

  Future<void> clearLanPeer() => _lanCoordinatorState.clearPeer();
}
