// ignore_for_file: unused_element

part of 'app_state.dart';

mixin AppStateModuleAccessors on ChangeNotifier {
  AppStateModules get _modules;

  TimeRepository get _repository => _modules.repository;
  ActivityState get _activityState => _modules.activityState;
  ActivityMutationState get _activityMutationState =>
      _modules.activityMutationState;
  AuthState get _authState => _modules.authState;
  CategoryState get _categoryState => _modules.categoryState;
  CategoryMutationState get _categoryMutationState =>
      _modules.categoryMutationState;
  EntryState get _entryState => _modules.entryState;
  EntryMutationState get _entryMutationState => _modules.entryMutationState;
  AppLifecycleState get _lifecycleState => _modules.lifecycleState;
  AppRefreshState get _refreshState => _modules.refreshState;
  AppRuntimeState get _runtimeState => _modules.runtimeState;
  InteropState get _interopState => _modules.interopState;
  InteropCoordinatorState get _interopCoordinatorState =>
      _modules.interopCoordinatorState;
  LanState get _lanState => _modules.lanState;
  LanCoordinatorState get _lanCoordinatorState => _modules.lanCoordinatorState;
  ReminderCoordinatorState get _reminderCoordinatorState =>
      _modules.reminderCoordinatorState;
  SettingsState get _settingsState => _modules.settingsState;
  SettingsCoordinatorState get _settingsCoordinatorState =>
      _modules.settingsCoordinatorState;
  SyncState get _syncState => _modules.syncState;
  SyncCoordinatorState get _syncCoordinatorState =>
      _modules.syncCoordinatorState;
  StatsState get _statsState => _modules.statsState;
  UndoCoordinatorState get _undoCoordinatorState =>
      _modules.undoCoordinatorState;
  UpdateState get _updateState => _modules.updateState;
}
