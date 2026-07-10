part of 'time_entry_repository.dart';

class _EntryInterval {
  const _EntryInterval(this.startAt, this.endAt);

  final DateTime startAt;
  final DateTime? endAt;
}

mixin TimeEntryRepositoryStorageLogic {
  Uuid get _uuid;

  List<TimeEntry> _entryRowsForStorage(TimeEntry entry) {
    return entry.isDeleted || entry.isRunning
        ? [entry]
        : _splitClosedEntryByLocalDay(entry, entry.updatedAt);
  }

  Future<void> _insertEntryRows(
    DatabaseExecutor executor,
    List<TimeEntry> entries,
  ) async {
    for (final item in entries) {
      await executor.insert(
        'time_entries',
        item.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<TimeEntry>> _saveEntryRows(
    DatabaseExecutor executor,
    TimeEntry entry,
  ) async {
    final entries = _entryRowsForStorage(entry);
    await _insertEntryRows(executor, entries);
    return entries;
  }

  Future<void> _cutOverlappingEntries(
    DatabaseExecutor executor,
    List<TimeEntry> replacements,
    DateTime updatedAt,
  ) async {
    final replacementEntries = replacements
        .where(
          (entry) =>
              !entry.isDeleted &&
              (entry.endAt == null || entry.startAt.isBefore(entry.endAt!)),
        )
        .toList()
      ..sort((first, second) => first.startAt.compareTo(second.startAt));
    if (replacementEntries.isEmpty) {
      return;
    }

    final protectedIds = replacementEntries.map((entry) => entry.id).toSet();
    final firstStart = replacementEntries.first.startAt;
    final hasRunningReplacement = replacementEntries.any(
      (entry) => entry.endAt == null,
    );
    final finiteReplacementEnds = [
      for (final entry in replacementEntries)
        if (entry.endAt != null) entry.endAt!,
    ];
    final lastEnd = finiteReplacementEnds.isEmpty
        ? null
        : finiteReplacementEnds.reduce(
            (first, second) => first.isAfter(second) ? first : second,
          );
    final rows = await executor.query(
      'time_entries',
      where: hasRunningReplacement
          ? 'is_deleted = 0 and (end_at is null or end_at > ?)'
          : 'is_deleted = 0 and start_at < ? and '
              '(end_at is null or end_at > ?)',
      whereArgs: hasRunningReplacement
          ? [firstStart.toUtc().toIso8601String()]
          : [
              lastEnd!.toUtc().toIso8601String(),
              firstStart.toUtc().toIso8601String(),
            ],
      orderBy: 'is_deleted asc, start_at asc, end_at asc',
    );

    for (final row in rows) {
      final candidate = TimeEntry.fromMap(row);
      if (protectedIds.contains(candidate.id)) {
        continue;
      }
      final pieces = _cutEntryByReplacements(
        candidate,
        replacementEntries,
        updatedAt,
      );
      if (pieces.length == 1 &&
          pieces.single.startAt == candidate.startAt &&
          pieces.single.endAt == candidate.endAt) {
        continue;
      }
      if (pieces.isEmpty) {
        await _insertEntryRows(
          executor,
          [candidate.copyWith(isDeleted: true, updatedAt: updatedAt)],
        );
        continue;
      }
      await _saveEntryRows(executor, pieces.first);
      for (final piece in pieces.skip(1)) {
        await _saveEntryRows(executor, piece);
      }
    }
  }

  List<TimeEntry> _cutEntryByReplacements(
    TimeEntry entry,
    List<TimeEntry> replacements,
    DateTime updatedAt,
  ) {
    var remaining = [_EntryInterval(entry.startAt, entry.endAt)];
    for (final replacement in replacements) {
      final replacementEnd = replacement.endAt;
      final next = <_EntryInterval>[];
      for (final interval in remaining) {
        final intervalEnd = interval.endAt;
        final overlaps = replacementEnd == null
            ? intervalEnd == null || replacement.startAt.isBefore(intervalEnd)
            : interval.startAt.isBefore(replacementEnd) &&
                (intervalEnd == null ||
                    replacement.startAt.isBefore(intervalEnd));
        if (!overlaps) {
          next.add(interval);
          continue;
        }
        if (interval.startAt.isBefore(replacement.startAt)) {
          next.add(_EntryInterval(interval.startAt, replacement.startAt));
        }
        if (replacementEnd != null &&
            (intervalEnd == null || replacementEnd.isBefore(intervalEnd))) {
          next.add(_EntryInterval(replacementEnd, intervalEnd));
        }
      }
      remaining = next;
      if (remaining.isEmpty) {
        break;
      }
    }

    final pieces = <TimeEntry>[];
    var first = true;
    for (final interval in remaining) {
      pieces.add(
        entry.copyWith(
          id: first ? entry.id : _uuid.v4(),
          startAt: interval.startAt,
          endAt: interval.endAt,
          clearEndAt: interval.endAt == null,
          updatedAt: updatedAt,
        ),
      );
      first = false;
    }
    return pieces;
  }

  List<TimeEntry> _splitClosedEntryByLocalDay(
    TimeEntry entry,
    DateTime updatedAt,
  ) {
    final endAt = entry.endAt;
    if (endAt == null || !entry.startAt.isBefore(endAt)) {
      return [entry];
    }
    final entries = <TimeEntry>[];
    var cursor = entry.startAt;
    var first = true;
    while (cursor.isBefore(endAt)) {
      final dayEnd = cursor.startOfDay.add(const Duration(days: 1));
      final segmentEnd = endAt.isBefore(dayEnd) ? endAt : dayEnd;
      if (cursor.isBefore(segmentEnd)) {
        entries.add(
          entry.copyWith(
            id: first ? entry.id : _uuid.v4(),
            startAt: cursor,
            endAt: segmentEnd,
            updatedAt: updatedAt,
          ),
        );
      }
      cursor = segmentEnd;
      first = false;
    }
    return entries.isEmpty ? [entry] : entries;
  }
}
