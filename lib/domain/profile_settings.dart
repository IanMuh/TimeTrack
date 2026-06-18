enum ReminderMethod {
  dialog('dialog'),
  banner('banner'),
  silent('silent');

  const ReminderMethod(this.storageValue);

  final String storageValue;

  static ReminderMethod fromStorageValue(Object? value) {
    final text = value as String?;
    return ReminderMethod.values.firstWhere(
      (method) => method.storageValue == text,
      orElse: () => ReminderMethod.dialog,
    );
  }
}

class ProfileSettings {
  const ProfileSettings({
    required this.userId,
    required this.reminderMinutes,
    required this.reminderIntervalMinutes,
    required this.reminderMethod,
    required this.reminderTimeOfDayMinutes,
    required this.timezone,
    required this.updatedAt,
  });

  final String? userId;
  final int reminderMinutes;
  final int reminderIntervalMinutes;
  final ReminderMethod reminderMethod;
  final int reminderTimeOfDayMinutes;
  final String timezone;
  final DateTime updatedAt;

  static ProfileSettings defaults() {
    return ProfileSettings(
      userId: null,
      reminderMinutes: 45,
      reminderIntervalMinutes: 10,
      reminderMethod: ReminderMethod.dialog,
      reminderTimeOfDayMinutes: 9 * 60,
      timezone: DateTime.now().timeZoneName,
      updatedAt: DateTime.now(),
    );
  }

  ProfileSettings copyWith({
    String? userId,
    int? reminderMinutes,
    int? reminderIntervalMinutes,
    ReminderMethod? reminderMethod,
    int? reminderTimeOfDayMinutes,
    String? timezone,
    DateTime? updatedAt,
  }) {
    return ProfileSettings(
      userId: userId ?? this.userId,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      reminderIntervalMinutes:
          reminderIntervalMinutes ?? this.reminderIntervalMinutes,
      reminderMethod: reminderMethod ?? this.reminderMethod,
      reminderTimeOfDayMinutes:
          reminderTimeOfDayMinutes ?? this.reminderTimeOfDayMinutes,
      timezone: timezone ?? this.timezone,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toLocalMap() {
    return {
      'id': 1,
      'user_id': userId,
      'reminder_minutes': reminderMinutes,
      'reminder_interval_minutes': reminderIntervalMinutes,
      'reminder_method': reminderMethod.storageValue,
      'reminder_time_of_day_minutes': reminderTimeOfDayMinutes,
      'timezone': timezone,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> toRemoteMap(String remoteUserId) {
    return {
      'user_id': remoteUserId,
      'reminder_minutes': reminderMinutes,
      'reminder_interval_minutes': reminderIntervalMinutes,
      'reminder_method': reminderMethod.storageValue,
      'reminder_time_of_day_minutes': reminderTimeOfDayMinutes,
      'timezone': timezone,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static ProfileSettings fromMap(Map<String, Object?> map) {
    return ProfileSettings(
      userId: map['user_id'] as String?,
      reminderMinutes: (map['reminder_minutes'] as num).toInt(),
      reminderIntervalMinutes:
          ((map['reminder_interval_minutes'] as num?) ?? 10).toInt(),
      reminderMethod: ReminderMethod.fromStorageValue(map['reminder_method']),
      reminderTimeOfDayMinutes:
          ((map['reminder_time_of_day_minutes'] as num?) ?? 9 * 60).toInt(),
      timezone: map['timezone'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }
}
