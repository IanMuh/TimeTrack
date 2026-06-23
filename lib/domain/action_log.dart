import '../core/model_utils.dart';

enum ActionType {
  switch_('switch'),
  stop('stop'),
  edit('edit'),
  delete('delete'),
  undo('undo'),
  redo('redo'),
  merge('merge'),
  manual('manual'),
  split('split'),
  activityDelete('activityDelete');

  const ActionType(this.storageValue);

  final String storageValue;

  static ActionType fromStorageValue(Object? value) {
    final text = value as String?;
    return ActionType.values.firstWhere(
      (t) => t.storageValue == text,
      orElse: () => ActionType.switch_,
    );
  }
}

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
  final ActionType actionType;
  final String? activityId;
  final String? entryId;
  final String message;
  final DateTime occurredAt;
  final String deviceId;
  final DateTime updatedAt;
  final bool isDeleted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionLog && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ActionLog(id: $id, actionType: $actionType, activityId: $activityId, occurredAt: $occurredAt, isDeleted: $isDeleted)';

  ActionLog copyWith({
    String? id,
    String? userId,
    ActionType? actionType,
    String? activityId,
    String? entryId,
    String? message,
    DateTime? occurredAt,
    String? deviceId,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return ActionLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      actionType: actionType ?? this.actionType,
      activityId: activityId ?? this.activityId,
      entryId: entryId ?? this.entryId,
      message: message ?? this.message,
      occurredAt: occurredAt ?? this.occurredAt,
      deviceId: deviceId ?? this.deviceId,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, Object?> toLocalMap() {
    return {
      'id': id,
      'user_id': userId,
      'action_type': actionType.storageValue,
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
      'action_type': actionType.storageValue,
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
    try {
      return ActionLog(
        id: (map['id'] as String?) ??
            (throw const FormatException('ActionLog.fromMap: id is required')),
        userId: map['user_id'] as String?,
        actionType: ActionType.fromStorageValue(map['action_type']),
        activityId: map['activity_id'] as String?,
        entryId: map['entry_id'] as String?,
        message: (map['message'] as String?) ?? '',
        occurredAt: parseDateTime(map, 'occurred_at'),
        deviceId: (map['device_id'] as String?) ?? 'unknown',
        updatedAt: parseDateTime(map, 'updated_at'),
        isDeleted: readBool(map['is_deleted']),
      );
    } on TypeError catch (e) {
      throw FormatException('ActionLog.fromMap: invalid data type', e);
    }
  }
}
