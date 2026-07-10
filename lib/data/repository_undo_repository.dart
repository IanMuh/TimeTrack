import 'package:sqflite/sqflite.dart';

import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/activity_category.dart';
import '../domain/time_entry.dart';
import 'action_log_repository.dart';
import 'activity_category_repository.dart';
import 'activity_repository.dart';
import 'local_database.dart';
import 'repository_result.dart';
import 'repository_undo.dart';
import 'time_entry_repository.dart';

class RepositoryUndoRepository {
  const RepositoryUndoRepository({
    required LocalDatabase database,
    required ActivityRepository activityRepository,
    required ActivityCategoryRepository activityCategoryRepository,
    required TimeEntryRepository timeEntryRepository,
    required ActionLogRepository actionLogRepository,
  })  : _database = database,
        _activityRepo = activityRepository,
        _categoryRepo = activityCategoryRepository,
        _entryRepo = timeEntryRepository,
        _logRepo = actionLogRepository;

  final LocalDatabase _database;
  final ActivityRepository _activityRepo;
  final ActivityCategoryRepository _categoryRepo;
  final TimeEntryRepository _entryRepo;
  final ActionLogRepository _logRepo;

  Future<RepositoryUndoSnapshot> undoSnapshot({
    RepositoryUndoScope? scope,
  }) async {
    final activityRows = unwrapRepositoryResult(
      await _activityRepo.activities(includeDeleted: true),
    );
    final categoryRows = unwrapRepositoryResult(
      await _categoryRepo.categories(includeDeleted: true),
    );
    final categoryLinkRows = unwrapRepositoryResult(
      await _categoryRepo.activityCategoryLinks(includeDeleted: true),
    );
    final entryRows = scope == null
        ? unwrapRepositoryResult(await _entryRepo.allEntries())
        : await _timeEntriesForUndoWindows(scope.entryWindows);
    final logRows = scope == null
        ? unwrapRepositoryResult(await _logRepo.allActionLogs())
        : await _actionLogsForUndoWindows(scope.actionLogWindows);
    return RepositoryUndoSnapshot(
      activities: {
        for (final activity in activityRows) activity.id: activity,
      },
      categories: {
        for (final category in categoryRows) category.id: category,
      },
      categoryLinks: {
        for (final link in categoryLinkRows) link.id: link,
      },
      timeEntries: {
        for (final entry in entryRows) entry.id: entry,
      },
      actionLogs: {
        for (final log in logRows) log.id: log,
      },
    );
  }

  Future<void> applyUndoChangeSet(
    RepositoryUndoChangeSet changeSet, {
    required RepositoryUndoDirection direction,
  }) async {
    if (changeSet.isEmpty) {
      return;
    }
    final db = await _database.db;
    final updatedAt = DateTime.now();
    await db.transaction((txn) async {
      await _validateUndoChangeSet(txn, changeSet, direction);
      for (final change in changeSet.activities) {
        await _applyActivityUndoChange(txn, change, direction, updatedAt);
      }
      for (final change in changeSet.categories) {
        await _applyCategoryUndoChange(txn, change, direction, updatedAt);
      }
      for (final change in changeSet.categoryLinks) {
        await _applyCategoryLinkUndoChange(txn, change, direction, updatedAt);
      }
      for (final change in changeSet.timeEntries) {
        await _applyEntryUndoChange(txn, change, direction, updatedAt);
      }
      for (final change in changeSet.actionLogs) {
        await _applyActionLogUndoChange(txn, change, direction, updatedAt);
      }
    });
    final actionLabel = direction == RepositoryUndoDirection.undo ? '撤销' : '重做';
    unwrapRepositoryResult(
      await _logRepo.addActionLog(
        actionType: direction == RepositoryUndoDirection.undo
            ? ActionType.undo
            : ActionType.redo,
        activityId: null,
        entryId: null,
        occurredAt: updatedAt,
        message: '$actionLabel：${changeSet.label}',
      ),
    );
  }

