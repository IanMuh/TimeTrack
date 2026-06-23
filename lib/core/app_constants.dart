class AppConstants {
  AppConstants._();

  static const defaultActivityColor = 0xff64748b;

  /// Sentinel for open-ended entries (no endAt). 2100 is far enough for any
  /// practical record but still within Dart's DateTime range.
  static final farFutureDate = DateTime(2100);

  /// The maximum DateTime value representable in Dart. Used as an infinity
  /// sentinel in overlap calculations.
  static final maxDateTime =
      DateTime.fromMillisecondsSinceEpoch(8640000000000000);

  /// Any single running entry longer than this is considered suspicious.
  static const suspiciousEntryHours = 12;

  /// Default values for newly created profile settings.
  static const defaultReminderMinutes = 45;
  static const defaultReminderIntervalMinutes = 10;
  static const defaultReminderTimeOfDayMinutes = 540; // 9 * 60
  static const defaultMergeNeighborThresholdMinutes = 1;

  /// Default TCP port for LAN sync.
  static const lanDefaultPort = 8787;
}
