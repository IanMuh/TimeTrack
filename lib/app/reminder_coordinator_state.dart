import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';
import 'reminder_state.dart';

typedef ReminderNowReader = DateTime Function();
typedef ReminderSettingsReader = ProfileSettings Function();
typedef ReminderRunningEntryReader = TimeEntry? Function();
typedef ReminderEntryClassifier = bool Function(TimeEntry entry);
typedef ReminderChangeNotifier = void Function();

class ReminderCoordinatorState {
  ReminderCoordinatorState({
    required ReminderState reminderState,
    required ReminderNowReader now,
    required ReminderNowReader actionNow,
    required ReminderSettingsReader settings,
    required ReminderRunningEntryReader runningEntry,
    required ReminderEntryClassifier entryIsUnassigned,
    required ReminderChangeNotifier notifyListeners,
  })  : _reminderState = reminderState,
        _now = now,
        _actionNow = actionNow,
        _settings = settings,
        _runningEntry = runningEntry,
        _entryIsUnassigned = entryIsUnassigned,
        _notifyListeners = notifyListeners;

  final ReminderState _reminderState;
  final ReminderNowReader _now;
  final ReminderNowReader _actionNow;
  final ReminderSettingsReader _settings;
  final ReminderRunningEntryReader _runningEntry;
  final ReminderEntryClassifier _entryIsUnassigned;
  final ReminderChangeNotifier _notifyListeners;

  DateTime? get lastReminderAt => _reminderState.lastReminderAt;

  set lastReminderAt(DateTime? value) {
    _reminderState.lastReminderAt = value;
  }

  String? get ignoredSuspiciousEntryId {
    return _reminderState.ignoredSuspiciousEntryId;
  }

  set ignoredSuspiciousEntryId(String? value) {
    _reminderState.ignoredSuspiciousEntryId = value;
  }

  bool get shouldShowReminder {
    return _reminderState.shouldShowReminder(
      runningEntry: _runningEntry(),
      settings: _settings(),
      now: _now(),
      entryIsUnassigned: _entryIsUnassigned,
    );
  }

  bool get shouldShowReminderDialog {
    return _reminderState.shouldShowReminderDialog(
      runningEntry: _runningEntry(),
      settings: _settings(),
      now: _now(),
      entryIsUnassigned: _entryIsUnassigned,
    );
  }

  bool get shouldShowReminderBanner {
    return _reminderState.shouldShowReminderBanner(
      runningEntry: _runningEntry(),
      settings: _settings(),
      now: _now(),
      entryIsUnassigned: _entryIsUnassigned,
    );
  }

  bool get hasSuspiciousRunningEntry {
    return _reminderState.hasSuspiciousRunningEntry(
      runningEntry: _runningEntry(),
      now: _now(),
      entryIsUnassigned: _entryIsUnassigned,
    );
  }

  Future<void> continueCurrent() async {
    _reminderState.markReminded(_actionNow());
    _notifyListeners();
  }

  Future<void> snoozeReminder() async {
    await continueCurrent();
  }

  Future<void> ignoreSuspiciousRunning() async {
    _reminderState.ignoreSuspiciousRunning(_runningEntry());
    await continueCurrent();
  }
}
