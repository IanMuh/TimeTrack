part of 'app_state.dart';

mixin AppStateReminderFacade on ChangeNotifier {
  ReminderCoordinatorState get _reminderCoordinatorState;

  bool get shouldShowReminder => _reminderCoordinatorState.shouldShowReminder;

  bool get shouldShowReminderDialog {
    return _reminderCoordinatorState.shouldShowReminderDialog;
  }

  bool get shouldShowReminderBanner {
    return _reminderCoordinatorState.shouldShowReminderBanner;
  }

  bool get hasSuspiciousRunningEntry {
    return _reminderCoordinatorState.hasSuspiciousRunningEntry;
  }

  DateTime? get lastReminderAt => _reminderCoordinatorState.lastReminderAt;

  set lastReminderAt(DateTime? value) {
    _reminderCoordinatorState.lastReminderAt = value;
  }

  String? get ignoredSuspiciousEntryId {
    return _reminderCoordinatorState.ignoredSuspiciousEntryId;
  }

  set ignoredSuspiciousEntryId(String? value) {
    _reminderCoordinatorState.ignoredSuspiciousEntryId = value;
  }

  Future<void> continueCurrent() {
    return _reminderCoordinatorState.continueCurrent();
  }

  Future<void> snoozeReminder() {
    return _reminderCoordinatorState.snoozeReminder();
  }

  Future<void> ignoreSuspiciousRunning() {
    return _reminderCoordinatorState.ignoreSuspiciousRunning();
  }
}
