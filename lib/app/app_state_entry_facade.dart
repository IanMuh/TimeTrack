part of 'app_state.dart';

mixin AppStateEntryFacade on ChangeNotifier {
  EntryState get _entryState;

  List<TimeEntry> get dayEntries => _entryState.dayEntries;

  set dayEntries(List<TimeEntry> value) => _entryState.dayEntries = value;

  List<ActionLog> get dayActionLogs => _entryState.dayActionLogs;

  set dayActionLogs(List<ActionLog> value) {
    _entryState.dayActionLogs = value;
  }

  TimeEntry? get runningEntry => _entryState.runningEntry;

  set runningEntry(TimeEntry? value) => _entryState.runningEntry = value;
}
