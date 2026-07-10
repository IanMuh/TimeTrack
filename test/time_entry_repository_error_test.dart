import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/core/result.dart';
import 'package:timetrack/data/time_entry_repository_errors.dart';
import 'test_fixtures.dart';

void main() {
  test('time entry repository validation exception is typed and compatible',
      () {
    final error = TimeEntryRepositoryException(
      TimeEntryRepositoryFailureCode.entryNotSplitable,
    );

    expect(error, isA<StateError>());
    expect(error.message, 'entry_not_splitable');
    expect(error.failureCode, TimeEntryRepositoryFailureCode.entryNotSplitable);
    expect(error.failureCode.code, 'entry_not_splitable');
  });

  test('splitEntry preserves the validation code in AppResult failures',
      () async {
    final fixture = await buildTestRepositoryFixture(seedData: false);
    addTearDown(fixture.close);

    final result = await fixture.timeEntryRepository.splitEntry(
      entryId: 'missing-entry',
      splitAt: DateTime.utc(2026, 1, 1, 12),
    );

    expect(result, isA<AppFailure<List<Object?>>>());
    expect(
      (result as AppFailure).message,
      contains(TimeEntryRepositoryFailureCode.entryNotSplitable.code),
    );
  });
}
