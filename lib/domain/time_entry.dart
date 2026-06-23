import '../core/app_constants.dart';
import '../core/model_utils.dart';

class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.userId,
    required this.activityId,
    required this.startAt,
    required this.endAt,
    required this.note,
    required this.deviceId,
    required this.updatedAt,
    required this.isDeleted,
    this.activityNameSnapshot = '',
    this.activityColorSnapshot,
  });

  final String id;
  final String? userId;
  final String activityId;
  final String activityNameSnapshot;
  final int? activityColorSnapshot;
  final DateTime startAt;
  final DateTime? endAt;
  final String note;
  final String deviceId;
  final DateTime updatedAt;
  final bool isDeleted;

  bool get isRunning => endAt == null;

  Duration durationUntil(DateTime now) {
    final effectiveEnd = endAt ?? now;
    if (effectiveEnd.isBefore(startAt)) {
      return Duration.zero;
    }
    return effectiveEnd.difference(startAt);
  }

  Duration durationInWindow({
    required DateTime windowStart,
    required DateTime windowEnd,
    required DateTime now,
  }) {
    if (!windowStart.isBefore(windowEnd)) {
      return Duration.zero;
    }
    final effectiveEnd = endAt ?? now;
    if (!startAt.isBefore(windowEnd) || !effectiveEnd.isAfter(windowStart)) {
      return Duration.zero;
    }
    final clippedStart = startAt.isAfter(windowStart) ? startAt : windowStart;
    final clippedEnd =
        effectiveEnd.isBefore(windowEnd) ? effectiveEnd : windowEnd;
    if (!clippedStart.isBefore(clippedEnd)) {
      return Duration.zero;
    }
    return clippedEnd.difference(clippedStart);
  }

  bool overlaps(TimeEntry other) {
    final thisEnd =
        endAt ?? AppConstants.maxDateTime;
    final otherEnd =
        other.endAt ?? AppConstants.maxDateTime;
    return startAt.isBefore(otherEnd) && other.startAt.isBefore(thisEnd);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TimeEntry(id: $id, activityId: $activityId, startAt: $startAt, endAt: $endAt, isDeleted: $isDeleted)';

  TimeEntry copyWith({
    String? id,
    String? userId,
    String? activityId,
    String? activityNameSnapshot,
    int? activityColorSnapshot,
    bool clearActivityColorSnapshot = false,
    DateTime? startAt,
    DateTime? endAt,
    bool clearEndAt = false,
    String? note,
    String? deviceId,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      activityId: activityId ?? this.activityId,
      activityNameSnapshot: activityNameSnapshot ?? this.activityNameSnapshot,
      activityColorSnapshot: clearActivityColorSnapshot
          ? null
          : activityColorSnapshot ?? this.activityColorSnapshot,
      startAt: startAt ?? this.startAt,
      endAt: clearEndAt ? null : endAt ?? this.endAt,
      note: note ?? this.note,
      deviceId: deviceId ?? this.deviceId,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, Object?> toLocalMap() {
    return {
      'id': id,
      'user_id': userId,
      'activity_id': activityId,
      'activity_name': activityNameSnapshot,
      'activity_color': activityColorSnapshot,
      'start_at': startAt.toUtc().toIso8601String(),
      'end_at': endAt?.toUtc().toIso8601String(),
      'note': note,
      'device_id': deviceId,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  Map<String, Object?> toRemoteMap(String remoteUserId) {
    return {
      'id': id,
      'user_id': remoteUserId,
      'activity_id': activityId,
      'activity_name': activityNameSnapshot,
      'activity_color': activityColorSnapshot,
      'start_at': startAt.toUtc().toIso8601String(),
      'end_at': endAt?.toUtc().toIso8601String(),
      'note': note,
      'device_id': deviceId,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  static TimeEntry fromMap(Map<String, Object?> map) {
    try {
      return TimeEntry(
        id: (map['id'] as String?) ??
            (throw const FormatException('TimeEntry.fromMap: id is required')),
        userId: map['user_id'] as String?,
        activityId: (map['activity_id'] as String?) ?? '',
        activityNameSnapshot: (map['activity_name'] as String?) ?? '',
        activityColorSnapshot: (map['activity_color'] as num?)?.toInt(),
        startAt: parseDateTime(map, 'start_at'),
        endAt: map['end_at'] == null
            ? null
            : parseDateTime(map, 'end_at'),
        note: (map['note'] as String?) ?? '',
        deviceId: (map['device_id'] as String?) ?? 'unknown',
        updatedAt: parseDateTime(map, 'updated_at'),
        isDeleted: readBool(map['is_deleted']),
      );
    } on TypeError catch (e) {
      throw FormatException('TimeEntry.fromMap: invalid data type', e);
    }
  }
}
