import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';
import 'time_repository.dart';

abstract class SyncBackend {
  bool get isEnabled;

  Future<void> sync({DateTime? since});
}

class SyncService {
  SyncService({
    required TimeRepository repository,
    required SupabaseClient? client,
  }) : _cloudBackend = client == null
            ? null
            : SupabaseSyncBackend(repository: repository, client: client);

  final SupabaseSyncBackend? _cloudBackend;

  bool get isEnabled => _cloudBackend?.isEnabled ?? false;

  bool get isCloudEnabled => _cloudBackend != null;

  bool get isCloudSignedIn => currentUser != null;

  User? get currentUser => _cloudBackend?.currentUser;

  Future<void> sendMagicLink(String email) async {
    await _requireCloudBackend().sendMagicLink(email);
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    await _requireCloudBackend().verifyEmailOtp(
      email: email,
      token: token,
    );
  }

  Future<void> signOut() async {
    await _cloudBackend?.signOut();
  }

  Future<void> sync({DateTime? since}) async {
    await _requireCloudBackend().sync(since: since);
  }

  SupabaseSyncBackend _requireCloudBackend() {
    final backend = _cloudBackend;
    if (backend == null) {
      throw StateError('Supabase is not configured.');
    }
    return backend;
  }
}

class SupabaseSyncBackend implements SyncBackend {
  SupabaseSyncBackend({
    required TimeRepository repository,
    required SupabaseClient client,
  })  : _repository = repository,
        _client = client;

  final TimeRepository _repository;
  final SupabaseClient _client;

  @override
  bool get isEnabled => true;

  User? get currentUser => _client.auth.currentUser;

  Future<void> sendMagicLink(String email) async {
    await _client.auth.signInWithOtp(email: email.trim());
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    await _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> sync({DateTime? since}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }
    final floor = since ?? DateTime.fromMillisecondsSinceEpoch(0);

    final remoteActivityRows = await _client
        .from('activities')
        .select()
        .eq('user_id', user.id)
        .gte('updated_at', floor.toUtc().toIso8601String());
    for (final row in remoteActivityRows) {
      await _repository.replaceActivityIfRemoteNewer(Activity.fromMap(row));
    }

    final remoteEntryRows = await _client
        .from('time_entries')
        .select()
        .eq('user_id', user.id)
        .gte('updated_at', floor.toUtc().toIso8601String());
    for (final row in remoteEntryRows) {
      await _repository.replaceEntryIfRemoteNewer(TimeEntry.fromMap(row));
    }

    final remoteActionLogRows = await _client
        .from('action_logs')
        .select()
        .eq('user_id', user.id)
        .gte('updated_at', floor.toUtc().toIso8601String());
    for (final row in remoteActionLogRows) {
      await _repository.replaceActionLogIfRemoteNewer(ActionLog.fromMap(row));
    }

    final fetchedSettings = await fetchRemoteSettings();
    if (fetchedSettings != null) {
      await _repository.replaceSettingsIfRemoteNewer(fetchedSettings);
    }

    final localActivities = await _repository.activitiesSince(floor);
    for (final activity in localActivities) {
      await _uploadIfNotStale(
        table: 'activities',
        idColumn: 'id',
        id: activity.id,
        userId: user.id,
        updatedAt: activity.updatedAt,
        values: activity.toRemoteMap(user.id),
      );
    }

    final localEntries = await _repository.entriesSince(floor);
    for (final entry in localEntries) {
      await _uploadIfNotStale(
        table: 'time_entries',
        idColumn: 'id',
        id: entry.id,
        userId: user.id,
        updatedAt: entry.updatedAt,
        values: entry.toRemoteMap(user.id),
      );
    }

    final localActionLogs = await _repository.actionLogsSince(floor);
    for (final log in localActionLogs) {
      await _uploadIfNotStale(
        table: 'action_logs',
        idColumn: 'id',
        id: log.id,
        userId: user.id,
        updatedAt: log.updatedAt,
        values: log.toRemoteMap(user.id),
      );
    }

    final settings = await _repository.settings();
    await _uploadIfNotStale(
      table: 'profiles',
      idColumn: 'user_id',
      id: user.id,
      userId: user.id,
      updatedAt: settings.updatedAt,
      values: settings.toRemoteMap(user.id),
    );
  }

  Future<ProfileSettings?> fetchRemoteSettings() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    final rows =
        await _client.from('profiles').select().eq('user_id', user.id).limit(1);
    if (rows.isEmpty) {
      return null;
    }
    return ProfileSettings.fromMap(rows.first);
  }

  Future<void> _uploadIfNotStale({
    required String table,
    required String idColumn,
    required String id,
    required String userId,
    required DateTime updatedAt,
    required Map<String, Object?> values,
  }) async {
    final updatedAtIso = updatedAt.toUtc().toIso8601String();
    final rows = await _client
        .from(table)
        .select('updated_at')
        .eq(idColumn, id)
        .eq('user_id', userId)
        .limit(1);

    if (rows.isEmpty) {
      try {
        await _client.from(table).insert(values);
        return;
      } on PostgrestException catch (error) {
        if (error.code != '23505') {
          rethrow;
        }
      }
    }

    await _client
        .from(table)
        .update(values)
        .eq(idColumn, id)
        .eq('user_id', userId)
        .lte('updated_at', updatedAtIso);
  }
}
