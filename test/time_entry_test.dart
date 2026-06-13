import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/domain/time_entry.dart';

void main() {
  test('durationUntil uses current time for running entries', () {
    final entry = TimeEntry(
      id: '1',
      userId: null,
      activityId: 'work',
      startAt: DateTime(2026, 1, 1, 9),
      endAt: null,
      note: '',
      deviceId: 'test',
      updatedAt: DateTime(2026, 1, 1, 9),
      isDeleted: false,
    );

    expect(
      entry.durationUntil(DateTime(2026, 1, 1, 10)),
      const Duration(hours: 1),
    );
  });

  test('overlaps detects intersecting time windows', () {
    TimeEntry entry(String id, DateTime start, DateTime end) => TimeEntry(
          id: id,
          userId: null,
          activityId: 'work',
          startAt: start,
          endAt: end,
          note: '',
          deviceId: 'test',
          updatedAt: start,
          isDeleted: false,
        );

    final first = entry(
      '1',
      DateTime(2026, 1, 1, 9),
      DateTime(2026, 1, 1, 10),
    );
    final second = entry(
      '2',
      DateTime(2026, 1, 1, 9, 30),
      DateTime(2026, 1, 1, 10, 30),
    );
    final third = entry(
      '3',
      DateTime(2026, 1, 1, 10),
      DateTime(2026, 1, 1, 11),
    );

    expect(first.overlaps(second), isTrue);
    expect(first.overlaps(third), isFalse);
  });
}
