import 'dart:async';

typedef LifecycleAction = Future<void> Function();
typedef LifecyclePredicate = bool Function();
typedef LifecycleNotifier = void Function();
typedef LifecycleLoadingSetter = void Function(bool value);
typedef LifecycleErrorSetter = void Function(String message);
typedef LifecycleClock = DateTime Function();
typedef LifecycleTickHandler = void Function(DateTime currentTime);
typedef LifecycleTickerStarter = Object Function(void Function() onTick);
typedef LifecycleTickerCanceller = void Function(Object ticker);
typedef LifecycleStartupErrorFormatter = String Function(Object error);

class AppLifecycleState {
  AppLifecycleState({
    required LifecycleAction ensureSeedData,
    required LifecycleAction refresh,
    required LifecyclePredicate shouldStartLanServer,
    required LifecycleAction startLanServer,
    required LifecycleNotifier startStartupUpdateCheck,
    required LifecycleTickHandler tickClock,
    required LifecycleLoadingSetter setLoading,
    required LifecycleErrorSetter setErrorMessage,
    required LifecycleNotifier notifyListeners,
    LifecycleClock? clock,
  }) : this.withHandlers(
          ensureSeedData: ensureSeedData,
          refresh: refresh,
          shouldStartLanServer: shouldStartLanServer,
          startLanServer: startLanServer,
          startStartupUpdateCheck: startStartupUpdateCheck,
          tickClock: tickClock,
          setLoading: setLoading,
          setErrorMessage: setErrorMessage,
          notifyListeners: notifyListeners,
          clock: clock,
          startTicker: _startPeriodicTicker,
          cancelTicker: _cancelPeriodicTicker,
          formatStartupError: _defaultStartupError,
        );

  AppLifecycleState.withHandlers({
    required LifecycleAction ensureSeedData,
    required LifecycleAction refresh,
    required LifecyclePredicate shouldStartLanServer,
    required LifecycleAction startLanServer,
    required LifecycleNotifier startStartupUpdateCheck,
    required LifecycleTickHandler tickClock,
    required LifecycleLoadingSetter setLoading,
    required LifecycleErrorSetter setErrorMessage,
    required LifecycleNotifier notifyListeners,
    required LifecycleTickerStarter startTicker,
    required LifecycleTickerCanceller cancelTicker,
    LifecycleClock? clock,
    LifecycleStartupErrorFormatter? formatStartupError,
  })  : _ensureSeedData = ensureSeedData,
        _refresh = refresh,
        _shouldStartLanServer = shouldStartLanServer,
        _startLanServer = startLanServer,
        _startStartupUpdateCheck = startStartupUpdateCheck,
        _tickClock = tickClock,
        _setLoading = setLoading,
        _setErrorMessage = setErrorMessage,
        _notifyListeners = notifyListeners,
        _startTicker = startTicker,
        _cancelTicker = cancelTicker,
        _clock = clock ?? DateTime.now,
        _startupErrorFormatter = formatStartupError ?? _defaultStartupError;

  final LifecycleAction _ensureSeedData;
  final LifecycleAction _refresh;
  final LifecyclePredicate _shouldStartLanServer;
  final LifecycleAction _startLanServer;
  final LifecycleNotifier _startStartupUpdateCheck;
  final LifecycleTickHandler _tickClock;
  final LifecycleLoadingSetter _setLoading;
  final LifecycleErrorSetter _setErrorMessage;
  final LifecycleNotifier _notifyListeners;
  final LifecycleTickerStarter _startTicker;
  final LifecycleTickerCanceller _cancelTicker;
  final LifecycleClock _clock;
  final LifecycleStartupErrorFormatter _startupErrorFormatter;

  Object? _ticker;

  Future<void> initialize() async {
    _setLoading(true);
    _notifyListeners();
    try {
      await _ensureSeedData();
      await _refresh();
      if (_shouldStartLanServer()) {
        await _startLanServer();
      }
      _startStartupUpdateCheck();
      _restartTicker();
    } catch (error) {
      _setErrorMessage(_startupErrorFormatter(error));
    } finally {
      _setLoading(false);
      _notifyListeners();
    }
  }

  void dispose() {
    final ticker = _ticker;
    if (ticker == null) {
      return;
    }
    _ticker = null;
    _cancelTicker(ticker);
  }

  void _restartTicker() {
    dispose();
    _ticker = _startTicker(() {
      _tickClock(_clock());
    });
  }

  static Object _startPeriodicTicker(void Function() onTick) {
    return Timer.periodic(const Duration(seconds: 1), (_) {
      onTick();
    });
  }

  static void _cancelPeriodicTicker(Object ticker) {
    if (ticker is Timer) {
      ticker.cancel();
    }
  }

  static String _defaultStartupError(Object error) {
    final message = error.toString();
    if (message.toLowerCase().contains('databaseexception')) {
      return '本地数据库启动失败。请关闭其他 TimeTrack 窗口后重试；如果仍然失败，请先备份数据库文件后再排查。';
    }
    return message;
  }
}
