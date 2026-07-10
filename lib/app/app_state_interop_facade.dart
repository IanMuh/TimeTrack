part of 'app_state.dart';

mixin AppStateInteropFacade on ChangeNotifier {
  InteropState get _interopState;
  InteropCoordinatorState get _interopCoordinatorState;

  String? get interopMessage => _interopState.message;

  set interopMessage(String? value) {
    _interopState.message = value;
  }

  Future<void> exportInteropFile() => _interopCoordinatorState.exportFile();

  Future<void> importInteropFile() => _interopCoordinatorState.importFile();
}
