import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:timetrack/core/result.dart';
import 'package:timetrack/data/sync_service.dart';

void main() {
  group('unwrapSyncRepositoryResult', () {
    test('returns successful values', () {
      final value = unwrapSyncRepositoryResult(
        operation: 'replaceActivityIfRemoteNewer',
        result: const AppSuccess(7),
      );

      expect(value, 7);
    });

    test('converts failures to typed sync exceptions', () {
      expect(
        () => unwrapSyncRepositoryResult<int>(
          operation: 'replaceActivityIfRemoteNewer',
          result: const AppFailure<int>('activity boom'),
        ),
        throwsA(
          isA<SyncException>()
              .having(
                (error) => error.message,
                'message',
                'replaceActivityIfRemoteNewer failed: activity boom',
              )
              .having(
                (error) => error.failure.operation,
                'failure.operation',
                'replaceActivityIfRemoteNewer',
              )
              .having(
                (error) => error.failure.message,
                'failure.message',
                'activity boom',
              ),
        ),
      );
    });

    test('upload repository reads do not swallow failures as empty lists', () {
      final source = File('lib/data/sync_service.dart').readAsStringSync();

      expect(source, isNot(contains('onFailure: (_) => <Activity>[]')));
      expect(source, isNot(contains('onFailure: (_) => <ActivityCategory>[]')));
      expect(
        source,
        isNot(contains('onFailure: (_) => <ActivityCategoryLink>[]')),
      );
      expect(source, isNot(contains('onFailure: (_) => <TimeEntry>[]')));
      expect(source, isNot(contains('onFailure: (_) => <ActionLog>[]')));
      expect(source, contains("operation: 'activitiesSince'"));
      expect(source, contains("operation: 'categoriesSince'"));
      expect(source, contains("operation: 'categoryLinksSince'"));
      expect(source, contains("operation: 'entriesSince'"));
      expect(source, contains("operation: 'actionLogsSince'"));
    });
  });

  group('fetchAllPaginated', () {
    test('fetches pages until the final short page', () async {
      final calls = <(int, int)>[];

      final rows = await fetchAllPaginated(
        pageSize: 2,
        fetchPage: (offset, limit) async {
          calls.add((offset, limit));
          return switch (offset) {
            0 => [
                {'id': 1},
                {'id': 2},
              ],
            2 => [
                {'id': 3},
              ],
            _ => <Map<String, dynamic>>[],
          };
        },
      );

      expect(rows.map((row) => row['id']), [1, 2, 3]);
      expect(calls, [(0, 2), (2, 2)]);
    });

    test('rejects non-positive page size', () async {
      await expectLater(
        fetchAllPaginated(
          pageSize: 0,
          fetchPage: (offset, limit) async => const [],
        ),
        throwsArgumentError,
      );
    });
  });

  group('batchProcess', () {
    test('processes items in bounded chunks', () async {
      final batches = <List<int>>[];

      await batchProcess(
        items: [
          {'id': 1},
          {'id': 2},
          {'id': 3},
          {'id': 4},
          {'id': 5},
        ],
        maxBatchSize: 2,
        processBatch: (batch) async {
          batches.add([for (final item in batch) item['id'] as int]);
        },
      );

      expect(batches, [
        [1, 2],
        [3, 4],
        [5],
      ]);
    });

    test('rejects non-positive batch size', () async {
      await expectLater(
        batchProcess(
          items: const [],
          maxBatchSize: 0,
          processBatch: (_) async {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('withRetry', () {
    test('retries transient failures and returns the successful value',
        () async {
      var attempts = 0;

      final value = await withRetry(
        maxRetries: 3,
        baseDelay: Duration.zero,
        operation: () async {
          attempts++;
          if (attempts < 3) {
            throw const SocketException('offline');
          }
          return 'synced';
        },
      );

      expect(value, 'synced');
      expect(attempts, 3);
    });

    test('does not retry non-transient failures', () async {
      var attempts = 0;

      await expectLater(
        withRetry<void>(
          maxRetries: 3,
          baseDelay: Duration.zero,
          operation: () async {
            attempts++;
            throw StateError('bad request');
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(attempts, 1);
    });
  });

  group('isTransientSyncError', () {
    test('recognizes network-shaped errors without runtimeType matching', () {
      expect(
        isTransientSyncError(const SocketException('offline')),
        isTrue,
      );
      expect(isTransientSyncError(TimeoutException('slow')), isTrue);
      expect(
        isTransientSyncError(http.ClientException('connection closed')),
        isTrue,
      );
      expect(isTransientSyncError(StateError('validation failed')), isFalse);
    });
  });
}
