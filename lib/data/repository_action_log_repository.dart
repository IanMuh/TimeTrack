import '../core/result.dart';
import '../domain/action_log.dart';
import 'action_log_repository.dart';
import 'repository_result.dart';

class RepositoryActionLogRepository {
  RepositoryActionLogRepository({
    required ActionLogRepository actionLogRepository,
  }) : _logRepo = actionLogRepository;

  final ActionLogRepository _logRepo;

  Future<List<ActionLog>> actionLogsForDay(DateTime day) async {
    final result = await _logRepo.actionLogsForDay(day);
    return _unwrap(result);
  }

  Future<List<ActionLog>> actionLogsForRange(
    DateTime start,
    DateTime end,
  ) async {
    final result = await _logRepo.actionLogsForRange(start, end);
    return _unwrap(result);
  }

  Future<List<ActionLog>> actionLogsSince(DateTime since) async {
    final result = await _logRepo.actionLogsSince(since);
    return _unwrap(result);
  }

  Future<List<ActionLog>> allActionLogs() async {
    final result = await _logRepo.allActionLogs();
    return _unwrap(result);
  }

  Future<void> addActionLog({
    required ActionType actionType,
    required String? activityId,
    required String? entryId,
    required DateTime occurredAt,
    required String message,
  }) async {
    final result = await _logRepo.addActionLog(
      actionType: actionType,
      activityId: activityId,
      entryId: entryId,
      occurredAt: occurredAt,
      message: message,
    );
    _unwrap(result);
  }

  Future<void> replaceActionLogIfRemoteNewer(ActionLog remote) async {
    final result = await _logRepo.replaceActionLogIfRemoteNewer(remote);
    _unwrap(result);
  }

  T _unwrap<T>(AppResult<T> result) {
    return unwrapRepositoryResult(result);
  }
}
