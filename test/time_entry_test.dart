import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/domain/time_entry.dart';

void main() {
  TimeEntry entry({
    DateTime? startAt,
    DateTime? endAt,
  }) {
    final start = startAt ?? DateTime(2026, 1, 1, 9);
    return TimeEntry(
      id: '1',
      userId: null,
      activityId: 'work',
      startAt: start,
      endAt: endAt,
      note: '',
      deviceId: 'test',
      updatedAt: start,
      isDeleted: false,
    );
  }

  test('durationUntil uses current time for running entries', () {
    final running = entry();

    expect(
      running.durationUntil(DateTime(2026, 1, 1, 10)),
      const Duration(hours: 1),
    );
  });

  test('durationInWindow clips completed entries to arbitrary windows', () {
    final completed = entry(
      startAt: DateTime(2026, 1, 1, 22),
      endAt: DateTime(2026, 1, 2, 2),
    );

    expect(
      completed.durationInWindow(
        windowStart: DateTime(2026, 1, 1, 23),
        windowEnd: DateTime(2026, 1, 2),
        now: DateTime(2026, 1, 2, 12),
      ),
      const Duration(hours: 1),
    );
  });

  test('durationInWindow uses current time for running entries', () {
    final running = entry(
      startAt: DateTime(2026, 1, 1, 22),
    );

    expect(
      running.durationInWindow(
        windowStart: DateTime(2026, 1, 2),
        windowEnd: DateTime(2026, 1, 2, 1),
        now: DateTime(2026, 1, 2, 0, 30),
      ),
      const Duration(minutes: 30),
    );
  });

  test('durationInWindow returns zero for non-overlapping windows', () {
    final completed = entry(
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 10),
    );

    expect(
      completed.durationInWindow(
        windowStart: DateTime(2026, 1, 1, 10),
        windowEnd: DateTime(2026, 1, 1, 11),
        now: DateTime(2026, 1, 1, 12),
      ),
      Duration.zero,
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
