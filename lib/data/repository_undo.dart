import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/activity_category.dart';
import '../domain/time_entry.dart';

enum RepositoryUndoDirection { undo, redo }

class RepositoryUndoWindow {
  RepositoryUndoWindow({required DateTime start, required DateTime end})
      : start = start.isBefore(end) ? start : end,
        end = end.isAfter(start) ? end : start;

  factory RepositoryUndoWindow.forLocalDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return RepositoryUndoWindow(
      start: start,
      end: start.add(const Duration(days: 1)),
    );
  }

  factory RepositoryUndoWindow.covering(DateTime start, DateTime end) {
    final orderedStart = start.isBefore(end) ? start : end;
    final orderedEnd = end.isAfter(start) ? end : start;
    final dayStart = DateTime(
      orderedStart.year,
      orderedStart.month,
      orderedStart.day,
    );
    final endDayStart = DateTime(
      orderedEnd.year,
      orderedEnd.month,
      orderedEnd.day,
    );
    return RepositoryUndoWindow(
      start: dayStart,
      end: endDayStart.add(const Duration(days: 1)),
    );
  }

  final DateTime start;
  final DateTime end;

  bool get isEmpty => !start.isBefore(end);

  String get startValue => start.toUtc().toIso8601String();

  String get endValue => end.toUtc().toIso8601String();
}

class RepositoryUndoScope {
  const RepositoryUndoScope({
    this.entryWindows = const [],
    this.actionLogWindows = const [],
  });

  final List<RepositoryUndoWindow> entryWindows;
  final List<RepositoryUndoWindow> actionLogWindows;

  bool get hasEntryScope => entryWindows.any((window) => !window.isEmpty);

  bool get hasActionLogScope =>
      actionLogWindows.any((window) => !window.isEmpty);
}

class RepositoryUndoConflictException implements Exception {
  const RepositoryUndoConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RepositoryUndoSnapshot {
  const RepositoryUndoSnapshot({
    required this.activities,
    required this.categories,
    required this.categoryLinks,
    required this.timeEntries,
    required this.actionLogs,
  });

  final Map<String, Activity> activities;
  final Map<String, ActivityCategory> categories;
  final Map<String, ActivityCategoryLink> categoryLinks;
  final Map<String, TimeEntry> timeEntries;
  final Map<String, ActionLog> actionLogs;

  RepositoryUndoChangeSet diff({
    required String label,
    required RepositoryUndoSnapshot after,
  }) {
    return RepositoryUndoChangeSet(
      label: label,
      activities: _diffRows<Activity>(
        before: activities,
        after: after.activities,
        toMap: (value) => value.toLocalMap(),
      ),
      categories: _diffRows<ActivityCategory>(
        before: categories,
        after: after.categories,
        toMap: (value) => value.toLocalMap(),
      ),
      categoryLinks: _diffRows<ActivityCategoryLink>(
        before: categoryLinks,
        after: after.categoryLinks,
        toMap: (value) => value.toLocalMap(),
      ),
      timeEntries: _diffRows<TimeEntry>(
        before: timeEntries,
        after: after.timeEntries,
        toMap: (value) => value.toLocalMap(),
      ),
      actionLogs: _diffRows<ActionLog>(
        before: actionLogs,
        after: after.actionLogs,
        toMap: (value) => value.toLocalMap(),
      ),
    );
  }
}

class RepositoryUndoChangeSet {
  const RepositoryUndoChangeSet({
    required this.label,
    required this.activities,
    required this.categories,
    required this.categoryLinks,
    required this.timeEntries,
    required this.actionLogs,
  });

  final String label;
  final List<RepositoryUndoRowChange<Activity>> activities;
  final List<RepositoryUndoRowChange<ActivityCategory>> categories;
  final List<RepositoryUndoRowChange<ActivityCategoryLink>> categoryLinks;
  final List<RepositoryUndoRowChange<TimeEntry>> timeEntries;
  final List<RepositoryUndoRowChange<ActionLog>> actionLogs;

  bool get isEmpty =>
      activities.isEmpty &&
      categories.isEmpty &&
      categoryLinks.isEmpty &&
      timeEntries.isEmpty &&
      actionLogs.isEmpty;
}

class RepositoryUndoRowChange<T> {
  const RepositoryUndoRowChange({
    required this.id,
    required this.before,
    required this.after,
  });

  final String id;
  final T? before;
  final T? after;

  T? expectedFor(RepositoryUndoDirection direction) {
    return switch (direction) {
      RepositoryUndoDirection.undo => after,
      RepositoryUndoDirection.redo => before,
    };
  }

  T? targetFor(RepositoryUndoDirection direction) {
    return switch (direction) {
      RepositoryUndoDirection.undo => before,
      RepositoryUndoDirection.redo => after,
    };
  }

  T? fallbackFor(RepositoryUndoDirection direction) {
    return switch (direction) {
      RepositoryUndoDirection.undo => after,
      RepositoryUndoDirection.redo => before,
    };
  }
}

List<RepositoryUndoRowChange<T>> _diffRows<T>({
  required Map<String, T> before,
  required Map<String, T> after,
  required Map<String, Object?> Function(T value) toMap,
}) {
  final ids = {...before.keys, ...after.keys}.toList()..sort();
  final changes = <RepositoryUndoRowChange<T>>[];
  for (final id in ids) {
    final beforeValue = before[id];
    final afterValue = after[id];
    if (_mapsEqual(
        _toMapOrNull(beforeValue, toMap), _toMapOrNull(afterValue, toMap))) {
      continue;
    }
    changes.add(
      RepositoryUndoRowChange<T>(
        id: id,
        before: beforeValue,
        after: afterValue,
      ),
    );
  }
  return changes;
}

Map<String, Object?>? _toMapOrNull<T>(
  T? value,
  Map<String, Object?> Function(T value) toMap,
) {
  return value == null ? null : toMap(value);
}

bool _mapsEqual(Map<String, Object?>? first, Map<String, Object?>? second) {
  if (first == null || second == null) {
    return first == null && second == null;
  }
  if (first.length != second.length) {
    return false;
  }
  for (final entry in first.entries) {
    if (second[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
