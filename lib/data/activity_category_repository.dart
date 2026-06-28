import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/result.dart';
import '../domain/activity_category.dart';
import 'local_database.dart';
import 'repository_interfaces.dart';

class ActivityCategoryRepository implements IActivityCategoryRepository {
  ActivityCategoryRepository({
    required LocalDatabase database,
    Uuid? uuid,
  })  : _database = database,
        _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  @override
  Future<AppResult<List<ActivityCategory>>> categories({
    bool includeDeleted = false,
  }) async {
    try {
      final db = await _database.db;
      final rows = await db.query(
        'activity_categories',
        where: includeDeleted ? null : 'is_deleted = 0',
        orderBy: 'name asc',
      );
      return AppSuccess(rows.map(ActivityCategory.fromMap).toList());
    } catch (e) {
      return AppFailure('Failed to load activity categories: $e');
    }
  }

  @override
  Future<AppResult<ActivityCategory>> createCategory({
    required String name,
    required int color,
    String? userId,
  }) async {
    try {
      final category = ActivityCategory(
        id: _uuid.v4(),
        userId: userId,
        name: name.trim(),
        color: color,
        updatedAt: DateTime.now(),
        isDeleted: false,
      );
      await upsertCategory(category);
      return AppSuccess(category);
    } catch (e) {
      return AppFailure('Failed to create activity category: $e');
    }
  }

  @override
  Future<AppResult<ActivityCategory>> updateCategory({
    required ActivityCategory category,
    required String name,
    required int color,
  }) async {
    try {
      final updated = category.copyWith(
        name: name.trim(),
        color: color,
        updatedAt: DateTime.now(),
      );
      await upsertCategory(updated);
      return AppSuccess(updated);
    } catch (e) {
      return AppFailure('Failed to update activity category: $e');
    }
  }

