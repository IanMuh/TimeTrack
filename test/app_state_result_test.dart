import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/activity_state.dart';
import 'package:timetrack/app/app_state_result.dart';
import 'package:timetrack/core/result.dart';
import 'package:timetrack/data/repository_interfaces.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/time_entry.dart';

void main() {
  test('unwrapAppStateResult preserves failure details', () {
    expect(
      () => unwrapAppStateResult<int>(const AppFailure('entry failed')),
      throwsA(
        isA<AppStateException>()
            .having((error) => error.failure.message, 'message', 'entry failed')
            .having((error) => error.message, 'state message', 'entry failed'),
      ),
    );
  });

  test('ActivityState command failures use typed app exceptions', () async {
    final state = ActivityState(
      activityCatalog: _EmptyActivityCatalog(),
      activityCommands: _UnusedActivityCommands(),
      entryQueries: _UnusedEntryQueries(),
      entryCommands: const _FailingEntryCommands('switch failed'),
      onFullRefresh: () async {},
      onEntryRefresh: () async {},
    );

    await expectLater(
      state.switchTo(_activity()),
      throwsA(
        isA<AppStateException>().having(
          (error) => error.failure.message,
          'message',
          'switch failed',
        ),
      ),
    );
  });
}

Activity _activity() {
  return Activity(
    id: 'activity',
    userId: null,
    name: 'Focus',
    color: 0xff2563eb,
    isFavorite: true,
    updatedAt: DateTime(2026, 1, 1),
    isDeleted: false,
  );
}

class _EmptyActivityCatalog implements IActivityCatalogRepository {
  @override
  Future<AppResult<List<Activity>>> activities({bool includeDeleted = false}) {
    return Future.value(const AppSuccess([]));
  }

  @override
  Future<AppResult<List<Activity>>> oneOffActivities({
    bool includeDeleted = true,
  }) {
    return Future.value(const AppSuccess([]));
  }

  @override
  Future<AppResult<Activity>> unassignedActivity() {
    return Future.value(AppSuccess(_activity()));
  }
}

class _UnusedActivityCommands implements IActivityCommandRepository {
  @override
  Future<AppResult<Activity>> createActivity({
    required String name,
    required int color,
    String? userId,
    bool isOneOff = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<void>> deleteActivity(Activity activity) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<Activity>> restoreOneOffActivity(Activity activity) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<Activity>> updateActivity({
    required Activity activity,
    required String name,
    required int color,
  }) {
    throw UnimplementedError();
  }
}

class _UnusedEntryQueries implements ITimeEntryQueryRepository {
  @override
  Future<AppResult<List<TimeEntry>>> allEntries() {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<List<TimeEntry>>> entriesForDay(DateTime day) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<List<TimeEntry>>> entriesForRange(
    DateTime start,
    DateTime end,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<EntryMergeCandidate?>> mergeCandidateForEntry(
    String entryId,
    EntryMergeDirection direction,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<List<TimeEntry>>> overlappingEntries(TimeEntry entry) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<TimeEntry?>> runningEntry() {
    return Future.value(const AppSuccess(null));
  }
}

class _FailingEntryCommands implements ITimeEntryCommandRepository {
  const _FailingEntryCommands(this.message);

  final String message;

  @override
  Future<AppResult<TimeEntry>> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
    String? userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<void>> deleteEntry(TimeEntry entry) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<TimeEntry?>> mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<List<TimeEntry>>> saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<List<TimeEntry>>> splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<void>> stopRunning({DateTime? at}) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<TimeEntry>> switchToActivity(
    String activityId, {
    DateTime? at,
  }) {
    return Future.value(AppFailure(message));
  }
}
