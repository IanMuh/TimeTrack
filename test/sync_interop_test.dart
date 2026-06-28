import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/data/lan_sync.dart';
import 'package:timetrack/data/sync_bundle.dart';
import 'package:timetrack/data/sync_peer_store.dart';
import 'package:timetrack/data/time_repository.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/activity_category.dart';
import 'package:timetrack/domain/profile_settings.dart';
import 'package:timetrack/domain/time_entry.dart';
import 'test_fixtures.dart';

Future<TestRepositoryFixture> buildSyncRepo([String? deviceId]) async {
  final fixture = await buildTestRepositoryFixture(
    seedData: false,
    deviceId: deviceId,
  );
  addTearDown(fixture.close);
  return fixture;
}

void main() {
  test('exported bundle imports into an empty repository', () async {
    final source = await buildSyncRepo('source');
    await source.repository.ensureSeedData();
    final activity = (await source.repository.activities()).first;
    final entry = await source.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 10),
      note: 'synced',
    );
    await source.repository.updateReminderMinutesForTest(90);

    final target = await buildSyncRepo('target');
    await target.repository.mergeBundle(await source.repository.exportBundle());

    expect(
      (await target.repository.activities()).map((item) => item.id),
      contains(activity.id),
    );
    expect(
      (await target.repository.entriesForDay(DateTime(2026, 1, 1)))
          .map((item) => item.id),
      contains(entry.id),
    );
    expect((await target.repository.settings()).reminderMinutes, 90);
  });

  test('bundle preserves one-off flags entry snapshots and merge threshold',
      () async {
    final source = await buildSyncRepo('source');
    await source.repository.ensureSeedData();
    final activity = await source.repository.createActivity(
      name: '一次性协助',
      color: 0xffdb2777,
      isOneOff: true,
    );
    final entry = await source.repository.createManualEntry(
      activityId: activity.id,
      startAt: DateTime(2026, 1, 1, 9),
      endAt: DateTime(2026, 1, 1, 10),
      note: 'snapshot',
    );
    await source.repository.saveSettings(
      ProfileSettings.defaults().copyWith(
        mergeNeighborThresholdMinutes: 8,
        updatedAt: DateTime(2026, 1, 2),
      ),
    );

    final target = await buildSyncRepo('target');
    await target.repository.mergeBundle(await source.repository.exportBundle());

    final importedActivity = (await target.repository.activities(
      includeDeleted: true,
    ))
        .singleWhere((item) => item.id == activity.id);
    final importedEntry = (await target.repository.allEntries())
        .singleWhere((item) => item.id == entry.id);
    final settings = await target.repository.settings();

    expect(importedActivity.isOneOff, isTrue);
    expect(importedEntry.activityNameSnapshot, '一次性协助');
    expect(importedEntry.activityColorSnapshot, 0xffdb2777);
    expect(settings.mergeNeighborThresholdMinutes, 8);
  });

  test('bundle preserves activity categories and primary tag links', () async {
    final source = await buildSyncRepo('source');
    final activity = await source.repository.createActivity(
      name: '深度工作',
      color: 0xff2563eb,
    );
    final work = await source.repository.createCategory(
      name: '工作',
      color: 0xff0f766e,
    );
    final focus = await source.repository.createCategory(
      name: '专注',
      color: 0xff7c3aed,
    );
    await source.repository.setActivityCategories(
      activityId: activity.id,
      primaryCategoryId: work.id,
      secondaryCategoryIds: [focus.id],
    );

    final target = await buildSyncRepo('target');
    await target.repository.mergeBundle(await source.repository.exportBundle());

    final categories = await target.repository.categories();
    final links = await target.repository.activityCategoryLinks();

    expect(categories.map((item) => item.name), containsAll(['工作', '专注']));
    expect(
      links,
      containsAll(<Matcher>[
        isA<ActivityCategoryLink>()
            .having((link) => link.activityId, 'activityId', activity.id)
            .having((link) => link.categoryId, 'categoryId', work.id)
            .having((link) => link.isPrimary, 'isPrimary', isTrue),
        isA<ActivityCategoryLink>()
            .having((link) => link.activityId, 'activityId', activity.id)
            .having((link) => link.categoryId, 'categoryId', focus.id)
            .having((link) => link.isPrimary, 'isPrimary', isFalse),
      ]),
    );
  });

  test('v1 bundles decode with empty category collections', () {
    final decoded = const SyncBundleCodec().fromJson({
      'schema_version': 1,
      'exported_at': DateTime(2026, 1, 1).toIso8601String(),
      'source_device_id': 'legacy',
      'activities': const [],
      'time_entries': const [],
      'action_logs': const [],
      'profile_settings': {
        'id': 1,
        'user_id': null,
        'reminder_minutes': 45,
        'timezone': 'UTC',
        'updated_at': DateTime(2026, 1, 1).toIso8601String(),
      },
    });

    expect(decoded.categories, isEmpty);
    expect(decoded.categoryLinks, isEmpty);
  });

  test('newer records win and older records do not overwrite local data',
      () async {
    final target = await buildSyncRepo('target');
    final older = DateTime(2026, 1, 1);
    final newer = DateTime(2026, 1, 2);

    await target.repository.upsertActivity(
      Activity(
        id: 'activity-1',
        userId: null,
        name: 'newer local',
        color: 0xff000001,
        isFavorite: true,
        updatedAt: newer,
        isDeleted: false,
      ),
    );

    await target.repository.mergeBundle(
      SyncBundle(
        schemaVersion: SyncBundle.currentSchemaVersion,
        exportedAt: newer,
        sourceDeviceId: 'source',
        activities: [
          Activity(
            id: 'activity-1',
            userId: null,
            name: 'older remote',
            color: 0xff000002,
            isFavorite: true,
            updatedAt: older,
            isDeleted: false,
          ),
          Activity(
            id: 'activity-2',
            userId: null,
            name: 'new remote',
            color: 0xff000003,
            isFavorite: true,
            updatedAt: newer,
            isDeleted: false,
          ),
        ],
        timeEntries: const [],
        actionLogs: const [],
        profileSettings: ProfileSettings(
          userId: null,
          reminderMinutes: 60,
          reminderIntervalMinutes: 20,
          reminderMethod: ReminderMethod.banner,
          reminderTimeOfDayMinutes: 10 * 60,
          timezone: 'UTC',
          updatedAt: newer,
        ),
      ),
    );

    final activities = await target.repository.activities();
    expect(
      activities.firstWhere((item) => item.id == 'activity-1').name,
      'newer local',
    );
    expect(
      activities.firstWhere((item) => item.id == 'activity-2').name,
      'new remote',
    );
  });

  test('delete tombstones sync across repositories', () async {
    final target = await buildSyncRepo('target');
    final updatedAt = DateTime(2026, 1, 2);

    await target.repository.mergeBundle(
      SyncBundle(
        schemaVersion: SyncBundle.currentSchemaVersion,
        exportedAt: updatedAt,
        sourceDeviceId: 'source',
        activities: [
          Activity(
            id: 'activity-1',
            userId: null,
            name: 'deleted remote',
            color: 0xff000001,
            isFavorite: true,
            updatedAt: updatedAt,
            isDeleted: true,
          ),
        ],
        timeEntries: const [],
        actionLogs: const [],
        profileSettings: ProfileSettings(
          userId: null,
          reminderMinutes: 45,
          reminderIntervalMinutes: 10,
          reminderMethod: ReminderMethod.dialog,
          reminderTimeOfDayMinutes: 9 * 60,
          timezone: 'UTC',
          updatedAt: updatedAt,
        ),
      ),
    );

    final visibleActivities = await target.repository.activities();
    expect(
        visibleActivities.where((activity) => !activity.isUnassigned), isEmpty);
    expect(
      visibleActivities.singleWhere((activity) => activity.isUnassigned).name,
      '未安排',
    );

    final allActivities = await target.repository.activities(
      includeDeleted: true,
    );
    expect(allActivities.where((activity) => !activity.isUnassigned),
        hasLength(1));
    expect(
      allActivities
          .singleWhere((activity) => activity.id == 'activity-1')
          .isDeleted,
      isTrue,
    );
  });

  test('invalid bundle schema is rejected before mutating data', () async {
    final repository = (await buildSyncRepo('target')).repository;
    await repository.upsertActivity(
      Activity(
        id: 'activity-1',
        userId: null,
        name: 'keep me',
        color: 0xff000001,
        isFavorite: true,
        updatedAt: DateTime(2026, 1, 1),
        isDeleted: false,
      ),
    );

    expect(
      () => const SyncBundleCodec().fromJson({
        'schema_version': 999,
        'exported_at': DateTime(2026, 1, 1).toIso8601String(),
        'source_device_id': 'source',
        'activities': const [],
        'time_entries': const [],
        'action_logs': const [],
        'profile_settings': {
          'id': 1,
          'user_id': null,
          'reminder_minutes': 45,
          'timezone': 'UTC',
          'updated_at': DateTime(2026, 1, 1).toIso8601String(),
        },
      }),
      throwsFormatException,
    );
    expect((await repository.activities()).single.name, 'keep me');
  });

  test('generated device ids persist and are unique per repository', () async {
    final first = await buildSyncRepo();
    final second = await buildSyncRepo();

    final firstDeviceId = await first.repository.currentDeviceId();
    expect(await first.repository.currentDeviceId(), firstDeviceId);
    expect(await second.repository.currentDeviceId(), isNot(firstDeviceId));
  });

  test('lan client rejects public cleartext hosts before pairing', () async {
    final client = await buildSyncRepo('client');
    final peerStore = SyncPeerStore(database: client.database);
    final lanClient = LanSyncClient(
      repository: client.repository,
      deviceIdStore: client.deviceIdStore,
      peerStore: peerStore,
    );

    expect(
      () => lanClient.pair(baseUrl: 'http://example.com:8787', code: '123456'),
      throwsA(
        isA<LanSyncException>().having(
          (error) => error.toString(),
          'message',
          contains('私有局域网地址'),
        ),
      ),
    );
  });

  test('lan client and server pair and perform bidirectional sync', () async {
    final host = await buildSyncRepo('host');
    final client = await buildSyncRepo('client');
    await host.repository.ensureSeedData();
    await client.repository.ensureSeedData();

    final hostPeerStore = SyncPeerStore(database: host.database);
    final clientPeerStore = SyncPeerStore(database: client.database);
    final server = LanSyncServer(
      repository: host.repository,
      deviceIdStore: host.deviceIdStore,
      peerStore: hostPeerStore,
      portCandidates: const [0],
      bindAddress: InternetAddress.loopbackIPv4,
    );
    await server.start();
    addTearDown(server.stop);

    final lanClient = LanSyncClient(
      repository: client.repository,
      deviceIdStore: client.deviceIdStore,
      peerStore: clientPeerStore,
    );
    await lanClient.pair(
      baseUrl: 'http://127.0.0.1:${server.port}',
      code: server.pairingCode!,
    );

    final clientActivity = (await client.repository.activities()).first;
    final clientEntry = await client.repository.createManualEntry(
      activityId: clientActivity.id,
      startAt: DateTime(2026, 1, 3, 9),
      endAt: DateTime(2026, 1, 3, 10),
      note: 'from client',
    );
    await lanClient.syncNow();

    expect(
      (await host.repository.entriesForDay(DateTime(2026, 1, 3)))
          .map((item) => item.id),
      contains(clientEntry.id),
    );

    final hostActivity = (await host.repository.activities()).first;
    final hostEntry = await host.repository.createManualEntry(
      activityId: hostActivity.id,
      startAt: DateTime(2026, 1, 4, 9),
      endAt: DateTime(2026, 1, 4, 10),
      note: 'from host',
    );
    await lanClient.syncNow();

    expect(
      (await client.repository.entriesForDay(DateTime(2026, 1, 4)))
          .map((item) => item.id),
      contains(hostEntry.id),
    );
  });

  test('multiple lan clients keep their pairings and sync without token loss',
      () async {
    final host = await buildSyncRepo();
    final firstClient = await buildSyncRepo();
    final secondClient = await buildSyncRepo();
    await host.repository.ensureSeedData();
    await firstClient.repository.ensureSeedData();
    await secondClient.repository.ensureSeedData();

    final server = LanSyncServer(
      repository: host.repository,
      deviceIdStore: host.deviceIdStore,
      peerStore: SyncPeerStore(database: host.database),
      portCandidates: const [0],
      bindAddress: InternetAddress.loopbackIPv4,
    );
    await server.start();
    addTearDown(server.stop);

    final firstLanClient = LanSyncClient(
      repository: firstClient.repository,
      deviceIdStore: firstClient.deviceIdStore,
      peerStore: SyncPeerStore(database: firstClient.database),
    );
    final secondLanClient = LanSyncClient(
      repository: secondClient.repository,
      deviceIdStore: secondClient.deviceIdStore,
      peerStore: SyncPeerStore(database: secondClient.database),
    );
    final baseUrl = 'http://127.0.0.1:${server.port}';
    await firstLanClient.pair(baseUrl: baseUrl, code: server.pairingCode!);
    await secondLanClient.pair(baseUrl: baseUrl, code: server.pairingCode!);

    final firstActivity = (await firstClient.repository.activities()).first;
    final firstEntry = await firstClient.repository.createManualEntry(
      activityId: firstActivity.id,
      startAt: DateTime(2026, 1, 5, 9),
      endAt: DateTime(2026, 1, 5, 10),
      note: 'from first client',
    );

    await firstLanClient.syncNow();

    expect(
      (await host.repository.entriesForDay(DateTime(2026, 1, 5)))
          .map((item) => item.id),
      contains(firstEntry.id),
    );
  });

  test('lan sync exchanges host and client changes in one sync', () async {
    final host = await buildSyncRepo('host');
    final client = await buildSyncRepo('client');
    await host.repository.ensureSeedData();
    await client.repository.ensureSeedData();

    final server = LanSyncServer(
      repository: host.repository,
      deviceIdStore: host.deviceIdStore,
      peerStore: SyncPeerStore(database: host.database),
      portCandidates: const [0],
      bindAddress: InternetAddress.loopbackIPv4,
    );
    await server.start();
    addTearDown(server.stop);

    final lanClient = LanSyncClient(
      repository: client.repository,
      deviceIdStore: client.deviceIdStore,
      peerStore: SyncPeerStore(database: client.database),
    );
    await lanClient.pair(
      baseUrl: 'http://127.0.0.1:${server.port}',
      code: server.pairingCode!,
    );

    final hostActivity = (await host.repository.activities()).first;
    final clientActivity = (await client.repository.activities()).first;
    final hostEntry = await host.repository.createManualEntry(
      activityId: hostActivity.id,
      startAt: DateTime(2026, 1, 6, 9),
      endAt: DateTime(2026, 1, 6, 10),
      note: 'from host before sync',
    );
    final clientEntry = await client.repository.createManualEntry(
      activityId: clientActivity.id,
      startAt: DateTime(2026, 1, 6, 11),
      endAt: DateTime(2026, 1, 6, 12),
      note: 'from client before sync',
    );

    await lanClient.syncNow();

    expect(
      (await host.repository.entriesForDay(DateTime(2026, 1, 6)))
          .map((item) => item.id),
      contains(clientEntry.id),
    );
    expect(
      (await client.repository.entriesForDay(DateTime(2026, 1, 6)))
          .map((item) => item.id),
      contains(hostEntry.id),
    );
  });

  test('multiple running entries normalize to the latest running entry',
      () async {
    final repository = (await buildSyncRepo('target')).repository;
    final activity = Activity(
      id: 'activity-1',
      userId: null,
      name: 'work',
      color: 0xff000001,
      isFavorite: true,
      updatedAt: DateTime(2026, 1, 1),
      isDeleted: false,
    );
    await repository.upsertActivity(activity);

    await repository.mergeBundle(
      SyncBundle(
        schemaVersion: SyncBundle.currentSchemaVersion,
        exportedAt: DateTime(2026, 1, 2),
        sourceDeviceId: 'source',
        activities: [activity],
        timeEntries: [
          TimeEntry(
            id: 'old-running',
            userId: null,
            activityId: activity.id,
            startAt: DateTime(2026, 1, 1, 9),
            endAt: null,
            note: '',
            deviceId: 'source',
            updatedAt: DateTime(2026, 1, 1, 9),
            isDeleted: false,
          ),
          TimeEntry(
            id: 'new-running',
            userId: null,
            activityId: activity.id,
            startAt: DateTime(2026, 1, 1, 10),
            endAt: null,
            note: '',
            deviceId: 'source',
            updatedAt: DateTime(2026, 1, 1, 10),
            isDeleted: false,
          ),
        ],
        actionLogs: const [],
        profileSettings: ProfileSettings(
          userId: null,
          reminderMinutes: 45,
          reminderIntervalMinutes: 10,
          reminderMethod: ReminderMethod.dialog,
          reminderTimeOfDayMinutes: 9 * 60,
          timezone: 'UTC',
          updatedAt: DateTime(2026, 1, 1),
        ),
      ),
    );

    expect((await repository.runningEntry())?.id, 'new-running');
    final oldEntry = (await repository.allEntries())
        .firstWhere((entry) => entry.id == 'old-running');
    expect(oldEntry.endAt, DateTime(2026, 1, 1, 10));
  });
}

extension on TimeRepository {
  Future<void> updateReminderMinutesForTest(int minutes) async {
    final current = await settings();
    await saveSettings(
      current.copyWith(
        reminderMinutes: minutes,
        updatedAt: DateTime.now(),
      ),
    );
  }
}
