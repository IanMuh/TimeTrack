// ignore_for_file: unused_element

part of 'time_entry_repository.dart';

mixin TimeEntryRepositoryCommandLogic
    on
        TimeEntryRepositoryQueryLogic,
        TimeEntryRepositoryStorageLogic,
        TimeEntryRepositorySupportLogic,
        TimeEntryRepositoryNormalizationLogic {
  @override
  ActivityRepository get _activityRepo;

  @override
  DateTime _now();

  @override
  Future<TimeEntry> _switchToActivity(
    String activityId, {
    DateTime? at,
  }) async {
    final now = at ?? _now();
    await rolloverRunningEntriesIfNeeded(at: now);
    final deviceId = await _currentDeviceId();
    final targetIsUnassigned =
        await _activityRepo.activityIdIsUnassigned(activityId);
    final db = await _database.db;
    late TimeEntry next;
    String? previousActivityId;
    await db.transaction((txn) async {
      final runningRows = await txn.query(
        'time_entries',
        where: 'end_at is null and is_deleted = 0',
        orderBy: 'start_at desc',
      );

      if (targetIsUnassigned && runningRows.isNotEmpty) {
        final running = TimeEntry.fromMap(runningRows.first);
        if (running.activityId == activityId) {
          next = running;
          return;
        }
      }

      for (final row in runningRows) {
        final running = TimeEntry.fromMap(row);
        previousActivityId ??= running.activityId;
        if (running.startAt.isBefore(now)) {
          await _saveEntryRows(
            txn,
            await _activityRepo.entryWithActivitySnapshot(
              running.copyWith(endAt: now, updatedAt: now),
              txn,
            ),
          );
          await _activityRepo.softDeleteOneOffActivityIfNeeded(
            running.activityId,
            now,
            txn,
          );
        } else {
          await txn.insert(
            'time_entries',
            running.copyWith(isDeleted: true, updatedAt: now).toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await _activityRepo.softDeleteOneOffActivityIfNeeded(
            running.activityId,
            now,
            txn,
          );
        }
      }

      next = await _activityRepo.entryWithActivitySnapshot(
        TimeEntry(
          id: _uuid.v4(),
          userId: null,
          activityId: activityId,
          startAt: now,
          endAt: null,
          note: '',
          deviceId: deviceId,
          updatedAt: now,
          isDeleted: false,
        ),
        txn,
      );
      await txn.insert('time_entries', next.toLocalMap());
      await txn.insert(
        'action_logs',
        _buildActionLog(
          actionType: ActionType.switch_,
          activityId: activityId,
          entryId: next.id,
          occurredAt: now,
          message: previousActivityId == null ? '开始事项' : '切换事项',
        ).toLocalMap(),
      );
    });
    if (targetIsUnassigned) {
      await mergeAdjacentUnassignedEntries(activityId, updatedAt: now);
      return await _runningEntry() ?? next;
    }
    return next;
  }

  Future<void> _stopRunning({DateTime? at}) async {
    final now = at ?? _now();
    await rolloverRunningEntriesIfNeeded(at: now);
    final unassigned = await _activityRepo.ensureUnassignedActivity();
    final running = await _runningEntry();
    if (running == null) {
      await _startUnassigned(at: now);
      return;
    }
    if (running.activityId == unassigned.id) {
      await mergeAdjacentUnassignedEntries(unassigned.id, updatedAt: now);
      return;
    }
    if (running.startAt.isAfter(now)) {
      await _saveEntry(
        running.copyWith(isDeleted: true, updatedAt: now),
      );
      await _activityRepo.softDeleteOneOffActivityIfNeeded(
        running.activityId,
        now,
      );
      await _startUnassigned(at: now);
      return;
    }
    await _saveEntry(running.copyWith(endAt: now, updatedAt: now));
    await _activityRepo.softDeleteOneOffActivityIfNeeded(
      running.activityId,
      now,
    );
    await _insertActionLog(
      actionType: ActionType.stop,
      activityId: running.activityId,
      entryId: running.id,
      occurredAt: now,
      message: '停止事项',
    );
    await _startUnassigned(at: now);
  }

  @override
  Future<List<TimeEntry>> _saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  }) async {
    final db = await _database.db;
    final saved = <TimeEntry>[];
    await db.transaction((txn) async {
      final normalized =
          await _activityRepo.entryWithActivitySnapshot(entry, txn);
      final entries = _entryRowsForStorage(normalized);
      if (cutOverlaps) {
        await _cutOverlappingEntries(txn, entries, normalized.updatedAt);
      }
      await _insertEntryRows(txn, entries);
      saved.addAll(entries);
    });
    if (logEdit) {
      final editOccurredAt = saved.first.updatedAt;
      await _insertActionLog(
        actionType: ActionType.edit,
        activityId: entry.activityId,
        entryId: entry.id,
        occurredAt: editOccurredAt,
        message: '编辑时间段',
      );
    }
    return saved;
  }

  Future<List<TimeEntry>> saveEntryRows(
    DatabaseExecutor executor,
    TimeEntry entry,
  ) async {
    final entries = _entryRowsForStorage(entry);
    await _insertEntryRows(executor, entries);
    return entries;
  }
}