  Future<List<TimeEntry>> _timeEntriesForUndoWindows(
    List<RepositoryUndoWindow> windows,
  ) async {
    final db = await _database.db;
    final entriesById = <String, TimeEntry>{};
    for (final window in _mergedUndoWindows(windows)) {
      final rows = await db.query(
        'time_entries',
        where: 'start_at < ? and (end_at is null or end_at > ?)',
        whereArgs: [window.endValue, window.startValue],
        orderBy: 'updated_at asc',
      );
      for (final row in rows) {
        final entry = TimeEntry.fromMap(row);
        entriesById[entry.id] = entry;
      }
    }
    return entriesById.values.toList();
  }

  Future<List<ActionLog>> _actionLogsForUndoWindows(
    List<RepositoryUndoWindow> windows,
  ) async {
    final db = await _database.db;
    final logsById = <String, ActionLog>{};
    for (final window in _mergedUndoWindows(windows)) {
      final rows = await db.query(
        'action_logs',
        where: 'occurred_at >= ? and occurred_at < ?',
        whereArgs: [window.startValue, window.endValue],
        orderBy: 'updated_at asc',
      );
      for (final row in rows) {
        final log = ActionLog.fromMap(row);
        logsById[log.id] = log;
      }
    }
    return logsById.values.toList();
  }

  List<RepositoryUndoWindow> _mergedUndoWindows(
    List<RepositoryUndoWindow> windows,
  ) {
    final sorted = [
      for (final window in windows)
        if (!window.isEmpty) window,
    ]..sort((first, second) => first.start.compareTo(second.start));
    if (sorted.isEmpty) {
      return const [];
    }

    final merged = <RepositoryUndoWindow>[];
    var current = sorted.first;
    for (final window in sorted.skip(1)) {
      if (!window.start.isAfter(current.end)) {
        current = RepositoryUndoWindow(
          start: current.start,
          end: window.end.isAfter(current.end) ? window.end : current.end,
        );
        continue;
      }
      merged.add(current);
      current = window;
    }
    merged.add(current);
    return merged;
  }

  Future<void> _validateUndoChangeSet(
    DatabaseExecutor executor,
    RepositoryUndoChangeSet changeSet,
    RepositoryUndoDirection direction,
  ) async {
    for (final change in changeSet.activities) {
      final current = await _activityRepo.activityById(change.id, executor);
      if (!_rowMatchesExpected<Activity>(
        current: current,
        expected: change.expectedFor(direction),
        toMap: (value) => value.toLocalMap(),
        isDeleted: (value) => value.isDeleted,
      )) {
        throw _undoConflict(direction);
      }
    }
    for (final change in changeSet.categories) {
      final current = await _categoryRepo.categoryById(change.id, executor);
      if (!_rowMatchesExpected<ActivityCategory>(
        current: current,
        expected: change.expectedFor(direction),
        toMap: (value) => value.toLocalMap(),
        isDeleted: (value) => value.isDeleted,
      )) {
        throw _undoConflict(direction);
      }
    }
    for (final change in changeSet.categoryLinks) {
      final current = await _categoryRepo.categoryLinkById(change.id, executor);
      if (!_rowMatchesExpected<ActivityCategoryLink>(
        current: current,
        expected: change.expectedFor(direction),
        toMap: (value) => value.toLocalMap(),
        isDeleted: (value) => value.isDeleted,
      )) {
        throw _undoConflict(direction);
      }
    }
    for (final change in changeSet.timeEntries) {
      final current = await _entryRepo.entryByIdWithExecutor(
        change.id,
        executor,
      );
      if (!_rowMatchesExpected<TimeEntry>(
        current: current,
        expected: change.expectedFor(direction),
        toMap: (value) => value.toLocalMap(),
        isDeleted: (value) => value.isDeleted,
      )) {
        throw _undoConflict(direction);
      }
    }
    for (final change in changeSet.actionLogs) {
      final current = await _logRepo.actionLogById(change.id, executor);
      if (!_rowMatchesExpected<ActionLog>(
        current: current,
        expected: change.expectedFor(direction),
        toMap: (value) => value.toLocalMap(),
        isDeleted: (value) => value.isDeleted,
      )) {
        throw _undoConflict(direction);
      }
    }
  }

