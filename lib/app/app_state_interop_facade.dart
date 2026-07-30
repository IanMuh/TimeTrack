part of 'app_state.dart';

mixin AppStateInteropFacade on ChangeNotifier {
  InteropState get _interopState;
  InteropCoordinatorState get _interopCoordinatorState;

  String? get interopMessage => _interopState.message;

  set interopMessage(String? value) {
    _interopState.message = value;
  }

  Future<void> exportInteropFile({
    required String exportedPrefix,
    required String canceledMessage,
    required String failedPrefix,
  }) =>
      _interopCoordinatorState.exportFile(
        exportedPrefix: exportedPrefix,
        canceledMessage: canceledMessage,
        failedPrefix: failedPrefix,
      );

  Future<void> importInteropFile({
    required String importedPrefix,
    required String canceledMessage,
    required String failedPrefix,
  }) =>
      _interopCoordinatorState.importFile(
        importedPrefix: importedPrefix,
        canceledMessage: canceledMessage,
        failedPrefix: failedPrefix,
      );
}
