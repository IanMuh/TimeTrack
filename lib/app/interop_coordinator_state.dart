import 'interop_state.dart';

typedef InteropAction = Future<void> Function();
typedef InteropImportAction = Future<bool> Function();
typedef InteropMessageSetter = void Function(String? message);
typedef InteropNotifier = void Function();
typedef InteropRefreshRunner = Future<void> Function();

class InteropCoordinatorState {
  InteropCoordinatorState({
    required InteropState interopState,
    required InteropMessageSetter setInteropMessage,
    required InteropNotifier notifyListeners,
    required InteropRefreshRunner refresh,
  }) : this.withHandlers(
          exportFile: interopState.exportFile,
          importFile: interopState.importFile,
          setInteropMessage: setInteropMessage,
          notifyListeners: notifyListeners,
          refresh: refresh,
        );

  const InteropCoordinatorState.withHandlers({
    required InteropAction exportFile,
    required InteropImportAction importFile,
    required InteropMessageSetter setInteropMessage,
    required InteropNotifier notifyListeners,
    required InteropRefreshRunner refresh,
  })  : _exportFile = exportFile,
        _importFile = importFile,
        _setInteropMessage = setInteropMessage,
        _notifyListeners = notifyListeners,
        _refresh = refresh;

  final InteropAction _exportFile;
  final InteropImportAction _importFile;
  final InteropMessageSetter _setInteropMessage;
  final InteropNotifier _notifyListeners;
  final InteropRefreshRunner _refresh;

  Future<void> exportFile() async {
    await _exportFile();
    _notifyListeners();
  }

  Future<void> importFile() async {
    try {
      if (await _importFile()) {
        await _refresh();
      }
    } catch (error) {
      _setInteropMessage('导入失败：$error');
    }
    _notifyListeners();
  }
}
