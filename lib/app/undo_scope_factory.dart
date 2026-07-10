import '../data/repository_undo.dart';
import '../domain/time_entry.dart';

typedef UndoDateTimeReader = DateTime Function();
typedef UndoEntriesReader = List<TimeEntry> Function();
typedef UndoRunningEntryReader = TimeEntry? Function();

class UndoScopeFactory {
  const UndoScopeFactory({
    required UndoDateTimeReader selectedDay,
    required UndoDateTimeReader now,
    required UndoDateTimeReader systemNow,
    required UndoDateTimeReader operationNow,
    required UndoEntriesReader dayEntries,
    required UndoRunningEntryReader runningEntry,
  })  : _selectedDay = selectedDay,
        _now = now,
        _systemNow = systemNow,
        _operationNow = operationNow,
        _dayEntries = dayEntries,
        _runningEntry = runningEntry;

  final UndoDateTimeReader _selectedDay;
  final UndoDateTimeReader _now;
  final UndoDateTimeReader _systemNow;
  final UndoDateTimeReader _operationNow;
  final UndoEntriesReader _dayEntries;
  final UndoRunningEntryReader _runningEntry;

  RepositoryUndoScope activeEntryScope() {
    final windows = <RepositoryUndoWindow>[];
    final entry = _runningEntry();
    if (entry != null) {
      windows.add(_entryWindow(entry, fallbackEnd: _operationNow()));
    }
    return _scopeForWindows(windows);
  }

  RepositoryUndoScope entryScope(
    TimeEntry entry, {
    DateTime? fallbackEnd,
  }) {
    return _scopeForWindows([
      _entryWindow(entry, fallbackEnd: fallbackEnd),
    ]);
  }

  RepositoryUndoScope entryIdScope(
    String entryId, {
    List<DateTime> extraDays = const [],
  }) {
    final entry = _loadedEntryById(entryId);
    return _scopeForWindows([
      if (entry != null) _entryWindow(entry, fallbackEnd: _operationNow()),
      for (final day in extraDays) RepositoryUndoWindow.forLocalDay(day),
    ]);
  }

  RepositoryUndoScope entryIntervalScope(
    DateTime start,
    DateTime end,
  ) {
    return _scopeForWindows([
      RepositoryUndoWindow.covering(start, end),
    ]);
  }

  RepositoryUndoWindow _entryWindow(
    TimeEntry entry, {
    DateTime? fallbackEnd,
  }) {
    return RepositoryUndoWindow.covering(
      entry.startAt,
      entry.endAt ?? fallbackEnd ?? _operationNow(),
    );
  }

  RepositoryUndoScope _scopeForWindows(
    Iterable<RepositoryUndoWindow> windows,
  ) {
    final entryWindows = <RepositoryUndoWindow>[
      ...windows,
      RepositoryUndoWindow.forLocalDay(_selectedDay()),
      RepositoryUndoWindow.forLocalDay(_now()),
      RepositoryUndoWindow.forLocalDay(_systemNow()),
    ];
    return RepositoryUndoScope(
      entryWindows: entryWindows,
      actionLogWindows: entryWindows,
    );
  }

  TimeEntry? _loadedEntryById(String entryId) {
    for (final entry in _dayEntries()) {
      if (entry.id == entryId) {
        return entry;
      }
    }
    final current = _runningEntry();
    if (current?.id == entryId) {
      return current;
    }
    return null;
  }
}
