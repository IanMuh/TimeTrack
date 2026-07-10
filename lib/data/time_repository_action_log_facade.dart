part of 'time_repository.dart';

mixin TimeRepositoryActionLogFacade {
  RepositoryActionLogRepository get _actionLogFacade;

  Future<List<ActionLog>> actionLogsForDay(DateTime day) async {
    return _actionLogFacade.actionLogsForDay(day);
  }

  Future<List<ActionLog>> actionLogsForRange(
    DateTime start,
    DateTime end,
  ) async {
    return _actionLogFacade.actionLogsForRange(start, end);
  }

  Future<List<ActionLog>> actionLogsSince(DateTime since) async {
    return _actionLogFacade.actionLogsSince(since);
  }

  Future<List<ActionLog>> allActionLogs() async {
    return _actionLogFacade.allActionLogs();
  }

  Future<void> addActionLog({
    required ActionType actionType,
    required String? activityId,
    required String? entryId,
    required DateTime occurredAt,
    required String message,
  }) async {
    await _actionLogFacade.addActionLog(
      actionType: actionType,
      activityId: activityId,
      entryId: entryId,
      occurredAt: occurredAt,
      message: message,
    );
  }

  Future<void> replaceActionLogIfRemoteNewer(ActionLog remote) async {
    await _actionLogFacade.replaceActionLogIfRemoteNewer(remote);
  }
}
