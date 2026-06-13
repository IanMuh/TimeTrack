class ProfileSettings {
  const ProfileSettings({
    required this.userId,
    required this.reminderMinutes,
    required this.timezone,
    required this.updatedAt,
  });

  final String? userId;
  final int reminderMinutes;
  final String timezone;
  final DateTime updatedAt;

  static ProfileSettings defaults() {
    return ProfileSettings(
      userId: null,
      reminderMinutes: 45,
      timezone: DateTime.now().timeZoneName,
      updatedAt: DateTime.now(),
    );
  }

  ProfileSettings copyWith({
    String? userId,
    int? reminderMinutes,
    String? timezone,
    DateTime? updatedAt,
  }) {
    return ProfileSettings(
      userId: userId ?? this.userId,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      timezone: timezone ?? this.timezone,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toLocalMap() {
    return {
      'id': 1,
      'user_id': userId,
      'reminder_minutes': reminderMinutes,
      'timezone': timezone,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> toRemoteMap(String remoteUserId) {
    return {
      'user_id': remoteUserId,
      'reminder_minutes': reminderMinutes,
      'timezone': timezone,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static ProfileSettings fromMap(Map<String, Object?> map) {
    return ProfileSettings(
      userId: map['user_id'] as String?,
      reminderMinutes: (map['reminder_minutes'] as num).toInt(),
      timezone: map['timezone'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }
}
