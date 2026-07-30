import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/app_state.dart';
import 'package:timetrack/core/app_version.dart';
import 'package:timetrack/data/activity_repository.dart';
import 'package:timetrack/data/app_update_service.dart';
import 'package:timetrack/data/device_id_store.dart';
import 'package:timetrack/data/file_interop_service.dart';
import 'package:timetrack/data/lan_sync.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/settings_repository.dart';
import 'package:timetrack/data/sync_peer_store.dart';
import 'package:timetrack/data/sync_service.dart';
import 'package:timetrack/data/time_repository.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/time_entry.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/app_shell.dart';

class ShellTestState extends AppState {
  ShellTestState()
      : super(
          repository: _repository,
          activityCatalog: _activityRepository,
          activityCommands: _activityRepository,
          entryQueries: _timeEntryRepository,
          entryCommands: _timeEntryRepository,
          syncService: SyncService(
            activityRepository: _activityRepository,
            settingsRepository: _settingsRepository,
            timeEntryRepository: _timeEntryRepository,
            actionLogRepository: _actionLogRepository,
            client: null,
          ),
          lanSyncServer: LanSyncServer(
            bundleStore: _repository,
            deviceIdStore: _deviceIdStore,
            peerStore: _peerStore,
            portCandidates: const [0],
          ),
          lanSyncClient: LanSyncClient(
            bundleStore: _repository,
            deviceIdStore: _deviceIdStore,
            peerStore: _peerStore,
          ),
          fileInteropService: FileInteropService(
            bundleStore: _repository,
          ),
        ) {
    isLoading = false;
    now = DateTime(2026, 1, 1, 12);
    selectedDay = DateTime(2026, 1, 1);
    activities = [
      Activity(
        id: 'work',
        userId: null,
        name: '工作',
        color: 0xff2563eb,
        isFavorite: true,
        updatedAt: now,
        isDeleted: false,
      ),
      Activity(
        id: 'unassigned',
        userId: null,
        name: '未安排',
        color: 0xff64748b,
        isFavorite: false,
        updatedAt: now,
        isDeleted: false,
        isUnassigned: true,
      ),
    ];
  }

  static final _database = LocalDatabase();
  static final _activityRepository = ActivityRepository(database: _database);
  static final _settingsRepository = SettingsRepository(database: _database);
  static final _deviceIdStore = DeviceIdStore(database: _database);
  static final _timeEntryRepository = TimeEntryRepository(
    database: _database,
    activityRepository: _activityRepository,
  );
  static final _actionLogRepository = ActionLogRepository(database: _database);
  static final _repository = TimeRepository(
    database: _database,
    activityRepository: _activityRepository,
    settingsRepository: _settingsRepository,
    deviceIdStore: _deviceIdStore,
    timeEntryRepository: _timeEntryRepository,
    actionLogRepository: _actionLogRepository,
  );
  static final _peerStore = SyncPeerStore(database: _database);

  var undoCount = 0;
  var redoCount = 0;
  var manualEntryDialogOpened = false;
  var updatePromptMarkCount = 0;
  bool _canUndo = false;
  bool _canRedo = false;
  String? _undoLabel;
  String? _redoLabel;

  void setHistory({
    required bool canUndo,
    required bool canRedo,
    String? undoLabel,
    String? redoLabel,
  }) {
    _canUndo = canUndo;
    _canRedo = canRedo;
    _undoLabel = undoLabel;
    _redoLabel = redoLabel;
    notifyListeners();
  }

  void showUpdatePrompt() {
    currentAppVersion = '0.1.0-pre';
    updateStatus = AppUpdateStatus.available;
    availableUpdate = AppUpdateInfo(
      currentVersion: AppVersion.parse('0.1.0-pre'),
      latestVersion: AppVersion.parse('0.2.0-pre'),
      releaseName: 'TimeTrack 0.2.0-pre',
      releaseNotes: 'Release notes',
      pageUrl: Uri.parse('https://example.com/release'),
      downloadUrl: Uri.parse('https://example.com/app.apk'),
      isPrerelease: true,
    );
    notifyListeners();
  }

  void startRunning({Duration elapsed = const Duration(minutes: 42)}) {
    clockNotifier.value = now;
    final entry = TimeEntry(
      id: 'running-entry',
      userId: null,
      activityId: 'work',
      activityNameSnapshot: '工作',
      activityColorSnapshot: 0xff2563eb,
      startAt: now.subtract(elapsed),
      endAt: null,
      note: '',
      deviceId: 'test-device',
      updatedAt: now,
      isDeleted: false,
    );
    runningEntry = entry;
    dayEntries = [entry];
    notifyListeners();
  }

  @override
  bool get canUndo => _canUndo;

  @override
  bool get canRedo => _canRedo;

  @override
  String? get undoLabel => _undoLabel;

  @override
  String? get redoLabel => _redoLabel;

  @override
  bool get canHostLan => false;

  @override
  bool get hasSyncTarget => false;

  @override
  bool get shouldShowReminderDialog => false;

  @override
  bool get shouldShowReminderBanner => false;

  @override
  bool get hasSuspiciousRunningEntry => false;

  @override
  void markUpdatePromptShown() {
    updatePromptMarkCount += 1;
    super.markUpdatePromptShown();
  }

  @override
  Future<void> undo() async {
    undoCount += 1;
    _canUndo = false;
    _canRedo = true;
    _redoLabel = _undoLabel;
    _undoLabel = null;
    notifyListeners();
  }

  @override
  Future<void> redo() async {
    redoCount += 1;
    _canUndo = true;
    _canRedo = false;
    _undoLabel = _redoLabel;
    _redoLabel = null;
    notifyListeners();
  }

  @override
  Future<void> selectDay(DateTime day) async {
    selectedDay = day;
    notifyListeners();
  }

  @override
  Future<List<Activity>> entryActivityChoices() async {
    return activities.where((activity) => !activity.isUnassigned).toList();
  }

  @override
  Future<List<Activity>> oneOffActivitySuggestions() async => const [];

  @override
  Future<List<TimeEntry>> overlaps(TimeEntry entry) async => const [];

  @override
  Future<void> createManualEntry({
    required String activityId,
    required DateTime startAt,
    required DateTime endAt,
    required String note,
  }) async {
    manualEntryDialogOpened = true;
    notifyListeners();
  }
}

Future<void> pumpShell(
  WidgetTester tester,
  ShellTestState state, {
  required double width,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppShell(state: state),
    ),
  );
  await tester.pump();
}

Future<void> pumpShortcutFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

Finder historyButton(String tooltipPrefix) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is IconButton &&
        (widget.tooltip?.startsWith(tooltipPrefix) ?? false),
  );
}
