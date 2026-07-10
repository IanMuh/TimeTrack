part of 'time_stats.dart';

class TimeStatsCalculator {
  const TimeStatsCalculator._();

  static List<TimeEntry> visibleStoredEntries({
    required List<TimeEntry> entries,
    required Activity? unassignedActivity,
  }) {
    return [
      for (final entry in entries)
        if (!entry.isDeleted &&
            (unassignedActivity == null ||
                entry.activityId != unassignedActivity.id))
          entry,
    ];
  }

  static Map<String, Duration> totalsInWindow({
    required List<TimeEntry> entries,
    required DateTime windowStart,
    required DateTime windowEnd,
    required DateTime effectiveNow,
  }) {
    final totals = <String, Duration>{};
    for (final entry in entries) {
      final duration = entry.durationInWindow(
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: effectiveNow,
      );
      if (duration == Duration.zero) {
        continue;
      }
      totals[entry.activityId] =
          (totals[entry.activityId] ?? Duration.zero) + duration;
    }
    return totals;
  }

  static Duration longestInWindow({
    required List<TimeEntry> entries,
    required DateTime windowStart,
    required DateTime windowEnd,
    required DateTime effectiveNow,
  }) {
    var longest = Duration.zero;
    for (final entry in entries) {
      final duration = entry.durationInWindow(
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: effectiveNow,
      );
      if (duration > longest) {
        longest = duration;
      }
    }
    return longest;
  }

  static List<TimeEntry> entriesWithUnassignedGaps({
    required List<TimeEntry> entries,
    required Activity? unassignedActivity,
    required DateTime windowStart,
    required DateTime windowEnd,
    required DateTime effectiveNow,
  }) {
    final effectiveEnd = _earlier(windowEnd, effectiveNow);
    final visibleEntries = [
      for (final entry in entries)
        if (unassignedActivity == null ||
            entry.activityId != unassignedActivity.id)
          entry,
    ];
    if (unassignedActivity == null || !windowStart.isBefore(effectiveEnd)) {
      return visibleEntries;
    }

    final coverage = [
      for (final entry in visibleEntries)
        if (!entry.isDeleted &&
            entry.startAt.isBefore(effectiveEnd) &&
            (entry.endAt ?? effectiveNow).isAfter(windowStart))
          entry,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));

    final gaps = <TimeEntry>[];
    var cursor = windowStart;
    for (final entry in coverage) {
      final entryStart = _later(entry.startAt, windowStart);
      final entryEnd = _earlier(entry.endAt ?? effectiveNow, effectiveEnd);
      if (!entryEnd.isAfter(entryStart)) {
        continue;
      }
      if (cursor.isBefore(entryStart)) {
        gaps.add(_unassignedEntry(
          unassignedActivity,
          cursor,
          entryStart,
          effectiveNow,
        ));
      }
      if (cursor.isBefore(entryEnd)) {
        cursor = entryEnd;
      }
    }
    if (cursor.isBefore(effectiveEnd)) {
      gaps.add(_unassignedEntry(
        unassignedActivity,
        cursor,
        effectiveEnd,
        effectiveNow,
      ));
    }

    final combined = [...visibleEntries, ...gaps]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return combined;
  }

  static TimeEntry _unassignedEntry(
    Activity activity,
    DateTime start,
    DateTime end,
    DateTime effectiveNow,
  ) {
    final id = const Uuid().v5(
      Namespace.url.value,
      'timetrack:unassigned:${activity.id}:'
      '${start.toUtc().toIso8601String()}:'
      '${end.toUtc().toIso8601String()}',
    );
    return TimeEntry(
      id: id,
      userId: activity.userId,
      activityId: activity.id,
      activityNameSnapshot: activity.name,
      activityColorSnapshot: activity.color,
      startAt: start,
      endAt: end,
      note: '',
      deviceId: 'unassigned-gap',
      updatedAt: effectiveNow,
      isDeleted: false,
    );
  }
}
