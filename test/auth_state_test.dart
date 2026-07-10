import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/auth_state.dart';

void main() {
  test('AppState auth facade stays separate from runtime facade', () {
    final authFacade = File('lib/app/app_state_auth_facade.dart');
    final runtimeFacade = File('lib/app/app_state_runtime_facade.dart');

    expect(authFacade.existsSync(), isTrue);

    final authSource = authFacade.readAsStringSync();
    final runtimeSource = runtimeFacade.readAsStringSync();

    expect(authSource, contains('mixin AppStateAuthFacade'));
    expect(authSource, contains('Future<void> sendMagicLink'));
    expect(authSource, contains('Future<void> verifyEmailOtp({'));
    expect(authSource, contains('Future<void> signOut()'));
    expect(runtimeSource, isNot(contains('Future<void> sendMagicLink')));
    expect(runtimeSource, isNot(contains('Future<void> verifyEmailOtp({')));
    expect(runtimeSource, isNot(contains('Future<void> signOut()')));
  });

  test('sendMagicLink forwards email without refreshing local state', () async {
    final harness = _AuthHarness();

    await harness.state.sendMagicLink('me@example.com');

    expect(harness.order, ['magic:me@example.com']);
  });

  test('verifyEmailOtp refreshes and syncs after successful verification',
      () async {
    final harness = _AuthHarness();

    await harness.state.verifyEmailOtp(
      email: 'me@example.com',
      token: '123456',
    );

    expect(harness.order, [
      'verify:me@example.com:123456',
      'refresh',
      'sync',
    ]);
  });

  test('signOut refreshes local state without running sync', () async {
    final harness = _AuthHarness();

    await harness.state.signOut();

    expect(harness.order, ['signOut', 'refresh']);
  });
}

class _AuthHarness {
  _AuthHarness() {
    state = AuthState.withHandlers(
      sendMagicLink: (email) async {
        order.add('magic:$email');
      },
      verifyEmailOtp: ({required email, required token}) async {
        order.add('verify:$email:$token');
      },
      signOut: () async {
        order.add('signOut');
      },
      refresh: () async {
        order.add('refresh');
      },
      sync: () async {
        order.add('sync');
      },
    );
  }

  final List<String> order = [];
  late final AuthState state;
}
