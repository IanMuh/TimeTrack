import '../core/model_utils.dart';

class ActivityCategory {
  const ActivityCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String id;
  final String? userId;
  final String name;
  final int color;
  final DateTime updatedAt;
  final bool isDeleted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  ActivityCategory copyWith({
    String? id,
    String? userId,
    String? name,
    int? color,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return ActivityCategory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      color: color ?? this.color,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, Object?> toLocalMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'color': color,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  Map<String, Object?> toRemoteMap(String remoteUserId) {
    return {
      'id': id,
      'user_id': remoteUserId,
      'name': name,
      'color': color,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  static ActivityCategory fromMap(Map<String, Object?> map) {
    try {
      return ActivityCategory(
        id: (map['id'] as String?) ??
            (throw const FormatException(
              'ActivityCategory.fromMap: id is required',
            )),
        userId: map['user_id'] as String?,
        name: (map['name'] as String?) ?? '',
        color: (map['color'] as num?)?.toInt() ?? 0xff0f766e,
        updatedAt: parseDateTime(map, 'updated_at'),
        isDeleted: readBool(map['is_deleted']),
      );
    } on TypeError catch (e) {
      throw FormatException('ActivityCategory.fromMap: invalid data type', e);
    }
  }
}

class ActivityCategoryLink {
  const ActivityCategoryLink({
    required this.id,
    required this.userId,
    required this.activityId,
    required this.categoryId,
    required this.isPrimary,
    required this.sortOrder,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String id;
  final String? userId;
  final String activityId;
  final String categoryId;
  final bool isPrimary;
  final int sortOrder;
  final DateTime updatedAt;
  final bool isDeleted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityCategoryLink &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  ActivityCategoryLink copyWith({
    String? id,
    String? userId,
    String? activityId,
    String? categoryId,
    bool? isPrimary,
    int? sortOrder,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return ActivityCategoryLink(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      activityId: activityId ?? this.activityId,
      categoryId: categoryId ?? this.categoryId,
      isPrimary: isPrimary ?? this.isPrimary,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, Object?> toLocalMap() {
    return {
      'id': id,
      'user_id': userId,
      'activity_id': activityId,
      'category_id': categoryId,
      'is_primary': isPrimary ? 1 : 0,
      'sort_order': sortOrder,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  Map<String, Object?> toRemoteMap(String remoteUserId) {
    return {
      'id': id,
      'user_id': remoteUserId,
      'activity_id': activityId,
      'category_id': categoryId,
      'is_primary': isPrimary,
      'sort_order': sortOrder,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  static ActivityCategoryLink fromMap(Map<String, Object?> map) {
    try {
      return ActivityCategoryLink(
        id: (map['id'] as String?) ??
            (throw const FormatException(
              'ActivityCategoryLink.fromMap: id is required',
            )),
        userId: map['user_id'] as String?,
        activityId: (map['activity_id'] as String?) ??
            (throw const FormatException(
              'ActivityCategoryLink.fromMap: activity_id is required',
            )),
        categoryId: (map['category_id'] as String?) ??
            (throw const FormatException(
              'ActivityCategoryLink.fromMap: category_id is required',
            )),
        isPrimary: readBool(map['is_primary']),
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        updatedAt: parseDateTime(map, 'updated_at'),
        isDeleted: readBool(map['is_deleted']),
      );
    } on TypeError catch (e) {
      throw FormatException(
        'ActivityCategoryLink.fromMap: invalid data type',
        e,
      );
    }
  }
}
