import '../core/result.dart';
import '../domain/activity_category.dart';
import 'activity_category_repository.dart';
import 'repository_result.dart';

class RepositoryCategoryRepository {
  const RepositoryCategoryRepository({
    required ActivityCategoryRepository categoryRepository,
  }) : _categoryRepo = categoryRepository;

  final ActivityCategoryRepository _categoryRepo;

  Future<List<ActivityCategory>> categories({
    bool includeDeleted = false,
  }) async {
    final result = await _categoryRepo.categories(
      includeDeleted: includeDeleted,
    );
    return _unwrap(result);
  }

  Future<ActivityCategory> createCategory({
    required String name,
    required int color,
    String? userId,
  }) async {
    final result = await _categoryRepo.createCategory(
      name: name,
      color: color,
      userId: userId,
    );
    return _unwrap(result);
  }

  Future<ActivityCategory> updateCategory({
    required ActivityCategory category,
    required String name,
    required int color,
  }) async {
    final result = await _categoryRepo.updateCategory(
      category: category,
      name: name,
      color: color,
    );
    return _unwrap(result);
  }

  Future<void> deleteCategory(ActivityCategory category) async {
    final result = await _categoryRepo.deleteCategory(category);
    _unwrap(result);
  }

  Future<List<ActivityCategoryLink>> activityCategoryLinks({
    bool includeDeleted = false,
  }) async {
    final result = await _categoryRepo.activityCategoryLinks(
      includeDeleted: includeDeleted,
    );
    return _unwrap(result);
  }

  Future<List<ActivityCategoryLink>> linksForActivity(
    String activityId, {
    bool includeDeleted = false,
  }) async {
    final result = await _categoryRepo.linksForActivity(
      activityId,
      includeDeleted: includeDeleted,
    );
    return _unwrap(result);
  }

  Future<List<ActivityCategoryLink>> setActivityCategories({
    required String activityId,
    required String? primaryCategoryId,
    required List<String> secondaryCategoryIds,
    String? userId,
  }) async {
    final result = await _categoryRepo.setActivityCategories(
      activityId: activityId,
      primaryCategoryId: primaryCategoryId,
      secondaryCategoryIds: secondaryCategoryIds,
      userId: userId,
    );
    return _unwrap(result);
  }

  Future<List<ActivityCategory>> categoriesSince(DateTime since) async {
    final result = await _categoryRepo.categoriesSince(since);
    return _unwrap(result);
  }

  Future<List<ActivityCategoryLink>> categoryLinksSince(DateTime since) async {
    final result = await _categoryRepo.categoryLinksSince(since);
    return _unwrap(result);
  }

  Future<void> replaceCategoryIfRemoteNewer(ActivityCategory remote) async {
    final result = await _categoryRepo.replaceCategoryIfRemoteNewer(remote);
    _unwrap(result);
  }

  Future<void> replaceCategoryLinkIfRemoteNewer(
    ActivityCategoryLink remote,
  ) async {
    final result = await _categoryRepo.replaceCategoryLinkIfRemoteNewer(remote);
    _unwrap(result);
  }

  T _unwrap<T>(AppResult<T> result) {
    return unwrapRepositoryResult(result);
  }
}
