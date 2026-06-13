import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';
import 'time_repository.dart';

class SyncService {
  SyncService({
    required TimeRepository repository,
    required SupabaseClient? client,
  })  : _repository = repository,
        _client = client;

  final TimeRepository _repository;
  final SupabaseClient? _client;

  bool get isEnabled => _client != null;

  User? get currentUser => _client?.auth.currentUser;

  Future<void> sendMagicLink(String email) async {
    final client = _requireClient();
    await client.auth.signInWithOtp(email: email.trim());
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final client = _requireClient();
    await client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  Future<void> sync({DateTime? since}) async {
    final client = _requireClient();
    final user = client.auth.currentUser;
    if (user == null) {
      return;
    }
    final floor = since ?? DateTime.fromMillisecondsSinceEpoch(0);

    final localActivities = await _repository.activitiesSince(floor);
    for (final activity in localActivities) {
      await client.from('activities').upsert(activity.toRemoteMap(user.id));
    }

    final localEntries = await _repository.entriesSince(floor);
    for (final entry in localEntries) {
      await client.from('time_entries').upsert(entry.toRemoteMap(user.id));
    }

    final localActionLogs = await _repository.actionLogsSince(floor);
    for (final log in localActionLogs) {
      await client.from('action_logs').upsert(log.toRemoteMap(user.id));
    }

    final settings = await _repository.settings();
    await client.from('profiles').upsert(settings.toRemoteMap(user.id));

    final remoteActivityRows = await client
        .from('activities')
        .select()
        .eq('user_id', user.id)
        .gte('updated_at', floor.toUtc().toIso8601String());
    for (final row in remoteActivityRows) {
      await _repository.replaceActivityIfRemoteNewer(Activity.fromMap(row));
    }

    final remoteEntryRows = await client
        .from('time_entries')
        .select()
        .eq('user_id', user.id)
        .gte('updated_at', floor.toUtc().toIso8601String());
    for (final row in remoteEntryRows) {
      await _repository.replaceEntryIfRemoteNewer(TimeEntry.fromMap(row));
    }

    final remoteActionLogRows = await client
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
  }

  Future<ProfileSettings?> fetchRemoteSettings() async {
    final client = _requireClient();
    final user = client.auth.currentUser;
    if (user == null) {
      return null;
    }
    final rows = await client
        .from('profiles')
        .select()
        .eq('user_id', user.id)
        .limit(1);
    if (rows.isEmpty) {
      return null;
    }
    return ProfileSettings.fromMap(rows.first);
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    return client;
  }
}
