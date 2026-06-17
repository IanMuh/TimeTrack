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
  });

  final String id;
  final String? userId;
  final String activityId;
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
    final clippedEnd = effectiveEnd.isBefore(windowEnd) ? effectiveEnd : windowEnd;
    if (!clippedStart.isBefore(clippedEnd)) {
      return Duration.zero;
    }
    return clippedEnd.difference(clippedStart);
  }

  bool overlaps(TimeEntry other) {
    final thisEnd =
        endAt ?? DateTime.fromMillisecondsSinceEpoch(8640000000000000);
    final otherEnd =
        other.endAt ?? DateTime.fromMillisecondsSinceEpoch(8640000000000000);
    return startAt.isBefore(otherEnd) && other.startAt.isBefore(thisEnd);
  }

  TimeEntry copyWith({
    String? id,
    String? userId,
    String? activityId,
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
      'start_at': startAt.toUtc().toIso8601String(),
      'end_at': endAt?.toUtc().toIso8601String(),
      'note': note,
      'device_id': deviceId,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  static TimeEntry fromMap(Map<String, Object?> map) {
    return TimeEntry(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      activityId: map['activity_id'] as String,
      startAt: DateTime.parse(map['start_at'] as String).toLocal(),
      endAt: map['end_at'] == null
          ? null
          : DateTime.parse(map['end_at'] as String).toLocal(),
      note: (map['note'] as String?) ?? '',
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
