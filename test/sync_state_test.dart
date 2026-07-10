import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/sync_state.dart';
import 'package:timetrack/data/sync_status_store.dart';

void main() {
  test('run skips work when no sync target is available', () async {
    final cloud = _FakeCloudSync();
    final state = _buildState(cloud: cloud);
    var lanSyncCount = 0;
    var refreshCount = 0;

    final outcome = await state.run(
      isSignedIn: false,
      hasLanPeer: false,
      runLanSync: () async => lanSyncCount += 1,
      refresh: () async => refreshCount += 1,
    );

    expect(outcome.didRun, isFalse);
    expect(cloud.sinceValues, isEmpty);
    expect(lanSyncCount, 0);
    expect(refreshCount, 0);
    expect(state.status.lastSuccessfulSyncAt, isNull);
  });

  test('run uses the last cloud success as the incremental floor', () async {
    final cloud = _FakeCloudSync();
    final state = _buildState(cloud: cloud);
    final lastCloudSuccess = DateTime.utc(2026, 6, 24, 8, 30);
    state.status = await state.statusStore.markSuccess(
      at: lastCloudSuccess,
      target: SyncTarget.cloud,
    );

    final outcome = await state.run(
      isSignedIn: true,
      hasLanPeer: false,
      runLanSync: () async {},
      refresh: () async {},
    );

    expect(outcome.didRun, isTrue);
    expect(outcome.errorMessage, isNull);
    expect(cloud.sinceValues, [lastCloudSuccess]);
    expect(state.status.lastTarget, SyncTarget.cloud);
  });

  test('run records lan failure without advancing last success', () async {
    final state = _buildState();
    final previousSuccess = DateTime.utc(2026, 6, 24, 8, 30);
    state.status = await state.statusStore.markSuccess(
      at: previousSuccess,
      target: SyncTarget.lan,
    );

    final outcome = await state.run(
      isSignedIn: false,
      hasLanPeer: true,
      runLanSync: () async => throw StateError('host unavailable'),
      refresh: () async {},
    );

    expect(outcome.didRun, isTrue);
    expect(outcome.errorMessage, contains('同步部分失败'));
    expect(outcome.errorMessage, contains('局域网同步'));
    expect(state.status.lastSuccessfulSyncAt?.toUtc(), previousSuccess);
    expect(state.status.lastError, outcome.errorMessage);
    expect(state.status.lastTarget, SyncTarget.lan);
  });

  test('run records lan success and clears previous errors', () async {
    final now = DateTime.utc(2026, 6, 25, 9);
    final state = _buildState(now: () => now);
    state.status = await state.statusStore.markFailure(
      error: 'old failure',
      target: SyncTarget.lan,
    );

    final outcome = await state.run(
      isSignedIn: false,
      hasLanPeer: true,
      runLanSync: () async {},
      refresh: () async {},
    );

    expect(outcome.didRun, isTrue);
    expect(outcome.errorMessage, isNull);
    expect(state.status.lastSuccessfulSyncAt, now);
    expect(state.status.lastError, isNull);
    expect(state.status.lastTarget, SyncTarget.lan);
  });

  test('run syncs cloud then lan then cloud backfill for combined target',
      () async {
    final cloud = _FakeCloudSync();
    final state = _buildState(cloud: cloud);
    final lastCloudSuccess = DateTime.utc(2026, 6, 24, 8, 30);
    var lanSyncCount = 0;
    state.status = await state.statusStore.markSuccess(
      at: lastCloudSuccess,
      target: SyncTarget.cloud,
    );

    final outcome = await state.run(
      isSignedIn: true,
      hasLanPeer: true,
      runLanSync: () async => lanSyncCount += 1,
      refresh: () async {},
    );

    expect(outcome.didRun, isTrue);
    expect(outcome.errorMessage, isNull);
    expect(cloud.sinceValues, [lastCloudSuccess, null]);
    expect(lanSyncCount, 1);
    expect(state.status.lastTarget, SyncTarget.cloudLan);
  });

  test('run aggregates partial failures and still refreshes local state',
      () async {
    final cloud = _FakeCloudSync(error: StateError('cloud down'));
    final state = _buildState(cloud: cloud);
    var refreshCount = 0;

    final outcome = await state.run(
      isSignedIn: true,
      hasLanPeer: true,
      runLanSync: () async => throw StateError('lan down'),
      refresh: () async => refreshCount += 1,
    );

    expect(outcome.didRun, isTrue);
    expect(
      outcome.errorMessage,
      contains('云同步：Bad state: cloud down；局域网同步：Bad state: lan down'),
    );
    expect(refreshCount, 1);
    expect(state.status.lastSuccessfulSyncAt, isNull);
    expect(state.status.lastError, outcome.errorMessage);
    expect(state.status.lastTarget, SyncTarget.cloudLan);
  });
}

SyncState _buildState({
  _FakeCloudSync? cloud,
  DateTime Function()? now,
}) {
  return SyncState.withHandlers(
    cloudSync: (cloud ?? _FakeCloudSync()).call,
    statusStore: SyncStatusStore.memory(),
    now: now,
  );
}

class _FakeCloudSync {
  _FakeCloudSync({this.error});

  final Object? error;
  final sinceValues = <DateTime?>[];

  Future<void> call({DateTime? since}) async {
    sinceValues.add(since);
    final syncError = error;
    if (syncError != null) {
      throw syncError;
    }
  }
}
