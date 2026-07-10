import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/interop_coordinator_state.dart';

void main() {
  test('AppState interop facade stays separate from runtime facade', () {
    final interopFacade = File('lib/app/app_state_interop_facade.dart');
    final runtimeFacade = File('lib/app/app_state_runtime_facade.dart');
    final coreFacade = File('lib/app/app_state_core_facade.dart');

    expect(interopFacade.existsSync(), isTrue);

    final interopSource = interopFacade.readAsStringSync();
    final runtimeSource = runtimeFacade.readAsStringSync();
    final coreSource = coreFacade.readAsStringSync();

    expect(interopSource, contains('mixin AppStateInteropFacade'));
    expect(interopSource, contains('String? get interopMessage'));
    expect(interopSource, contains('set interopMessage(String? value)'));
    expect(interopSource, contains('Future<void> exportInteropFile()'));
    expect(interopSource, contains('Future<void> importInteropFile()'));
    expect(runtimeSource, isNot(contains('Future<void> exportInteropFile()')));
    expect(runtimeSource, isNot(contains('Future<void> importInteropFile()')));
    expect(coreSource, isNot(contains('String? get interopMessage')));
    expect(coreSource, isNot(contains('set interopMessage(String? value)')));
  });

  test('export notifies after exporting', () async {
    final harness = _InteropHarness();

    await harness.state.exportFile();

    expect(harness.order, ['export', 'notify']);
  });

  test('successful import refreshes before notifying', () async {
    final harness = _InteropHarness(importResult: true);

    await harness.state.importFile();

    expect(harness.order, ['import', 'refresh', 'notify']);
  });

  test('cancelled import only notifies', () async {
    final harness = _InteropHarness(importResult: false);

    await harness.state.importFile();

    expect(harness.order, ['import', 'notify']);
  });

  test('failed import publishes localized failure message', () async {
    final harness = _InteropHarness(importError: StateError('bad file'));

    await harness.state.importFile();

    expect(harness.order, [
      'import',
      'message:导入失败：Bad state: bad file',
      'notify',
    ]);
  });
}

class _InteropHarness {
  _InteropHarness({
    this.importResult = false,
    this.importError,
  }) {
    state = InteropCoordinatorState.withHandlers(
      exportFile: () async {
        order.add('export');
      },
      importFile: () async {
        order.add('import');
        final error = importError;
        if (error != null) {
          throw error;
        }
        return importResult;
      },
      setInteropMessage: (message) {
        order.add('message:$message');
      },
      notifyListeners: () {
        order.add('notify');
      },
      refresh: () async {
        order.add('refresh');
      },
    );
  }

  final bool importResult;
  final Object? importError;
  final List<String> order = [];
  late final InteropCoordinatorState state;
}