  RepositoryUndoConflictException _undoConflict(
    RepositoryUndoDirection direction,
  ) {
    final actionLabel = direction == RepositoryUndoDirection.undo ? '撤销' : '重做';
    return RepositoryUndoConflictException('数据已变化，无法$actionLabel。');
  }

  Future<void> _applyActivityUndoChange(
    DatabaseExecutor executor,
    RepositoryUndoRowChange<Activity> change,
    RepositoryUndoDirection direction,
    DateTime updatedAt,
  ) async {
    final target = change.targetFor(direction);
    final fallback = change.fallbackFor(direction);
    final value = target?.copyWith(updatedAt: updatedAt) ??
        fallback?.copyWith(isDeleted: true, updatedAt: updatedAt);
    if (value == null) {
      return;
    }
    await executor.insert(
      'activities',
      value.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _applyCategoryUndoChange(
    DatabaseExecutor executor,
    RepositoryUndoRowChange<ActivityCategory> change,
    RepositoryUndoDirection direction,
    DateTime updatedAt,
  ) async {
    final target = change.targetFor(direction);
    final fallback = change.fallbackFor(direction);
    final value = target?.copyWith(updatedAt: updatedAt) ??
        fallback?.copyWith(isDeleted: true, updatedAt: updatedAt);
    if (value == null) {
      return;
    }
    await executor.insert(
      'activity_categories',
      value.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _applyCategoryLinkUndoChange(
    DatabaseExecutor executor,
    RepositoryUndoRowChange<ActivityCategoryLink> change,
    RepositoryUndoDirection direction,
    DateTime updatedAt,
  ) async {
    final target = change.targetFor(direction);
    final fallback = change.fallbackFor(direction);
    final value = target?.copyWith(updatedAt: updatedAt) ??
        fallback?.copyWith(isDeleted: true, updatedAt: updatedAt);
    if (value == null) {
      return;
    }
    await executor.insert(
      'activity_category_links',
      value.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _applyEntryUndoChange(
    DatabaseExecutor executor,
    RepositoryUndoRowChange<TimeEntry> change,
    RepositoryUndoDirection direction,
    DateTime updatedAt,
  ) async {
    final target = change.targetFor(direction);
    final fallback = change.fallbackFor(direction);
    final value = target?.copyWith(updatedAt: updatedAt) ??
        fallback?.copyWith(isDeleted: true, updatedAt: updatedAt);
    if (value == null) {
      return;
    }
    await executor.insert(
      'time_entries',
      value.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _applyActionLogUndoChange(
    DatabaseExecutor executor,
    RepositoryUndoRowChange<ActionLog> change,
    RepositoryUndoDirection direction,
    DateTime updatedAt,
  ) async {
    final target = change.targetFor(direction);
    final fallback = change.fallbackFor(direction);
    final value = target?.copyWith(updatedAt: updatedAt) ??
        fallback?.copyWith(isDeleted: true, updatedAt: updatedAt);
    if (value == null) {
      return;
    }
    await executor.insert(
      'action_logs',
      value.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  bool _rowMatchesExpected<T>({
    required T? current,
    required T? expected,
    required Map<String, Object?> Function(T value) toMap,
    required bool Function(T value) isDeleted,
  }) {
    if (expected == null) {
      return current == null || isDeleted(current);
    }
    if (current == null) {
      return isDeleted(expected);
    }
    return _comparableMapsEqual(toMap(current), toMap(expected));
  }

  bool _comparableMapsEqual(
    Map<String, Object?> current,
    Map<String, Object?> expected,
  ) {
    final currentComparable = _comparableUndoMap(current);
    final expectedComparable = _comparableUndoMap(expected);
    if (currentComparable.length != expectedComparable.length) {
      return false;
    }
    for (final entry in currentComparable.entries) {
      if (expectedComparable[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  Map<String, Object?> _comparableUndoMap(Map<String, Object?> value) {
    return {...value}
      ..remove('updated_at')
      ..remove('user_id');
  }
}
