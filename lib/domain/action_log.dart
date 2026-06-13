class ActionLog {
  const ActionLog({
    required this.id,
    required this.userId,
    required this.actionType,
    required this.activityId,
    required this.entryId,
    required this.message,
    required this.occurredAt,
    required this.deviceId,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String id;
  final String? userId;
  final String actionType;
  final String? activityId;
  final String? entryId;
  final String message;
  final DateTime occurredAt;
  final String deviceId;
  final DateTime updatedAt;
  final bool isDeleted;

  Map<String, Object?> toLocalMap() {
    return {
      'id': id,
      'user_id': userId,
      'action_type': actionType,
      'activity_id': activityId,
      'entry_id': entryId,
      'message': message,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'device_id': deviceId,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  Map<String, Object?> toRemoteMap(String remoteUserId) {
    return {
      'id': id,
      'user_id': remoteUserId,
      'action_type': actionType,
      'activity_id': activityId,
      'entry_id': entryId,
      'message': message,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'device_id': deviceId,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  static ActionLog fromMap(Map<String, Object?> map) {
    return ActionLog(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      actionType: map['action_type'] as String,
      activityId: map['activity_id'] as String?,
      entryId: map['entry_id'] as String?,
      message: map['message'] as String,
      occurredAt: DateTime.parse(map['occurred_at'] as String).toLocal(),
      deviceId: (map['device_id'] as String?) ?? 'unknown',
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      isDeleted: _readBool(map['is_deleted']),
    );
  }

  static bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    return false;
  }
}
