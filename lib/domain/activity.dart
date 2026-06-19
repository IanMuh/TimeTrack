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
  });

  final String id;
  final String? userId;
  final String name;
  final int color;
  final bool isFavorite;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isUnassigned;

  Activity copyWith({
    String? id,
    String? userId,
    String? name,
    int? color,
    bool? isFavorite,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isUnassigned,
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
    };
  }

  static Activity fromMap(Map<String, Object?> map) {
    return Activity(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      name: map['name'] as String,
      color: (map['color'] as num).toInt(),
      isFavorite: _readBool(map['is_favorite']),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      isDeleted: _readBool(map['is_deleted']),
      isUnassigned: _readBool(map['is_unassigned']),
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
