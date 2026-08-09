import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/app_state.dart';
import 'package:timetrack/core/app_version.dart';
import 'package:timetrack/core/result.dart';
import 'package:timetrack/data/activity_repository.dart';
import 'package:timetrack/data/app_update_service.dart';
import 'package:timetrack/data/device_id_store.dart';
import 'package:timetrack/data/file_interop_service.dart';
import 'package:timetrack/data/lan_sync.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/settings_repository.dart';
import 'package:timetrack/data/sync_peer_store.dart';
import 'package:timetrack/data/sync_service.dart';
import 'package:timetrack/data/sync_status_store.dart';
import 'package:timetrack/data/time_repository.dart';
import 'package:timetrack/domain/profile_settings.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/settings_page.dart';

void main() {
  group('SettingsPage version update card', () {
    testWidgets('renders update states on compact width without overflow', (
      tester,
    ) async {
      await _expectUpdateCardStates(tester, width: 390);
    });

    testWidgets('compact update section can return to settings sections', (
      tester,
    ) async {
      final state = _UpdateCardTestState(
        check: ({required currentVersion, required platform}) async {
          return AppSuccess(_updateInfo(currentVersion: currentVersion));
        },
      );
      addTearDown(state.dispose);
      await state.checkForUpdates();
      await _pumpSettingsPage(tester, state: state, width: 390);

      expect(find.text('Version update'), findsOneWidget);
      expect(find.text('Update available'), findsOneWidget);

      await tester.tap(find.byTooltip('Back to settings sections'));
      await tester.pumpAndSettle();

      expect(find.text('General'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('First Day of Week'), findsOneWidget);
      expect(find.text('Time Format'), findsOneWidget);
      expect(find.text('Backup & Export'), findsOneWidget);
      expect(find.text('Sync Mode'), findsOneWidget);
      expect(find.text('About TimeTrack'), findsOneWidget);
      expect(find.text('Activity categories'), findsNothing);

      await tester.tap(find.text('Sync Mode'));
      await tester.pumpAndSettle();

      expect(find.text('Cloud sync'), findsAtLeastNWidgets(1));
      expect(find.text('Sync status'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders desktop reference overview on expanded width', (
      tester,
    ) async {
      final state = _UpdateCardTestState(
        check: ({required currentVersion, required platform}) async {
          return const AppSuccess(null);
        },
      );
      addTearDown(state.dispose);
      state.currentAppVersion = '1.0.0';
      state.syncStatus = SyncStatus(
        lastSuccessfulSyncAt: DateTime(2024, 5, 15, 9, 30),
        lastTarget: SyncTarget.cloud,
      );

      await _pumpSettingsPage(tester, state: state, width: 920);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Backup & Export'), findsOneWidget);
      expect(find.text('Sync'), findsOneWidget);
      expect(find.text('Sync Mode'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('About TimeTrack'), findsOneWidget);
      expect(find.text('TimeTrack Desktop'), findsNothing);
      expect(find.text('Made with'), findsNothing);

      await tester.tap(find.text('Sync Mode'));
      await tester.pumpAndSettle();

      expect(find.text('Cloud sync'), findsAtLeastNWidgets(1));
      expect(find.text('Sync status'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop overview rows open matching detail sections', (
      tester,
    ) async {
      await _expectDesktopOverviewRowOpens(
        tester,
        rowText: 'Appearance',
        expectedDetails: [
          'Appearance',
          'The current mobile theme follows the light reference.',
        ],
      );
      await _expectDesktopOverviewRowOpens(
        tester,
        rowText: 'First Day of Week',
        expectedDetails: ['Timeline', 'Merge threshold'],
      );
      await _expectDesktopOverviewRowOpens(
        tester,
        rowText: 'Quick Reminder',
        expectedDetails: ['Reminders', 'Trigger time'],
      );
      await _expectDesktopOverviewRowOpens(
        tester,
        rowText: 'Export Data',
        expectedDetails: ['Device sharing', 'Import file / Export file'],
      );
      await _expectDesktopOverviewRowOpens(
        tester,
        rowText: 'Sync Mode',
        expectedDetails: ['Cloud sync', 'Sync status'],
      );
      await _expectDesktopOverviewRowOpens(
        tester,
        rowText: 'About TimeTrack',
        expectedDetails: ['Version update', 'Current version'],
      );
    });

    testWidgets('desktop overview quick reminder opens reminder settings',
        (tester) async {
      final state = _UpdateCardTestState(
        check: ({required currentVersion, required platform}) async {
          return const AppSuccess(null);
        },
      );
      addTearDown(state.dispose);

      await _pumpSettingsPage(tester, state: state, width: 920);

      await tester.tap(find.text('Quick Reminder'));
      await tester.pumpAndSettle();

      expect(find.text('Reminders'), findsAtLeastNWidgets(1));
      expect(find.text('Method'), findsOneWidget);
      expect(find.byType(SegmentedButton<ReminderMethod>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop export row opens transfer actions', (
      tester,
    ) async {
      final state = _UpdateCardTestState(
        check: ({required currentVersion, required platform}) async {
          return const AppSuccess(null);
        },
      );
      addTearDown(state.dispose);

      await _pumpSettingsPage(tester, state: state, width: 920);
      await tester.tap(find.text('Export Data').first);
      await tester.pumpAndSettle();

      expect(find.text('Device sharing'), findsAtLeastNWidgets(1));
      expect(find.widgetWithText(FilledButton, 'Import file'), findsOneWidget);
      expect(
          find.widgetWithText(OutlinedButton, 'Export file'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop overview localizes labels in Chinese without overflow',
        (tester) async {
      final state = _UpdateCardTestState(
        check: ({required currentVersion, required platform}) async {
          return const AppSuccess(null);
        },
      );
      addTearDown(state.dispose);

      await _pumpSettingsPage(
        tester,
        state: state,
        width: 920,
        locale: const Locale('zh'),
      );

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('通用'), findsOneWidget);
      expect(find.text('备份与导出'), findsOneWidget);
      expect(find.text('同步'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
      expect(find.text('快速提醒'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders update states on expanded width without overflow', (
      tester,
    ) async {
      await _expectUpdateCardStates(tester, width: 920);
    });
  });
}

Future<void> _expectUpdateCardStates(
  WidgetTester tester, {
  required double width,
}) async {
  final checkingCompleter = Completer<AppResult<AppUpdateInfo?>>();
  final checkingState = _UpdateCardTestState(
    check: ({required currentVersion, required platform}) {
      return checkingCompleter.future;
    },
  );
  addTearDown(checkingState.dispose);
  await _pumpSettingsPage(tester, state: checkingState, width: width);

  final checkingFuture = checkingState.checkForUpdates();
  await tester.pump();

  expect(find.text('Version update'), _expandedTitleMatcher(width));
  expect(find.text('Checking for updates...'), findsOneWidget);
  expect(tester.widget<FilledButton>(find.byType(FilledButton).last).enabled,
      isFalse);
  expect(tester.takeException(), isNull);

  checkingCompleter.complete(AppSuccess(_updateInfo()));
  await checkingFuture;
  await tester.pump();

  final upToDateState = _UpdateCardTestState(
    check: ({required currentVersion, required platform}) async {
      return const AppSuccess(null);
    },
  );
  addTearDown(upToDateState.dispose);
  await upToDateState.checkForUpdates();
  await _pumpSettingsPage(tester, state: upToDateState, width: width);

  expect(find.text('Version update'), _expandedTitleMatcher(width));
  expect(find.text("You're up to date"), findsOneWidget);
  expect(find.text('Current version'), findsOneWidget);
  expect(find.text('0.1.0-pre'), findsOneWidget);
  expect(tester.takeException(), isNull);

  final availableState = _UpdateCardTestState(
    check: ({required currentVersion, required platform}) async {
      return AppSuccess(_updateInfo(currentVersion: currentVersion));
    },
  );
  addTearDown(availableState.dispose);
  await availableState.checkForUpdates();
  await _pumpSettingsPage(tester, state: availableState, width: width);

  expect(find.text('Update available'), findsOneWidget);
  expect(find.text('Latest version'), findsOneWidget);
  expect(find.text('0.2.0-pre'), findsOneWidget);
  expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton).last).enabled,
      isTrue);
  expect(tester.takeException(), isNull);

  final failedState = _UpdateCardTestState(
    check: ({required currentVersion, required platform}) async {
      return const AppFailure('HTTP 500');
    },
  );
  addTearDown(failedState.dispose);
  await failedState.checkForUpdates();
  await _pumpSettingsPage(tester, state: failedState, width: width);

  expect(find.text('Error: HTTP 500'), findsOneWidget);
  expect(find.text('Latest version'), findsNothing);
  expect(tester.takeException(), isNull);
}

Matcher _expandedTitleMatcher(double width) {
  return width >= 840 ? findsAtLeastNWidgets(1) : findsOneWidget;
}

Future<void> _expectDesktopOverviewRowOpens(
  WidgetTester tester, {
  required String rowText,
  required List<String> expectedDetails,
}) async {
  final state = _UpdateCardTestState(
    check: ({required currentVersion, required platform}) async {
      return const AppSuccess(null);
    },
  );
  addTearDown(state.dispose);
  state.currentAppVersion = '1.0.0';

  await _pumpSettingsPage(tester, state: state, width: 920);
  await tester.tap(find.text(rowText).first);
  await tester.pumpAndSettle();

  for (final text in expectedDetails) {
    expect(find.text(text), findsAtLeastNWidgets(1));
  }
  if (find.byType(AlertDialog).evaluate().isNotEmpty) {
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
  }
  expect(tester.takeException(), isNull);
}

Future<void> _pumpSettingsPage(
  WidgetTester tester, {
  required AppState state,
  required double width,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 1200,
          child: SettingsPage(
            key: ValueKey(state),
            state: state,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

AppUpdateInfo _updateInfo({AppVersion? currentVersion}) {
  return AppUpdateInfo(
    currentVersion: currentVersion ?? AppVersion.parse('0.1.0-pre'),
    latestVersion: AppVersion.parse('0.2.0-pre'),
    releaseName: 'TimeTrack 0.2.0-pre',
    releaseNotes: 'Release notes',
    pageUrl: Uri.parse('https://example.com/release'),
    downloadUrl: Uri.parse('https://example.com/app.exe'),
    isPrerelease: true,
  );
}

typedef _CheckHandler = Future<AppResult<AppUpdateInfo?>> Function({
  required AppVersion currentVersion,
  required TargetPlatform platform,
});

class _UpdateCardTestState extends AppState {
  _UpdateCardTestState({required _CheckHandler check})
      : _check = check,
        super(
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
            timeout: const Duration(milliseconds: 50),
          ),
          fileInteropService: FileInteropService(bundleStore: _repository),
        );

  final _CheckHandler _check;

  static final LocalDatabase _database = LocalDatabase();
  static final ActivityRepository _activityRepository =
      ActivityRepository(database: _database);
  static final SettingsRepository _settingsRepository =
      SettingsRepository(database: _database);
  static final DeviceIdStore _deviceIdStore =
      DeviceIdStore(database: _database);
  static final TimeEntryRepository _timeEntryRepository = TimeEntryRepository(
    database: _database,
    activityRepository: _activityRepository,
  );
  static final ActionLogRepository _actionLogRepository =
      ActionLogRepository(database: _database);
  static final TimeRepository _repository = TimeRepository(
    database: _database,
    activityRepository: _activityRepository,
    settingsRepository: _settingsRepository,
    deviceIdStore: _deviceIdStore,
    timeEntryRepository: _timeEntryRepository,
    actionLogRepository: _actionLogRepository,
  );
  static final SyncPeerStore _peerStore = SyncPeerStore(database: _database);

  @override
  Future<void> checkForUpdates({bool silent = false}) async {
    updateStatus = AppUpdateStatus.checking;
    updateErrorMessage = null;
    currentAppVersion = '0.1.0-pre';
    if (!silent) {
      notifyListeners();
    }
    final currentVersion = AppVersion.parse(currentAppVersion);
    final result = await _check(
      currentVersion: currentVersion,
      platform: TargetPlatform.windows,
    );
    result.when(
      onSuccess: (update) {
        availableUpdate = update;
        updateStatus = update == null
            ? AppUpdateStatus.upToDate
            : AppUpdateStatus.available;
        updateErrorMessage = null;
      },
      onFailure: (message) {
        availableUpdate = null;
        updateStatus = AppUpdateStatus.failed;
        updateErrorMessage = message;
      },
    );
    notifyListeners();
  }

  @override
  Future<void> openUpdateDownload() async {
    updateErrorMessage = null;
    notifyListeners();
  }

  @override
  Future<void> updateReminderSettings({
    int? reminderMinutes,
    int? reminderIntervalMinutes,
    ReminderMethod? reminderMethod,
    int? reminderTimeOfDayMinutes,
    int? mergeNeighborThresholdMinutes,
  }) async {
    settings = settings.copyWith(
      reminderMinutes: reminderMinutes,
      reminderIntervalMinutes: reminderIntervalMinutes,
      reminderMethod: reminderMethod,
      reminderTimeOfDayMinutes: reminderTimeOfDayMinutes,
      mergeNeighborThresholdMinutes: mergeNeighborThresholdMinutes,
      updatedAt: DateTime(2024, 5, 15, 9, 30),
    );
    notifyListeners();
  }
}
