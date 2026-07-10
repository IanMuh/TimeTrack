// ignore_for_file: unused_element

part of 'time_entry_repository.dart';

mixin TimeEntryRepositoryEditLogic
    on
        TimeEntryRepositoryQueryLogic,
        TimeEntryRepositoryStorageLogic,
        TimeEntryRepositorySupportLogic,
        TimeEntryRepositoryCommandLogic {
  @override
  ActivityRepository get _activityRepo;
  @override
  Uuid get _uuid;

  @override
  DateTime _now();

  @override
  Future<List<TimeEntry>> _saveEntry(
    TimeEntry entry, {
    bool logEdit = false,
    bool cutOverlaps = false,
  });

  Future<List<TimeEntry>> _splitEntry({
    required String entryId,
    required DateTime splitAt,
  }) async {
    final current = await entryById(entryId);
    if (current == null || current.isDeleted || current.isRunning) {
      throw TimeEntryRepositoryException(
        TimeEntryRepositoryFailureCode.entryNotSplitable,
      );
    }
    final endAt = current.endAt;
    if (endAt == null ||
        !current.startAt.isBefore(splitAt) ||
        !splitAt.isBefore(endAt)) {
      throw TimeEntryRepositoryException(
        TimeEntryRepositoryFailureCode.splitOutOfRange,
      );
    }

    final now = _now();
    final saved = <TimeEntry>[];
    final db = await _database.db;
    await db.transaction((txn) async {
      final first = await _activityRepo.entryWithActivitySnapshot(
        current.copyWith(endAt: splitAt, updatedAt: now),
        txn,
      );
      final second = await _activityRepo.entryWithActivitySnapshot(
        current.copyWith(
          id: _uuid.v4(),
          startAt: splitAt,
          endAt: endAt,
          updatedAt: now,
        ),
        txn,
      );
      saved
        ..addAll(await _saveEntryRows(txn, first))
        ..addAll(await _saveEntryRows(txn, second));
    });
    await _insertActionLog(
      actionType: ActionType.split,
      activityId: current.activityId,
      entryId: current.id,
      occurredAt: now,
      message: '切割时间段',
    );
    return saved;
  }

  Future<TimeEntry> _createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
    String? userId,
  }) async {
    final now = _now();
    final deviceId = await _currentDeviceId();
    final entry = TimeEntry(
      id: _uuid.v4(),
      userId: userId,
      activityId: activityId,
      startAt: startAt,
      endAt: endAt,
      note: note,
      deviceId: deviceId,
      updatedAt: now,
      isDeleted: false,
    );
    final saved = await _saveEntry(entry, cutOverlaps: true);
    await _insertActionLog(
      actionType: ActionType.manual,
      activityId: activityId,
      entryId: entry.id,
      occurredAt: now,
      message: '补记时间段',
    );
    return saved.first;
  }

  Future<void> _deleteEntry(TimeEntry entry) async {
    final now = _now();
    await _saveEntry(entry.copyWith(isDeleted: true, updatedAt: now));
    await _insertActionLog(
      actionType: ActionType.delete,
      activityId: entry.activityId,
      entryId: entry.id,
      occurredAt: now,
      message: '删除时间段',
    );
  }

  Future<TimeEntry?> _mergeEntryWithNeighbor({
    required String entryId,
    required EntryMergeDirection direction,
    required bool confirmed,
  }) async {
    final candidate = await _mergeCandidateForEntry(entryId, direction);
    if (candidate == null) {
      return null;
    }
    if (candidate.requiresConfirmation && !confirmed) {
      throw TimeEntryRepositoryException(
        TimeEntryRepositoryFailureCode.mergeConfirmationRequired,
      );
    }

    final now = _now();
    final current = candidate.current;
    final neighbor = candidate.neighbor;
    final startAt = current.startAt.isBefore(neighbor.startAt)
        ? current.startAt
        : neighbor.startAt;
    final currentEnd = current.endAt!;
    final neighborEnd = neighbor.endAt!;
    final endAt = currentEnd.isAfter(neighborEnd) ? currentEnd : neighborEnd;
    final merged = current.copyWith(
      startAt: startAt,
      endAt: endAt,
      note: _mergedNotes(current.note, neighbor.note),
      updatedAt: now,
    );

    final db = await _database.db;
    await db.transaction((txn) async {
      await _saveEntryRows(
        txn,
        await _activityRepo.entryWithActivitySnapshot(merged, txn),
      );
      await txn.insert(
        'time_entries',
        neighbor.copyWith(isDeleted: true, updatedAt: now).toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await _insertActionLog(
      actionType: ActionType.merge,
      activityId: merged.activityId,
      entryId: merged.id,
      occurredAt: now,
      message: direction == EntryMergeDirection.previous ? '合并左侧' : '合并右侧',
    );
    return merged;
  }

  Future<void> _replaceEntryIfRemoteNewer(TimeEntry remote) async {
    final db = await _database.db;
    final localRows = await db.query(
      'time_entries',
      where: 'id = ?',
      whereArgs: [remote.id],
      limit: 1,
    );
    if (localRows.isEmpty ||
        TimeEntry.fromMap(localRows.first)
            .updatedAt
            .isBefore(remote.updatedAt)) {
      await _saveEntry(remote);
    }
  }
}
