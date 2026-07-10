import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/time_stats.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/time_entry.dart';

void main() {
  test('time stats implementation stays split behind stable entrypoint', () {
    final barrel = File('lib/app/time_stats.dart');
    final calculator = File('lib/app/time_stats_calculator.dart');
    final rangeStats = File('lib/app/time_range_stats.dart');
    final models = File('lib/app/time_stats_models.dart');

    expect(calculator.existsSync(), isTrue);
    expect(rangeStats.existsSync(), isTrue);
    expect(models.existsSync(), isTrue);

    final barrelSource = barrel.readAsStringSync();
    expect(barrelSource, contains("part 'time_stats_calculator.dart';"));
    expect(barrelSource, contains("part 'time_range_stats.dart';"));
    expect(barrelSource, contains("part 'time_stats_models.dart';"));
    expect(barrelSource, isNot(contains('class TimeStatsCalculator')));
    expect(barrelSource, isNot(contains('class TimeRangeStats')));

    for (final file in [barrel, calculator, rangeStats, models]) {
      expect(_pureLineCount(file), lessThanOrEqualTo(250));
    }
  });

  test('entriesWithUnassignedGaps fills only uncovered time', () {
    final now = DateTime(2026, 1, 2, 12);
    final unassigned = _activity(
      id: 'unassigned',
      name: '未安排',
      isUnassigned: true,
    );
    final focus = _entry(
      id: 'focus',
      activityId: 'focus',
      startAt: DateTime(2026, 1, 2, 9),
      endAt: DateTime(2026, 1, 2, 10),
    );

    final entries = TimeStatsCalculator.entriesWithUnassignedGaps(
      entries: [focus],
      unassignedActivity: unassigned,
      windowStart: DateTime(2026, 1, 2, 8),
      windowEnd: DateTime(2026, 1, 2, 12),
      effectiveNow: now,
    );

    expect(entries.map((entry) => entry.activityId), [
      unassigned.id,
      'focus',
      unassigned.id,
    ]);
    expect(entries.first.startAt, DateTime(2026, 1, 2, 8));
    expect(entries.first.endAt, DateTime(2026, 1, 2, 9));
    expect(entries.last.startAt, DateTime(2026, 1, 2, 10));
    expect(entries.last.endAt, DateTime(2026, 1, 2, 12));
    expect(entries.last.deviceId, 'unassigned-gap');
    expect(entries.last.updatedAt, now);
  });

  test('visibleStoredEntries excludes deleted and unassigned rows', () {
    final unassigned = _activity(
      id: 'unassigned',
      name: '未安排',
      isUnassigned: true,
    );

    final entries = TimeStatsCalculator.visibleStoredEntries(
      entries: [
        _entry(id: 'work', activityId: 'work'),
        _entry(id: 'deleted', activityId: 'work', isDeleted: true),
        _entry(id: 'gap', activityId: unassigned.id),
      ],
      unassignedActivity: unassigned,
    );

    expect(entries.map((entry) => entry.id), ['work']);
  });

  test('totals and longest clip entries to the requested window', () {
    final entries = [
      _entry(
        id: 'early',
        activityId: 'work',
        startAt: DateTime(2026, 1, 1, 23),
        endAt: DateTime(2026, 1, 2, 1),
      ),
      _entry(
        id: 'later',
        activityId: 'work',
        startAt: DateTime(2026, 1, 2, 9),
        endAt: DateTime(2026, 1, 2, 10, 30),
      ),
    ];
    final start = DateTime(2026, 1, 2);
    final end = DateTime(2026, 1, 3);
    final now = DateTime(2026, 1, 2, 12);

    final totals = TimeStatsCalculator.totalsInWindow(
      entries: entries,
      windowStart: start,
      windowEnd: end,
      effectiveNow: now,
    );
    final longest = TimeStatsCalculator.longestInWindow(
      entries: entries,
      windowStart: start,
      windowEnd: end,
      effectiveNow: now,
    );

    expect(totals['work'], const Duration(hours: 2, minutes: 30));
    expect(longest, const Duration(hours: 1, minutes: 30));
  });
}

Activity _activity({
  required String id,
  required String name,
  bool isUnassigned = false,
}) {
  return Activity(
    id: id,
    userId: null,
    name: name,
    color: 0xff2563eb,
    isFavorite: true,
    updatedAt: DateTime(2026, 1, 1),
    isDeleted: false,
    isUnassigned: isUnassigned,
  );
}

int _pureLineCount(File file) {
  return file.readAsLinesSync().where((line) {
    final trimmed = line.trim();
    return trimmed.isNotEmpty &&
        !trimmed.startsWith('//') &&
        !trimmed.startsWith('#') &&
        !trimmed.startsWith('--');
  }).length;
}

TimeEntry _entry({
  required String id,
  required String activityId,
  DateTime? startAt,
  DateTime? endAt,
  bool isDeleted = false,
}) {
  final start = startAt ?? DateTime(2026, 1, 2, 9);
  return TimeEntry(
    id: id,
    userId: null,
    activityId: activityId,
    startAt: start,
    endAt: endAt ?? DateTime(2026, 1, 2, 10),
    note: '',
    deviceId: 'test-device',
    updatedAt: start,
    isDeleted: isDeleted,
  );
}
