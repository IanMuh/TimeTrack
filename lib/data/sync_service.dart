import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';
import 'repository_interfaces.dart';
import 'time_repository.dart';

// ---------------------------------------------------------------------------
// Top-level helpers (testable independently of SupabaseClient)
// ---------------------------------------------------------------------------

/// Pagination helper: fetches all rows using range-based pagination.
///
/// [pageSize] is the number of rows per page (default 1000 per requirement).
/// [fetchPage] is called repeatedly with (offset, limit) until an empty page
/// or a page smaller than pageSize is returned.
Future<List<Map<String, dynamic>>> fetchAllPaginated({
  required int pageSize,
  required Future<List<Map<String, dynamic>>> Function(int offset, int limit)
      fetchPage,
}) async {
  final allRows = <Map<String, dynamic>>[];
  var offset = 0;
  while (true) {
    final page = await fetchPage(offset, pageSize);
    if (page.isEmpty) break;
    allRows.addAll(page);
    if (page.length < pageSize) break;
    offset += pageSize;
  }
  return allRows;
}

/// Batch processing helper: splits [items] into chunks of at most
/// [maxBatchSize] and calls [processBatch] for each chunk.
Future<void> batchProcess({
  required List<Map<String, dynamic>> items,
  required int maxBatchSize,
  required Future<void> Function(List<Map<String, dynamic>> batch)
      processBatch,
}) async {
  if (items.isEmpty) return;
  for (var i = 0; i < items.length; i += maxBatchSize) {
    final end = (i + maxBatchSize > items.length)
        ? items.length
        : i + maxBatchSize;
    await processBatch(items.sublist(i, end));
  }
}

/// Retry helper with exponential backoff.
///
/// Retries [operation] up to [maxRetries] times (default 3) with delays of
/// baseDelay × 2^attempt (1s, 2s, 4s). Only retries on transient errors:
/// PostgrestException with 5xx codes, SocketException, TimeoutException,
/// and ClientException. All other errors are immediately rethrown.
Future<T> withRetry<T>({
  required Future<T> Function() operation,
  int maxRetries = 3,
  Duration baseDelay = const Duration(seconds: 1),
}) async {
  for (var attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (e) {
      if (attempt == maxRetries || !_isTransientError(e)) rethrow;
      final delay = baseDelay * (1 << attempt); // 1s, 2s, 4s
      await Future.delayed(delay);
    }
  }
  // unreachable — loop always throws or returns
  throw StateError('Unreachable');
}

bool _isTransientError(Object error) {
  if (error is PostgrestException) {
    final code = error.code;
    if (code != null) {
      final codeNum = int.tryParse(code);
      if (codeNum != null && codeNum >= 500 && codeNum < 600) return true;
    }
  }
  if (error is SocketException || error is TimeoutException) return true;
  // Catch HTTP-level errors from the underlying client (package:http throws
  // ClientException on socket/connection failures).
  if (error.runtimeType.toString() == 'ClientException') return true;
  return false;
}

abstract class SyncBackend {
  bool get isEnabled;

  Future<void> sync({DateTime? since});
}

