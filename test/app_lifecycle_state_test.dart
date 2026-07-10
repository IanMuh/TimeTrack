import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/app_lifecycle_state.dart';

void main() {
  test('initialize runs startup tasks and starts the ticker', () async {
    final harness = _LifecycleHarness(shouldStartLanServer: true);

    await harness.state.initialize();

    expect(harness.order, [
      'loading:true',
      'notify',
      'seed',
      'refresh',
      'startLan',
      'startupUpdate',
      'ticker:start',
      'loading:false',
      'notify',
    ]);
    expect(harness.loading, isFalse);
    expect(harness.errorMessage, isNull);
  });

  test('ticker invokes the injected clock tick and dispose cancels it',
      () async {
    final tickTime = DateTime(2026, 1, 2, 12);
    final harness = _LifecycleHarness(clock: () => tickTime);

    await harness.state.initialize();
    harness.tick!();
    harness.state.dispose();

    expect(harness.order, contains('tick:2026-01-02 12:00:00.000'));
    expect(harness.order.last, 'ticker:cancel');
  });

  test('initialize skips LAN startup when predicate is false', () async {
    final harness = _LifecycleHarness(shouldStartLanServer: false);

    await harness.state.initialize();

    expect(harness.order, isNot(contains('startLan')));
    expect(harness.order, contains('ticker:start'));
  });

  test('initialize records formatted startup errors and stops loading',
      () async {
    final harness = _LifecycleHarness(
      seedError: StateError('DatabaseException: locked'),
    );

    await harness.state.initialize();

    expect(harness.loading, isFalse);
    expect(harness.errorMessage, contains('本地数据库启动失败'));
    expect(harness.order, [
      'loading:true',
      'notify',
      'seed',
      'error:本地数据库启动失败。请关闭其他 TimeTrack 窗口后重试；如果仍然失败，请先备份数据库文件后再排查。',
      'loading:false',
      'notify',
    ]);
  });
}

class _LifecycleHarness {
  _LifecycleHarness({
    bool shouldStartLanServer = false,
    Object? seedError,
    DateTime Function()? clock,
  }) : _seedError = seedError {
    state = AppLifecycleState.withHandlers(
      ensureSeedData: () async {
        order.add('seed');
        final error = _seedError;
        if (error != null) {
          throw error;
        }
      },
      refresh: () async {
        order.add('refresh');
      },
      shouldStartLanServer: () => shouldStartLanServer,
      startLanServer: () async {
        order.add('startLan');
      },
      startStartupUpdateCheck: () {
        order.add('startupUpdate');
      },
      tickClock: (currentTime) {
        order.add('tick:$currentTime');
      },
      setLoading: (value) {
        loading = value;
        order.add('loading:$value');
      },
      setErrorMessage: (message) {
        errorMessage = message;
        order.add('error:$message');
      },
      notifyListeners: () {
        order.add('notify');
      },
      startTicker: (onTick) {
        tick = onTick;
        order.add('ticker:start');
        return 'ticker';
      },
      cancelTicker: (ticker) {
        order.add('ticker:cancel');
      },
      clock: clock,
    );
  }

  final Object? _seedError;
  final List<String> order = [];
  late final AppLifecycleState state;
  void Function()? tick;
  bool loading = true;
  String? errorMessage;
}