  @override
  Future<AppResult<void>> deleteCategory(ActivityCategory category) async {
    try {
      final db = await _database.db;
      final updatedAt = DateTime.now();
      await db.transaction((txn) async {
        await txn.insert(
          'activity_categories',
          category.copyWith(isDeleted: true, updatedAt: updatedAt).toLocalMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        final rows = await txn.query(
          'activity_category_links',
          where: 'category_id = ? and is_deleted = 0',
          whereArgs: [category.id],
        );
        for (final row in rows) {
          final link = ActivityCategoryLink.fromMap(row);
          await txn.insert(
            'activity_category_links',
            link.copyWith(isDeleted: true, updatedAt: updatedAt).toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to delete activity category: $e');
    }
  }

  @override
  Future<AppResult<List<ActivityCategoryLink>>> activityCategoryLinks({
    bool includeDeleted = false,
  }) async {
    try {
      final db = await _database.db;
      final rows = await db.query(
        'activity_category_links',
        where: includeDeleted ? null : 'is_deleted = 0',
        orderBy: 'activity_id asc, is_primary desc, sort_order asc',
      );
      return AppSuccess(rows.map(ActivityCategoryLink.fromMap).toList());
    } catch (e) {
      return AppFailure('Failed to load activity category links: $e');
    }
  }

  @override
  Future<AppResult<List<ActivityCategoryLink>>> linksForActivity(
    String activityId, {
    bool includeDeleted = false,
  }) async {
    try {
      final db = await _database.db;
      final rows = await db.query(
        'activity_category_links',
        where: includeDeleted
            ? 'activity_id = ?'
            : 'activity_id = ? and is_deleted = 0',
        whereArgs: [activityId],
        orderBy: 'is_primary desc, sort_order asc',
      );
      return AppSuccess(rows.map(ActivityCategoryLink.fromMap).toList());
    } catch (e) {
      return AppFailure('Failed to load links for activity: $e');
    }
  }

  @override
  Future<AppResult<List<ActivityCategoryLink>>> setActivityCategories({
    required String activityId,
    required String? primaryCategoryId,
    required List<String> secondaryCategoryIds,
    String? userId,
  }) async {
    try {
      final db = await _database.db;
      final updatedAt = DateTime.now();
      final normalizedPrimary = _blankToNull(primaryCategoryId);
      final desired = <String, ({bool isPrimary, int sortOrder})>{};
      if (normalizedPrimary != null) {
        desired[normalizedPrimary] = (isPrimary: true, sortOrder: 0);
      }
      var order = 1;
      for (final categoryId in secondaryCategoryIds) {
        final normalized = _blankToNull(categoryId);
        if (normalized == null || normalized == normalizedPrimary) {
          continue;
        }
        desired.putIfAbsent(
          normalized,
          () => (isPrimary: false, sortOrder: order++),
        );
      }

      final saved = <ActivityCategoryLink>[];
      await db.transaction((txn) async {
        final rows = await txn.query(
          'activity_category_links',
          where: 'activity_id = ?',
          whereArgs: [activityId],
        );
        final existing = {
          for (final link in rows.map(ActivityCategoryLink.fromMap))
            link.categoryId: link,
        };
        for (final entry in desired.entries) {
          final old = existing[entry.key];
          final link = (old ??
                  ActivityCategoryLink(
                    id: _stableLinkId(activityId, entry.key),
                    userId: userId,
                    activityId: activityId,
                    categoryId: entry.key,
                    isPrimary: entry.value.isPrimary,
                    sortOrder: entry.value.sortOrder,
                    updatedAt: updatedAt,
                    isDeleted: false,
                  ))
              .copyWith(
            userId: userId ?? old?.userId,
            isPrimary: entry.value.isPrimary,
            sortOrder: entry.value.sortOrder,
            updatedAt: updatedAt,
            isDeleted: false,
          );
          await txn.insert(
            'activity_category_links',
            link.toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          saved.add(link);
        }
        for (final link in existing.values) {
          if (desired.containsKey(link.categoryId) || link.isDeleted) {
            continue;
          }
          final deleted = link.copyWith(isDeleted: true, updatedAt: updatedAt);
          await txn.insert(
            'activity_category_links',
            deleted.toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      saved.sort((a, b) {
        final primaryCompare =
            (b.isPrimary ? 1 : 0).compareTo(a.isPrimary ? 1 : 0);
        if (primaryCompare != 0) return primaryCompare;
        return a.sortOrder.compareTo(b.sortOrder);
      });
      return AppSuccess(saved);
    } catch (e) {
      return AppFailure('Failed to set activity categories: $e');
    }
  }

  @override
  Future<AppResult<List<ActivityCategory>>> categoriesSince(
    DateTime since,
  ) async {
    try {
      final db = await _database.db;
      final rows = await db.query(
        'activity_categories',
        where: 'updated_at >= ?',
        whereArgs: [since.toUtc().toIso8601String()],
        orderBy: 'updated_at asc',
      );
      return AppSuccess(rows.map(ActivityCategory.fromMap).toList());
    } catch (e) {
      return AppFailure('Failed to load categories since: $e');
    }
  }

  @override
  Future<AppResult<List<ActivityCategoryLink>>> categoryLinksSince(
    DateTime since,
  ) async {
    try {
      final db = await _database.db;
      final rows = await db.query(
        'activity_category_links',
        where: 'updated_at >= ?',
        whereArgs: [since.toUtc().toIso8601String()],
        orderBy: 'updated_at asc',
      );
      return AppSuccess(rows.map(ActivityCategoryLink.fromMap).toList());
    } catch (e) {
      return AppFailure('Failed to load category links since: $e');
    }
  }

  @override
  Future<AppResult<void>> replaceCategoryIfRemoteNewer(
    ActivityCategory remote,
  ) async {
    try {
      final db = await _database.db;
      final local = await categoryById(remote.id, db);
      if (local == null || local.updatedAt.isBefore(remote.updatedAt)) {
        await upsertCategory(remote, db);
      }
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to replace category: $e');
    }
  }

  @override
  Future<AppResult<void>> replaceCategoryLinkIfRemoteNewer(
    ActivityCategoryLink remote,
  ) async {
    try {
      final db = await _database.db;
      final local = await categoryLinkById(remote.id, db);
      if (local == null || local.updatedAt.isBefore(remote.updatedAt)) {
        await upsertCategoryLink(remote, db);
      }
      return const AppSuccess(null);
    } catch (e) {
      return AppFailure('Failed to replace category link: $e');
    }
  }

  Future<void> upsertCategory(
    ActivityCategory category, [
    DatabaseExecutor? executor,
  ]) async {
    final target = executor ?? await _database.db;
    await target.insert(
      'activity_categories',
      category.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertCategoryLink(
    ActivityCategoryLink link, [
    DatabaseExecutor? executor,
  ]) async {
    final target = executor ?? await _database.db;
    await target.insert(
      'activity_category_links',
      link.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ActivityCategory?> categoryById(
    String id,
    DatabaseExecutor executor,
  ) async {
    final rows = await executor.query(
      'activity_categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ActivityCategory.fromMap(rows.first);
  }

  Future<ActivityCategoryLink?> categoryLinkById(
    String id,
    DatabaseExecutor executor,
  ) async {
    final rows = await executor.query(
      'activity_category_links',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ActivityCategoryLink.fromMap(rows.first);
  }

  String _stableLinkId(String activityId, String categoryId) {
    return _uuid.v5(
      Namespace.url.value,
      'timetrack:activity-category-link:$activityId:$categoryId',
    );
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