class SyncService {
  SyncService({
    required TimeRepository repository,
    required IActivityRepository activityRepository,
    required ISettingsRepository settingsRepository,
    required ITimeEntryRepository timeEntryRepository,
    required IActionLogRepository actionLogRepository,
    required SupabaseClient? client,
  }) : _cloudBackend = client == null
            ? null
            : SupabaseSyncBackend(
                repository: repository,
                activityRepository: activityRepository,
                settingsRepository: settingsRepository,
                timeEntryRepository: timeEntryRepository,
                actionLogRepository: actionLogRepository,
                client: client,
              );

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
    required IActivityRepository activityRepository,
    required ISettingsRepository settingsRepository,
    required ITimeEntryRepository timeEntryRepository,
    required IActionLogRepository actionLogRepository,
    required SupabaseClient client,
  })  : _repository = repository,
        _activityRepository = activityRepository,
        _settingsRepository = settingsRepository,
        _timeEntryRepository = timeEntryRepository,
        _actionLogRepository = actionLogRepository,
        _client = client;

  // ignore: unused_field
  final TimeRepository _repository;
  final IActivityRepository _activityRepository;
  final ISettingsRepository _settingsRepository;
  final ITimeEntryRepository _timeEntryRepository;
  final IActionLogRepository _actionLogRepository;
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
    final floorIso = floor.toUtc().toIso8601String();

    // --- DOWNLOAD (paginated - pageSize=1000) ---
    final remoteActivityRows = await fetchAllPaginated(
      pageSize: 1000,
      fetchPage: (offset, limit) => _client
          .from('activities')
          .select()
          .eq('user_id', user.id)
          .gte('updated_at', floorIso)
          .range(offset, offset + limit - 1),
    );
    for (final row in remoteActivityRows) {
      final result = await _activityRepository
          .replaceActivityIfRemoteNewer(Activity.fromMap(row));
      result.fold(
        onSuccess: (_) {},
        onFailure: (msg) =>
            throw StateError('replaceActivityIfRemoteNewer failed: $msg'),
      );
    }

    final remoteEntryRows = await fetchAllPaginated(
      pageSize: 1000,
      fetchPage: (offset, limit) => _client
          .from('time_entries')
          .select()
          .eq('user_id', user.id)
          .gte('updated_at', floorIso)
          .range(offset, offset + limit - 1),
    );
    for (final row in remoteEntryRows) {
      final entryResult = await _timeEntryRepository
          .replaceEntryIfRemoteNewer(TimeEntry.fromMap(row));
      entryResult.fold(
        onSuccess: (_) {},
        onFailure: (msg) =>
            throw StateError('replaceEntryIfRemoteNewer failed: $msg'),
      );
    }

    final remoteActionLogRows = await fetchAllPaginated(
      pageSize: 1000,
      fetchPage: (offset, limit) => _client
          .from('action_logs')
          .select()
          .eq('user_id', user.id)
          .gte('updated_at', floorIso)
          .range(offset, offset + limit - 1),
    );
    for (final row in remoteActionLogRows) {
      final logResult = await _actionLogRepository
          .replaceActionLogIfRemoteNewer(ActionLog.fromMap(row));
      logResult.fold(
        onSuccess: (_) {},
        onFailure: (msg) =>
            throw StateError('replaceActionLogIfRemoteNewer failed: $msg'),
      );
    }

    final fetchedSettings = await fetchRemoteSettings();
    if (fetchedSettings != null) {
      final settingsResult =
          await _settingsRepository.replaceSettingsIfRemoteNewer(fetchedSettings);
      settingsResult.fold(
        onSuccess: (_) {},
        onFailure: (msg) =>
            throw StateError('replaceSettingsIfRemoteNewer failed: $msg'),
      );
    }

    // --- UPLOAD (batched with retry, max 100/batch) ---
    final localActivitiesResult =
        await _activityRepository.activitiesSince(floor);
    final localActivities = localActivitiesResult.fold(
      onSuccess: (list) => list,
      onFailure: (_) => <Activity>[],
    );
    if (localActivities.isNotEmpty) {
      await _batchUploadIfNotStale(
        table: 'activities',
        idColumn: 'id',
        userId: user.id,
        valuesList: localActivities
            .map((a) => a.toRemoteMap(user.id))
            .toList(),
      );
    }

    final localEntriesResult =
        await _timeEntryRepository.entriesSince(floor);
    final localEntries = localEntriesResult.fold(
      onSuccess: (list) => list,
      onFailure: (_) => <TimeEntry>[],
    );
    if (localEntries.isNotEmpty) {
      await _batchUploadIfNotStale(
        table: 'time_entries',
        idColumn: 'id',
        userId: user.id,
        valuesList:
            localEntries.map((e) => e.toRemoteMap(user.id)).toList(),
      );
    }

    final localActionLogsResult =
        await _actionLogRepository.actionLogsSince(floor);
    final localActionLogs = localActionLogsResult.fold(
      onSuccess: (list) => list,
      onFailure: (_) => <ActionLog>[],
    );
    if (localActionLogs.isNotEmpty) {
      await _batchUploadIfNotStale(
        table: 'action_logs',
        idColumn: 'id',
        userId: user.id,
        valuesList:
            localActionLogs.map((l) => l.toRemoteMap(user.id)).toList(),
      );
    }

    final settingsResult = await _settingsRepository.settings();
    final settings = settingsResult.fold(
      onSuccess: (value) => value,
      onFailure: (msg) =>
          throw StateError('Failed to load settings: $msg'),
    );
    await _batchUploadIfNotStale(
      table: 'profiles',
      idColumn: 'user_id',
      userId: user.id,
      valuesList: [settings.toRemoteMap(user.id)],
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

  // ---------------------------------------------------------------------------
  // Batch upload with last-write-wins + retry
  // ---------------------------------------------------------------------------

  /// Uploads [valuesList] in batches of at most 100, each batch wrapped
  /// with exponential-backoff retry. Only items whose local updated_at is
  /// not older than the remote row (or which do not exist remotely) are
  /// upserted — preserving last-write-wins semantics.
  Future<void> _batchUploadIfNotStale({
    required String table,
    required String idColumn,
    required String userId,
    required List<Map<String, Object?>> valuesList,
  }) async {
    if (valuesList.isEmpty) return;

    await batchProcess(
      items: valuesList,
      maxBatchSize: 100,
      processBatch: (batch) => withRetry(
        operation: () => _upsertBatchIfNewer(
          table: table,
          idColumn: idColumn,
          userId: userId,
          batch: batch,
        ),
      ),
    );
  }

  /// For a single batch: fetch remote timestamps, filter to only items whose
  /// local updated_at >= remote (or remote doesn't exist), then upsert.
  Future<void> _upsertBatchIfNewer({
    required String table,
    required String idColumn,
    required String userId,
    required List<Map<String, Object?>> batch,
  }) async {
    final ids = batch.map((v) => v[idColumn] as String).toList();

    // Fetch remote timestamps for all IDs in one query
    // Build an 'in' filter — e.g. "id.in.(a,b,c)"
    final inValue = '(${ids.join(',')})';
    final remoteRows = await _client
        .from(table)
        .select('$idColumn, updated_at')
        .eq('user_id', userId)
        .filter(idColumn, 'in', inValue);

    final remoteTimestamps = <String, DateTime>{};
    for (final row in remoteRows) {
      final rowId = row[idColumn] as String;
      remoteTimestamps[rowId] =
          DateTime.parse(row['updated_at'] as String);
    }

    // Keep only items where local >= remote (or remote absent)
    final toUpsert = batch.where((v) {
      final id = v[idColumn] as String;
      final localUpdatedAt = DateTime.parse(v['updated_at'] as String);
      final remoteUpdatedAt = remoteTimestamps[id];
      if (remoteUpdatedAt == null) return true; // new on remote
      return !localUpdatedAt.isBefore(remoteUpdatedAt);
    }).toList();

    if (toUpsert.isEmpty) return;

    await _client.from(table).upsert(toUpsert);
  }
}
