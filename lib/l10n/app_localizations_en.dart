// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TimeTrack';

  @override
  String get appSubtitle =>
      'Offline-first tracking. Pick an activity to get started.';

  @override
  String get navCurrent => 'Now';

  @override
  String get navTimeline => 'Timeline';

  @override
  String get navStats => 'Stats';

  @override
  String get navSettings => 'Settings';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get syncStatusLocal => 'Local mode';

  @override
  String get syncStatusCloud => 'Sync ready';

  @override
  String get activityUnassigned => 'Unassigned';

  @override
  String get reminderClose => 'Close';

  @override
  String get emptyTimeline => 'No entries yet';

  @override
  String get sync => 'Sync';

  @override
  String get edit => 'Edit';

  @override
  String get create => 'Create';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get continueLabel => 'Continue';

  @override
  String get confirm => 'Confirm';

  @override
  String get undoHint => 'Undo Ctrl+Z';

  @override
  String undoWithLabel(String label) {
    return 'Undo: $label Ctrl+Z';
  }

  @override
  String get redoHint => 'Redo Ctrl+Y';

  @override
  String redoWithLabel(String label) {
    return 'Redo: $label Ctrl+Y';
  }

  @override
  String get quickSwitch => 'Quick Switch';

  @override
  String get quickSwitchHint => 'Tap to select, tap again to confirm switch.';

  @override
  String quickSwitchSelected(String name) {
    return 'Selected $name, tap again to switch.';
  }

  @override
  String get currentDoing => 'Currently doing';

  @override
  String get notStarted => 'Not started';

  @override
  String get recording => 'Recording';

  @override
  String get notStartedRecord => 'Not started';

  @override
  String get selectActivityToStart =>
      'Pick an activity to start tracking today.';

  @override
  String elapsedDuration(String duration) {
    return 'Elapsed $duration';
  }

  @override
  String get stopCurrentActivity => 'Stop current activity';

  @override
  String confirmSwitchSemantics(String name) {
    return 'Confirm switch to $name';
  }

  @override
  String currentActivitySemantics(String name) {
    return 'Current activity $name';
  }

  @override
  String switchToSemantics(String name) {
    return 'Switch to $name';
  }

  @override
  String get systemActivityCannotEdit => 'System activity, cannot edit';

  @override
  String get editActivity => 'Edit activity';

  @override
  String get oneOffActivity => 'One-off activity';

  @override
  String get newActivity => 'New activity';

  @override
  String get editActivityTitle => 'Edit activity';

  @override
  String get name => 'Name';

  @override
  String get deleteActivityTitle => 'Delete activity';

  @override
  String confirmDeleteActivity(String name) {
    return 'Delete \"$name\"? Existing time records will be kept, but this activity can no longer be selected.';
  }

  @override
  String selectColorTooltip(String hex) {
    return 'Select color $hex';
  }

  @override
  String get rgbTuner => 'RGB Tuner';

  @override
  String get oneOff => 'One-off';

  @override
  String activityRunningMinutes(int minutes) {
    return 'Current activity has been running for $minutes minutes.';
  }

  @override
  String get remindLater => 'Remind later';

  @override
  String get stillDoingThis => 'Still working on this?';

  @override
  String get confirmPreviousPeriod => 'Confirm previous period';

  @override
  String get noRunningActivity => 'No running activity.';

  @override
  String suspiciousEntryContent(String time) {
    return 'Current activity started at $time and has been running for a while. You can end it now and fill in gaps later.';
  }

  @override
  String get keepCurrent => 'Keep current';

  @override
  String get endToNow => 'End now';

  @override
  String get syncing => 'Syncing';

  @override
  String get cloudSyncActive => 'Signed in with cloud sync';

  @override
  String get lanPeerPaired => 'Paired with LAN host';

  @override
  String get localModeHint =>
      'Local mode: enable LAN sharing or import/export in Settings';

  @override
  String get selectDate => 'Select date';

  @override
  String get previousDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String get emptyDayEntries => 'No entries for this day.';

  @override
  String get emptyRangeEntries => 'No entries for this range.';

  @override
  String get emptyDayActions => 'No switches or edits for this day.';

  @override
  String get emptyRangeActions => 'No switches or edits for this range.';

  @override
  String get timeline => 'Timeline';

  @override
  String get compact => 'Compact';

  @override
  String get detailed => 'Detailed';

  @override
  String get singleDay => '1 day';

  @override
  String get threeDays => '3 days';

  @override
  String get sevenDays => '7 days';

  @override
  String get addEntry => 'Add entry';

  @override
  String get viewMode => 'View';

  @override
  String get entries => 'Records';

  @override
  String get actions => 'Actions';

  @override
  String futureDayBanner(String date) {
    return '$date hasn\'t arrived yet. Records will appear here after the day actually occurs.';
  }

  @override
  String get dayCoverageLine => 'Day coverage';

  @override
  String get inProgress => 'In progress';

  @override
  String get zoomableTimeline => 'Zoomable timeline';

  @override
  String get timelineDragHint =>
      'Drag horizontally to view the full day scale. Zoom keeps the same time scale.';

  @override
  String get entryList => 'Entry list';

  @override
  String get entryListHint => 'Sorted by start time. Tap any entry to edit.';

  @override
  String get switchToRecordHint =>
      'Switch to adding entries or pick another date.';

  @override
  String editEntrySemantics(String name) {
    return 'Edit $name entry';
  }

  @override
  String get editTooltip => 'Edit';

  @override
  String deviceLabel(String id) {
    return 'Device $id';
  }

  @override
  String get addEntryTitle => 'Add entry';

  @override
  String get editEntryTitle => 'Edit entry';

  @override
  String get selectValidActivity => 'Please select a valid activity.';

  @override
  String get endTime => 'End';

  @override
  String get keepRunning => 'Keep running';

  @override
  String get closeToSaveHint => 'Disable to save this entry as ended.';

  @override
  String get note => 'Note';

  @override
  String get selectExistingOrNew =>
      'Pick an existing activity or type a new name.';

  @override
  String get runningCannotStartFuture =>
      'A running entry cannot start in the future.';

  @override
  String get endMustBeAfterStart => 'End time must be after start time.';

  @override
  String get overlapWarning =>
      'This period overlaps with existing entries. Tap save again to auto-split existing entries.';

  @override
  String get split => 'Split';

  @override
  String get extendToNow => 'Extend to now';

  @override
  String get mergeLeft => 'Merge left';

  @override
  String get mergeRight => 'Merge right';

  @override
  String get noAdjacentRecord => 'No adjacent entry to merge';

  @override
  String get left => 'Left';

  @override
  String get right => 'Right';

  @override
  String mergeDirectionRecord(String direction) {
    return 'Merge $direction';
  }

  @override
  String mergeConfirm(String name, String duration, int threshold) {
    return '$name duration is $duration, exceeding the $threshold min threshold. Merge?';
  }

  @override
  String get merge => 'Merge';

  @override
  String get splitEntryTitle => 'Split entry';

  @override
  String get splitPoint => 'Split point';

  @override
  String get splitPointError => 'Split point must be between start and end.';

  @override
  String get extendEntryError =>
      'Start time is after current time, cannot extend.';

  @override
  String get createActivityTitle => 'Create activity';

  @override
  String get persistent => 'Persistent';

  @override
  String get entryActivityLabel => 'Activity';

  @override
  String get editCurrentActivity => 'Edit current activity';

  @override
  String get noMatchingActivity => 'No matching activity';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get thisWeek => 'This week';

  @override
  String get lastWeek => 'Last week';

  @override
  String get stats => 'Stats';

  @override
  String statsSubtitle(String label) {
    return 'View time distribution and daily totals for $label.';
  }

  @override
  String get range => 'Range';

  @override
  String get customDay => 'Custom day';

  @override
  String get totalRangeRecords => 'Range total';

  @override
  String get longestStreak => 'Longest streak';

  @override
  String distributionChartTitle(String label) {
    return '$label distribution';
  }

  @override
  String get noDataToVisualize => 'No data to visualize yet';

  @override
  String get activityColorLegend =>
      'Grouped by activity, colors match activity colors.';

  @override
  String get noData => 'No data';

  @override
  String get startRecordingHint =>
      'Start recording or select a different range to see the distribution.';

  @override
  String get unknownActivity => 'Unknown activity';

  @override
  String get dailyTotal => 'Daily total';

  @override
  String get dailyTotalHint =>
      'Track your recording rhythm across the week or custom range.';

  @override
  String get recordHint =>
      'Total duration will be listed by date once records exist.';

  @override
  String get settings => 'Settings';

  @override
  String get settingsSubtitle =>
      'Reminders, sync, and device sharing always stay local-first.';

  @override
  String get timelineSettings => 'Timeline';

  @override
  String get timelineSettingsHint =>
      'Control whether confirmation is needed when merging adjacent entries.';

  @override
  String get mergeThreshold => 'Merge threshold';

  @override
  String minutesFormat(int count) {
    return '$count min';
  }

  @override
  String get reminderSettings => 'Reminders';

  @override
  String get reminderSettingsHint =>
      'Use gentle prompts to confirm long-running activities.';

  @override
  String get reminderInAppNotice =>
      'Reminders are in-app prompts; they are not guaranteed when the app is closed, suspended, or restricted in the background.';

  @override
  String get triggerTime => 'Trigger time';

  @override
  String get durationLabel => 'Duration';

  @override
  String get interval => 'Interval';

  @override
  String get method => 'Method';

  @override
  String get methodDialog => 'Dialog';

  @override
  String get methodBanner => 'Banner';

  @override
  String get methodSilent => 'Silent';

  @override
  String get supabaseConfigured => 'Supabase configured';

  @override
  String get supabaseNotConfigured => 'Supabase not configured';

  @override
  String get loggedIn => 'Signed in';

  @override
  String get notLoggedIn => 'Not signed in or local mode';

  @override
  String get cloudSync => 'Cloud sync';

  @override
  String get cloudSyncHint =>
      'App runs in local mode when Supabase is not configured.';

  @override
  String get syncStatus => 'Sync status';

  @override
  String syncTargetLabel(String target) {
    return 'Current target: $target';
  }

  @override
  String get syncTargetNone => 'None';

  @override
  String get syncTargetCloud => 'Cloud';

  @override
  String get syncTargetLan => 'LAN';

  @override
  String get syncTargetCloudLan => 'Cloud + LAN';

  @override
  String get lastSyncNever => 'Last success: never';

  @override
  String lastSyncAt(String time) {
    return 'Last success: $time';
  }

  @override
  String lastSyncError(String error) {
    return 'Last failure: $error';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get syncNow => 'Sync now';

  @override
  String get versionUpdate => 'Version update';

  @override
  String get versionUpdateHint =>
      'Check for a newer TimeTrack release and open the matching download page.';

  @override
  String get currentVersion => 'Current version';

  @override
  String get latestVersion => 'Latest version';

  @override
  String get versionUnknown => 'Unknown';

  @override
  String get updateStatusIdle => 'Not checked yet';

  @override
  String get updateStatusChecking => 'Checking for updates...';

  @override
  String get updateStatusUpToDate => 'You\'re up to date';

  @override
  String get updateStatusAvailable => 'Update available';

  @override
  String get updateStatusFailed => 'Update check failed';

  @override
  String updateErrorLabel(String error) {
    return 'Error: $error';
  }

  @override
  String get checkUpdates => 'Check updates';

  @override
  String get openDownloadPage => 'Open download page';

  @override
  String updateAvailablePrompt(String version) {
    return 'TimeTrack $version is available.';
  }

  @override
  String get viewInSettings => 'Settings';

  @override
  String get deviceInterop => 'Device sharing';

  @override
  String get deviceInteropHint =>
      'Share data via LAN on the same Wi-Fi or through file import/export.';

  @override
  String get interopSecurityNotice =>
      'Exported files are plain JSON. Use LAN sync only on trusted Wi-Fi; removing a pairing clears the host token saved on this device.';

  @override
  String get importFile => 'Import file';

  @override
  String get exportFile => 'Export file';

  @override
  String get lanHost => 'LAN host';

  @override
  String get lanHostWaiting =>
      'Waiting for devices on the same network to connect.';

  @override
  String get lanHostWindowsNote =>
      'v1 defaults: Windows as LAN host, Android as client connecting to PC.';

  @override
  String get lanHostAndroidNote =>
      'Enter the address and pairing code below on Android.';

  @override
  String get lanHostStartNote =>
      'Once started, other devices on the same Wi-Fi can pair.';

  @override
  String pairingCodeLabel(String code) {
    return 'Pairing code: $code';
  }

  @override
  String get windowsOnly => 'Windows only';

  @override
  String get stopHost => 'Stop host';

  @override
  String get startHost => 'Start host';

  @override
  String get connectLanHost => 'Connect to LAN host';

  @override
  String get connectLanHostHint =>
      'Enter address and pairing code to sync immediately.';

  @override
  String pairedWith(String name) {
    return 'Paired: $name';
  }

  @override
  String get removePairing => 'Remove pairing';

  @override
  String get hostAddress => 'Host address';

  @override
  String get hostHint => '192.168.1.10:8787';

  @override
  String get pairingCodeInput => 'Pairing code';

  @override
  String get pairAndSync => 'Pair & sync';

  @override
  String get multiDeviceSync => 'Multi-device sync';

  @override
  String get multiDeviceSyncHint =>
      'Local records always available. Sign in to sync to the cloud.';

  @override
  String get emailLabel => 'Email';

  @override
  String get sending => 'Sending';

  @override
  String get sendCode => 'Send code';

  @override
  String get emailCode => 'Verification code';

  @override
  String get verifying => 'Verifying';

  @override
  String get verifyLogin => 'Verify & sign in';

  @override
  String sendFailed(String error) {
    return 'Send failed: $error';
  }

  @override
  String verifyFailed(String error) {
    return 'Verification failed: $error';
  }

  @override
  String get exported => 'Exported';

  @override
  String get imported => 'Imported';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get interopStatus => 'Interop status';

  @override
  String get failed => 'Failed';
}
