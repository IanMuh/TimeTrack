import '../core/app_constants.dart';
import '../core/model_utils.dart';

class Activity {
  const Activity({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.isFavorite,
    required this.updatedAt,
    required this.isDeleted,
    this.isUnassigned = false,
    this.isOneOff = false,
  });

  final String id;
  final String? userId;
  final String name;
  final int color;
  final bool isFavorite;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isUnassigned;
  final bool isOneOff;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Activity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Activity(id: $id, name: $name, color: $color, isFavorite: $isFavorite, isDeleted: $isDeleted)';

  Activity copyWith({
    String? id,
    String? userId,
    String? name,
    int? color,
    bool? isFavorite,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isUnassigned,
    bool? isOneOff,
  }) {
    return Activity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      color: color ?? this.color,
      isFavorite: isFavorite ?? this.isFavorite,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isUnassigned: isUnassigned ?? this.isUnassigned,
      isOneOff: isOneOff ?? this.isOneOff,
    );
  }

  Map<String, Object?> toLocalMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'color': color,
      'is_favorite': isFavorite ? 1 : 0,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'is_unassigned': isUnassigned ? 1 : 0,
      'is_one_off': isOneOff ? 1 : 0,
    };
  }

  Map<String, Object?> toRemoteMap(String remoteUserId) {
    return {
      'id': id,
      'user_id': remoteUserId,
      'name': name,
      'color': color,
      'is_favorite': isFavorite,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
      'is_unassigned': isUnassigned,
      'is_one_off': isOneOff,
    };
  }

  static Activity fromMap(Map<String, Object?> map) {
    try {
      return Activity(
        id: (map['id'] as String?) ??
            (throw const FormatException('Activity.fromMap: id is required')),
        userId: map['user_id'] as String?,
        name: (map['name'] as String?) ?? '',
        color: (map['color'] as num?)?.toInt() ??
            AppConstants.defaultActivityColor,
        isFavorite: readBool(map['is_favorite']),
        updatedAt: parseDateTime(map, 'updated_at'),
        isDeleted: readBool(map['is_deleted']),
        isUnassigned: readBool(map['is_unassigned']),
        isOneOff: readBool(map['is_one_off']),
      );
    } on TypeError catch (e) {
      throw FormatException('Activity.fromMap: invalid data type', e);
    }
  }
}
