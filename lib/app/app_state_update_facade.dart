part of 'app_state.dart';

mixin AppStateUpdateFacade on ChangeNotifier {
  UpdateState get _updateState;

  AppUpdateStatus get updateStatus => _updateState.status;

  set updateStatus(AppUpdateStatus value) {
    _updateState.status = value;
  }

  AppUpdateInfo? get availableUpdate => _updateState.availableUpdate;

  set availableUpdate(AppUpdateInfo? value) {
    _updateState.availableUpdate = value;
  }

  String get currentAppVersion => _updateState.currentAppVersion;

  set currentAppVersion(String value) {
    _updateState.currentAppVersion = value;
  }

  String? get updateErrorMessage => _updateState.errorMessage;

  set updateErrorMessage(String? value) {
    _updateState.errorMessage = value;
  }

  bool get shouldShowUpdatePrompt => _updateState.shouldShowPrompt;

  void markUpdatePromptShown() {
    _updateState.markPromptShownAndNotify(notifyListeners);
  }

  Future<void> checkForUpdates({bool silent = false}) {
    return _updateState.checkForUpdates(
      silent: silent,
      notifyListeners: notifyListeners,
    );
  }

  Future<void> openUpdateDownload() {
    return _updateState.openDownloadAndNotify(notifyListeners);
  }

  void _startStartupUpdateCheck() {
    _updateState.startStartupCheck(notifyListeners: notifyListeners);
  }
}
