import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/data/sync_peer_store.dart';
import 'package:timetrack/domain/profile_settings.dart';
import 'package:timetrack/domain/stats_period.dart';
import 'test_fixtures.dart';

Future<TestAppFixture> _buildState() => buildTestAppFixture();

void main() {
  test('sync failure records an error without advancing last success',
      () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(fixture.dispose);
    final successAt = DateTime.utc(2026, 6, 24, 8, 30);
    state.syncStatus = await fixture.syncStatusStore.markSuccess(
      at: successAt,
      target: 'lan',
    );
    state.lanPeer = SyncPeer(
      id: 'missing-host',
      kind: SyncPeerKind.lanClient,
      displayName: 'Missing Host',
      baseUrl: 'http://127.0.0.1:9',
      token: 'token',
      updatedAt: DateTime(2026, 6, 24),
    );

    await state.sync();

    expect(state.syncStatus.lastSuccessfulSyncAt?.toUtc(), successAt);
    expect(state.syncStatus.lastError, contains('同步部分失败'));
    expect(state.syncStatus.lastTarget, 'lan');
  });

  test('successful lan sync records last success and clears old error',
      () async {
    final host = await _buildState();
    final client = await _buildState();
    addTearDown(host.dispose);
    addTearDown(client.dispose);
    final previousSuccess = DateTime.utc(2020, 1, 1);
    client.state.syncStatus = await client.syncStatusStore.markFailure(
      error: 'old failure',
      target: 'lan',
    );
    client.state.syncStatus = await client.syncStatusStore.markSuccess(
      at: previousSuccess,
      target: 'lan',
    );
    client.state.syncStatus = await client.syncStatusStore.markFailure(
      error: 'old failure',
      target: 'lan',
    );

    await host.lanSyncServer.start();
    addTearDown(host.lanSyncServer.stop);
    await client.state.pairLanPeer(
      baseUrl: 'http://127.0.0.1:${host.state.lanSyncPortForTest}',
      code: host.state.lanPairingCode!,
    );

    expect(client.state.syncStatus.lastSuccessfulSyncAt, isNotNull);
    expect(
      client.state.syncStatus.lastSuccessfulSyncAt!.toUtc().isAfter(
            previousSuccess,
          ),
      isTrue,
    );
    expect(client.state.syncStatus.lastError, isNull);
    expect(client.state.syncStatus.lastTarget, 'lan');
  });

  test('reminder interval controls repeated reminder cadence', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(fixture.dispose);
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

  test('unassigned running entry is hidden from active status prompts',
      () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(fixture.dispose);
    final unassigned = state.activities.singleWhere(
      (activity) => activity.isUnassigned,
    );

    await state.switchTo(unassigned);
    state.runningEntry = state.runningEntry?.copyWith(
      startAt: DateTime(2026, 1, 1, 8),
    );
    state.now = DateTime(2026, 1, 1, 21);
    state.settings = state.settings.copyWith(reminderMinutes: 30);

    expect(state.runningActivity, isNull);
    expect(state.runningDuration(), Duration.zero);
    expect(state.shouldShowReminder, isFalse);
    expect(state.hasSuspiciousRunningEntry, isFalse);
  });

  test('todayTotals clips cross-day entries to the selected day', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(fixture.dispose);
    final activity = state.activities.firstWhere(
      (activity) => !activity.isUnassigned,
    );

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

  test('todayTotals assigns unrecorded time to unassigned activity', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(fixture.dispose);
    final activity = state.activities.firstWhere(
      (activity) => !activity.isUnassigned,
    );
    final unassigned = state.activities.singleWhere(
      (activity) => activity.isUnassigned,
    );
    state.now = DateTime(2026, 1, 2, 12);

    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 2, 9),
      endAt: DateTime(2026, 1, 2, 10),
      note: 'morning',
    );
    await state.selectDay(DateTime(2026, 1, 2));

    final totals = state.todayTotals();
    expect(totals[activity.id], const Duration(hours: 1));
    expect(totals[unassigned.id], const Duration(hours: 11));
  });

  test('visibleDayEntries collapses real unassigned records into one gap',
      () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(fixture.dispose);
    final unassigned = state.activities.singleWhere(
      (activity) => activity.isUnassigned,
    );
    state.now = DateTime(2026, 1, 2, 12);

    await fixture.repository.createManualEntry(
      activityId: unassigned.id,
      startAt: DateTime(2026, 1, 2, 9),
      endAt: DateTime(2026, 1, 2, 10),
      note: 'legacy unassigned',
    );
    await state.selectDay(DateTime(2026, 1, 2));

    final visibleEntries = state.visibleDayEntries();
    final totals = state.todayTotals();

    expect(visibleEntries, hasLength(1));
    expect(visibleEntries.single.activityId, unassigned.id);
    expect(visibleEntries.single.deviceId, 'unassigned-gap');
    expect(visibleEntries.single.startAt, DateTime(2026, 1, 2));
    expect(visibleEntries.single.endAt, DateTime(2026, 1, 2, 12));
    expect(totals[unassigned.id], const Duration(hours: 12));
  });

  test('weekTotals clips entries to each day before summing', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(fixture.dispose);
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
    addTearDown(fixture.dispose);
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
    addTearDown(fixture.dispose);
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
    addTearDown(fixture.dispose);
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
    addTearDown(fixture.dispose);
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
    addTearDown(fixture.dispose);
    final activity = state.activities.first;
    final unassigned = state.activities.singleWhere(
      (activity) => activity.isUnassigned,
    );

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
    await fixture.repository.createManualEntry(
      activityId: unassigned.id,
      startAt: DateTime(2026, 1, 1, 12),
      endAt: DateTime(2026, 1, 1, 14),
      note: 'legacy unassigned',
    );

    final allTotals = await state.totalsForPeriod(StatsPeriod.all);
    expect(allTotals[activity.id], const Duration(hours: 2));
    expect(allTotals.containsKey(unassigned.id), isFalse);
  });

  test('statsForRange counts only real entries across multi-day gaps',
      () async {
    final fixture = await buildTestAppFixture(
      now: DateTime(2026, 1, 3, 12),
      selectedDay: DateTime(2026, 1, 3),
    );
    final state = fixture.state;
    addTearDown(fixture.dispose);
    final activity = state.activities.firstWhere(
      (activity) => !activity.isUnassigned,
    );
    final unassigned = state.activities.singleWhere(
      (activity) => activity.isUnassigned,
    );

    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 10),
      note: 'one real entry',
    );

    final stats = await state.statsForRange(
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 1, 4),
    );

    expect(stats.totalDuration, const Duration(hours: 1));
    expect(stats.longestBlock, const Duration(hours: 1));
    expect(stats.totalsByActivity, hasLength(1));
    expect(stats.totalsByActivity[activity.id], const Duration(hours: 1));
    expect(stats.totalsByActivity.containsKey(unassigned.id), isFalse);
    expect(stats.totalsByDay, hasLength(1));
    expect(
      stats.totalsByDay[DateTime(2026, 1, 1)],
      const Duration(hours: 1),
    );
  });

  test('totalsForPeriod uses state.now for running entry', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(fixture.dispose);
    final activity = state.activities.first;
    state.now = DateTime(2026, 1, 2, 10);

    final startAt = DateTime(2026, 1, 2, 9, 30);
    await fixture.repository.switchToActivity(activity.id, at: startAt);
    await state.selectDay(state.now);

    final dayTotals = await state.totalsForPeriod(StatsPeriod.day);
    expect(
      dayTotals[activity.id]?.inMinutes ?? 0,
      30,
    );
  });

  test('longestBlockForPeriod day finds longest clipped entry', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(fixture.dispose);
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
    // Unassigned gaps now behave like regular activity blocks.
    expect(longest.inMinutes, 14 * 60);
  });

  test('longestBlockForPeriod month finds longest in window', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(fixture.dispose);
    final activity = state.activities.first;

    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2025, 12, 31, 22),
      endAt: DateTime(2026, 1, 1, 2),
      note: '4h cross-month',
    );
    await state.selectDay(DateTime(2026, 1, 15));

    final longest = await state.longestBlockForPeriod(StatsPeriod.month);
    // Unassigned gaps now behave like regular activity blocks.
    expect(longest.inMinutes, 30 * 24 * 60 + 22 * 60);
  });

  test('longestBlockForPeriod all uses day-local split duration', () async {
    final fixture = await _buildState();
    final state = fixture.state;
    addTearDown(fixture.dispose);
    final activity = state.activities.first;
    final unassigned = state.activities.singleWhere(
      (activity) => activity.isUnassigned,
    );

    await fixture.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 2, 9),
      note: '24h',
    );
    await fixture.repository.createManualEntry(
      activityId: unassigned.id,
      startAt: DateTime(2026, 1, 3, 9),
      endAt: DateTime(2026, 1, 5, 9),
      note: 'legacy unassigned',
    );

    final longest = await state.longestBlockForPeriod(StatsPeriod.all);
    expect(longest.inHours, 15);
  });
}
