import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timetrack/app/app_state.dart';
import 'package:timetrack/data/file_interop_service.dart';
import 'package:timetrack/data/lan_sync.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/sync_peer_store.dart';
import 'package:timetrack/data/sync_service.dart';
import 'package:timetrack/data/time_repository.dart';
import 'package:timetrack/domain/profile_settings.dart';
import 'package:timetrack/domain/stats_period.dart';

class _StateFixture {
  const _StateFixture({
    required this.state,
    required this.repository,
  });

  final AppState state;
  final TimeRepository repository;
}

Future<_StateFixture> _buildState() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await LocalDatabase.createSchema(db);
  final database = LocalDatabase(database: db);
  final repository = TimeRepository(database: database);
  final peerStore = SyncPeerStore(database: database);
  await repository.ensureSeedData();
  final state = AppState(
    repository: repository,
    syncService: SyncService(repository: repository, client: null),
    lanSyncServer: LanSyncServer(
      repository: repository,
      peerStore: peerStore,
      portCandidates: const [0],
    ),
    lanSyncClient: LanSyncClient(
      repository: repository,
      peerStore: peerStore,
    ),
    fileInteropService: FileInteropService(repository: repository),
  );
  await state.refresh();
  return _StateFixture(state: state, repository: repository);
}

void main() {
  test('reminder interval controls repeated reminder cadence', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(state.dispose);
    final activity = state.activities.first;
    final startedAt = DateTime(2026, 1, 1, 9);

    await state.switchTo(activity);
    state.runningEntry = state.runningEntry?.copyWith(startAt: startedAt);
    state.settings = state.settings.copyWith(
      reminderMinutes: 30,
      reminderIntervalMinutes: 15,
      reminderMethod: ReminderMethod.dialog,
    );
    state.now = DateTime(2026, 1, 1, 9, 30);

    expect(state.shouldShowReminder, isTrue);

    state.lastReminderAt = DateTime(2026, 1, 1, 9, 20);
    expect(state.shouldShowReminder, isFalse);

    state.lastReminderAt = DateTime(2026, 1, 1, 9, 15);
    expect(state.shouldShowReminder, isTrue);
  });

  test('todayTotals clips cross-day entries to the selected day', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(state.dispose);
    final activity = state.activities.first;

    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 23, 30),
      endAt: DateTime(2026, 1, 2, 0, 30),
      note: 'cross day',
    );
    await state.selectDay(DateTime(2026, 1, 2));

    expect(
      state.todayTotals()[activity.id],
      const Duration(minutes: 30),
    );
  });

  test('weekTotals clips entries to each day before summing', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(state.dispose);
    final activity = state.activities.first;

    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 4, 23, 30),
      endAt: DateTime(2026, 1, 5, 0, 30),
      note: 'cross week',
    );
    await state.selectDay(DateTime(2026, 1, 5));

    expect(
      (await state.weekTotals())[activity.id],
      const Duration(minutes: 30),
    );
  });

  test('totalsForPeriod day matches todayTotals', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(state.dispose);
    final activity = state.activities.first;

    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 2, 9),
      endAt: DateTime(2026, 1, 2, 10),
      note: 'morning',
    );
    await state.selectDay(DateTime(2026, 1, 2));

    final dayTotals = await state.totalsForPeriod(StatsPeriod.day);
    expect(dayTotals[activity.id], const Duration(hours: 1));
    expect(dayTotals, state.todayTotals());
  });

  test('totalsForPeriod week includes all 7 days', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(state.dispose);
    final activity = state.activities.first;

    // Monday 9-10
    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2025, 12, 29, 9),
      endAt: DateTime(2025, 12, 29, 10),
      note: 'mon',
    );
    // Friday 9-10
    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 2, 9),
      endAt: DateTime(2026, 1, 2, 10),
      note: 'fri',
    );
    // Select Friday Jan 2 2026 (week = Dec 29 - Jan 4)
    await state.selectDay(DateTime(2026, 1, 2));

    final weekTotals = await state.totalsForPeriod(StatsPeriod.week);
    expect(weekTotals[activity.id], const Duration(hours: 2));
  });

  test('totalsForPeriod month clips cross-month entry', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(state.dispose);
    final activity = state.activities.first;

    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 31, 23, 0),
      endAt: DateTime(2026, 2, 1, 1, 0),
      note: 'cross month',
    );
    await state.selectDay(DateTime(2026, 1, 15));

    final monthTotals = await state.totalsForPeriod(StatsPeriod.month);
    // In January window: Jan 31 23:00 to Feb 1 00:00 = 1 hour
    expect(monthTotals[activity.id], const Duration(hours: 1));
  });

  test('totalsForPeriod year aggregates full year', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(state.dispose);
    final activity = state.activities.first;

    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 3, 1, 9),
      endAt: DateTime(2026, 3, 1, 10),
      note: 'march',
    );
    await state.selectDay(DateTime(2026, 6, 1));

    final yearTotals = await state.totalsForPeriod(StatsPeriod.year);
    expect(yearTotals[activity.id], const Duration(hours: 1));
  });

  test('totalsForPeriod all includes all non-deleted entries', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(state.dispose);
    final activity = state.activities.first;

    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2025, 1, 1, 9),
      endAt: DateTime(2025, 1, 1, 10),
      note: 'old',
    );
    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2027, 1, 1, 9),
      endAt: DateTime(2027, 1, 1, 10),
      note: 'future',
    );

    final allTotals = await state.totalsForPeriod(StatsPeriod.all);
    expect(allTotals[activity.id], const Duration(hours: 2));
  });

  test('totalsForPeriod uses state.now for running entry', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(state.dispose);
    final activity = state.activities.first;

    // Create a running entry 30 minutes ago via repository
    final startAt = state.now.subtract(const Duration(minutes: 30));
    await fixture.repository.switchToActivity(activity.id, at: startAt);
    await state.selectDay(state.now);

    final dayTotals = await state.totalsForPeriod(StatsPeriod.day);
    expect(
      dayTotals[activity.id]?.inMinutes ?? 0,
      greaterThanOrEqualTo(30),
    );
  });

  test('longestBlockForPeriod day finds longest clipped entry', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(state.dispose);
    final activity = state.activities.first;

    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 2, 9),
      endAt: DateTime(2026, 1, 2, 10),
      note: '1h',
    );
    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 23),
      endAt: DateTime(2026, 1, 2, 1),
      note: '2h cross',
    );
    await state.selectDay(DateTime(2026, 1, 2));

    final longest = await state.longestBlockForPeriod(StatsPeriod.day);
    // Entry 2: in window Jan 2 00:00 to Jan 2 01:00 = 1h (same as entry 1)
    expect(longest.inMinutes, 60);
  });

  test('longestBlockForPeriod month finds longest in window', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(state.dispose);
    final activity = state.activities.first;

    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2025, 12, 31, 22),
      endAt: DateTime(2026, 1, 1, 2),
      note: '4h cross-month',
    );
    await state.selectDay(DateTime(2026, 1, 15));

    final longest = await state.longestBlockForPeriod(StatsPeriod.month);
    // In January window: Jan 1 00:00 to Jan 1 02:00 = 2 hours
    expect(longest.inMinutes, 120);
  });

  test('longestBlockForPeriod all uses full duration', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(state.dispose);
    final activity = state.activities.first;

    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 2, 9),
      note: '24h',
    );

    final longest = await state.longestBlockForPeriod(StatsPeriod.all);
    expect(longest.inHours, 24);
  });
}
