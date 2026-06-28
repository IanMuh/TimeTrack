import 'dart:convert';

import '../domain/action_log.dart';
import '../domain/activity.dart';
import '../domain/activity_category.dart';
import '../domain/profile_settings.dart';
import '../domain/time_entry.dart';

class SyncBundle {
  const SyncBundle({
    required this.schemaVersion,
    required this.exportedAt,
    required this.sourceDeviceId,
    required this.activities,
    this.categories = const [],
    this.categoryLinks = const [],
    required this.timeEntries,
    required this.actionLogs,
    required this.profileSettings,
  });

  static const currentSchemaVersion = 2;

  final int schemaVersion;
  final DateTime exportedAt;
  final String sourceDeviceId;
  final List<Activity> activities;
  final List<ActivityCategory> categories;
  final List<ActivityCategoryLink> categoryLinks;
  final List<TimeEntry> timeEntries;
  final List<ActionLog> actionLogs;
  final ProfileSettings profileSettings;

  Map<String, Object?> toJson() {
    return {
      'schema_version': schemaVersion,
      'exported_at': exportedAt.toUtc().toIso8601String(),
      'source_device_id': sourceDeviceId,
      'activities': [
        for (final activity in activities) activity.toLocalMap(),
      ],
      'categories': [
        for (final category in categories) category.toLocalMap(),
      ],
      'category_links': [
        for (final link in categoryLinks) link.toLocalMap(),
      ],
      'time_entries': [
        for (final entry in timeEntries) entry.toLocalMap(),
      ],
      'action_logs': [
        for (final log in actionLogs) log.toLocalMap(),
      ],
      'profile_settings': profileSettings.toLocalMap(),
    };
  }
}

class SyncBundleCodec {
  const SyncBundleCodec();

  String encode(SyncBundle bundle) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(bundle.toJson());
  }

  SyncBundle decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('TimeTrack sync file must be a JSON object.');
    }
    return fromJson(decoded);
  }

  SyncBundle fromJson(Map<String, Object?> json) {
    final schemaVersion = _requiredInt(json, 'schema_version');
    if (schemaVersion < 1 || schemaVersion > SyncBundle.currentSchemaVersion) {
      throw FormatException(
        'Unsupported TimeTrack sync schema version: $schemaVersion.',
      );
    }

    return SyncBundle(
      schemaVersion: schemaVersion,
      exportedAt: DateTime.parse(_requiredString(json, 'exported_at')),
      sourceDeviceId: _requiredString(json, 'source_device_id'),
      activities: [
        for (final item in _requiredList(json, 'activities'))
          Activity.fromMap(_requiredMap(item, 'activities item')),
      ],
      categories: [
        for (final item in _optionalList(json, 'categories'))
          ActivityCategory.fromMap(_requiredMap(item, 'categories item')),
      ],
      categoryLinks: [
        for (final item in _optionalList(json, 'category_links'))
          ActivityCategoryLink.fromMap(
            _requiredMap(item, 'category_links item'),
          ),
      ],
      timeEntries: [
        for (final item in _requiredList(json, 'time_entries'))
          TimeEntry.fromMap(_requiredMap(item, 'time_entries item')),
      ],
      actionLogs: [
        for (final item in _requiredList(json, 'action_logs'))
          ActionLog.fromMap(_requiredMap(item, 'action_logs item')),
      ],
      profileSettings: ProfileSettings.fromMap(
        _requiredMap(json['profile_settings'], 'profile_settings'),
      ),
    );
  }

  int _requiredInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    throw FormatException('Missing or invalid integer field: $key.');
  }

  String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FormatException('Missing or invalid string field: $key.');
  }

  List<Object?> _requiredList(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is List<Object?>) {
      return value;
    }
    if (value is List) {
      return value.cast<Object?>();
    }
    throw FormatException('Missing or invalid list field: $key.');
  }

  List<Object?> _optionalList(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) {
      return const [];
    }
    if (value is List<Object?>) {
      return value;
    }
    if (value is List) {
      return value.cast<Object?>();
    }
    throw FormatException('Invalid list field: $key.');
  }

  Map<String, Object?> _requiredMap(Object? value, String label) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, Object?>();
    }
    throw FormatException('Missing or invalid object field: $label.');
  }
}
