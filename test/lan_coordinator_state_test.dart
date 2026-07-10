import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/lan_coordinator_state.dart';

void main() {
  test('AppState LAN facade stays separate from runtime facade', () {
    final lanFacade = File('lib/app/app_state_lan_facade.dart');
    final runtimeFacade = File('lib/app/app_state_runtime_facade.dart');
    final coreFacade = File('lib/app/app_state_core_facade.dart');

    expect(lanFacade.existsSync(), isTrue);

    final lanSource = lanFacade.readAsStringSync();
    final runtimeSource = runtimeFacade.readAsStringSync();
    final coreSource = coreFacade.readAsStringSync();

    expect(lanSource, contains('mixin AppStateLanFacade'));
    expect(lanSource, contains('SyncPeer? get lanPeer'));
    expect(lanSource, contains('set lanPeer(SyncPeer? value)'));
    expect(lanSource, contains('bool get canHostLan'));
    expect(lanSource, contains('bool get isLanServerRunning'));
    expect(lanSource, contains('String? get lanPairingCode'));
    expect(lanSource, contains('List<String> get lanServerUrls'));
    expect(lanSource, contains('int? get lanSyncPortForTest'));
    expect(lanSource, contains('Future<void> startLanServer()'));
    expect(lanSource, contains('Future<void> stopLanServer()'));
    expect(lanSource, contains('Future<void> pairLanPeer({'));
    expect(lanSource, contains('Future<void> clearLanPeer()'));
    expect(runtimeSource, isNot(contains('bool get canHostLan')));
    expect(runtimeSource, isNot(contains('bool get isLanServerRunning')));
    expect(runtimeSource, isNot(contains('String? get lanPairingCode')));
    expect(runtimeSource, isNot(contains('List<String> get lanServerUrls')));
    expect(runtimeSource, isNot(contains('int? get lanSyncPortForTest')));
    expect(runtimeSource, isNot(contains('Future<void> startLanServer()')));
    expect(runtimeSource, isNot(contains('Future<void> stopLanServer()')));
    expect(runtimeSource, isNot(contains('Future<void> pairLanPeer({')));
    expect(runtimeSource, isNot(contains('Future<void> clearLanPeer()')));
    expect(coreSource, isNot(contains('SyncPeer? get lanPeer')));
    expect(coreSource, isNot(contains('set lanPeer(SyncPeer? value)')));
  });

  test('start and stop publish LAN messages', () async {
    final harness = _LanHarness(message: 'server ready');

    await harness.state.startServer();
    harness.message = 'server stopped';
    await harness.state.stopServer();

    expect(harness.order, [
      'start',
      'message:server ready',
      'notify',
      'stop',
      'message:server stopped',
      'notify',
    ]);
  });

  test('successful pairing publishes message then syncs', () async {
    final harness = _LanHarness(pairResult: true, message: 'paired');

    await harness.state.pairPeer(
      baseUrl: 'http://127.0.0.1:4321',
      code: '123456',
    );

    expect(harness.order, [
      'pair:http://127.0.0.1:4321:123456',
      'message:paired',
      'notify',
      'sync',
    ]);
  });

  test('failed pairing publishes message without syncing', () async {
    final harness = _LanHarness(pairResult: false, message: 'bad code');

    await harness.state.pairPeer(
      baseUrl: 'http://127.0.0.1:4321',
      code: '000000',
    );

    expect(harness.order, [
      'pair:http://127.0.0.1:4321:000000',
      'message:bad code',
      'notify',
    ]);
  });

  test('clear peer publishes the resulting message', () async {
    final harness = _LanHarness(message: 'cleared');

    await harness.state.clearPeer();

    expect(harness.order, ['clear', 'message:cleared', 'notify']);
  });
}

class _LanHarness {
  _LanHarness({
    this.pairResult = false,
    this.message,
  }) {
    state = LanCoordinatorState.withHandlers(
      startServer: () async {
        order.add('start');
      },
      stopServer: () async {
        order.add('stop');
      },
      pairPeer: ({required baseUrl, required code}) async {
        order.add('pair:$baseUrl:$code');
        return pairResult;
      },
      clearPeer: () async {
        order.add('clear');
      },
      message: () => message,
      setInteropMessage: (value) {
        order.add('message:$value');
      },
      notifyListeners: () {
        order.add('notify');
      },
      sync: () async {
        order.add('sync');
      },
    );
  }

  final bool pairResult;
  String? message;
  final List<String> order = [];
  late final LanCoordinatorState state;
}
