part of 'app_state.dart';

mixin AppStateRuntimeFacade on ChangeNotifier {
  ActivityState get _activityState;
  EntryState get _entryState;
  LanState get _lanState;
  AppLifecycleState get _lifecycleState;
  AppRefreshState get _refreshState;
  AppRuntimeState get _runtimeState;

  bool get isLoading => _runtimeState.isLoading;

  set isLoading(bool value) {
    _runtimeState.isLoading = value;
  }

  String? get errorMessage => _runtimeState.errorMessage;

  set errorMessage(String? value) {
    _runtimeState.errorMessage = value;
  }

  Future<void> initialize() => _lifecycleState.initialize();

  Future<void> refresh() => _refreshState.refresh();

  Future<void> selectDay(DateTime day) => _refreshState.selectDay(day);

  Future<void> _refreshDailyData() => _refreshState.refreshDailyData();

  void _bindSubStateListeners() {
    _activityState.addListener(_onSubStateChanged);
    _entryState.addListener(_onSubStateChanged);
  }

  void _onSubStateChanged() => _notifyStateListeners();

  void _notifyStateListeners() => notifyListeners();

  @override
  void dispose() {
    _lifecycleState.dispose();
    _refreshState.dispose();
    _activityState.removeListener(_onSubStateChanged);
    _entryState.removeListener(_onSubStateChanged);
    _activityState.dispose();
    _entryState.dispose();
    unawaited(_lanState.stopServerForDispose());
    super.dispose();
  }
}
