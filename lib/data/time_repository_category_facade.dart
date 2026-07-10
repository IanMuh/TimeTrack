part of 'time_repository.dart';

mixin TimeRepositoryCategoryFacade {
  RepositoryCategoryRepository get _categoryFacade;

  Future<List<ActivityCategory>> categories({
    bool includeDeleted = false,
  }) async {
    return _categoryFacade.categories(includeDeleted: includeDeleted);
  }

  Future<ActivityCategory> createCategory({
    required String name,
    required int color,
    String? userId,
  }) async {
    return _categoryFacade.createCategory(
      name: name,
      color: color,
      userId: userId,
    );
  }

  Future<ActivityCategory> updateCategory({
    required ActivityCategory category,
    required String name,
    required int color,
  }) async {
    return _categoryFacade.updateCategory(
      category: category,
      name: name,
      color: color,
    );
  }

  Future<void> deleteCategory(ActivityCategory category) async {
    await _categoryFacade.deleteCategory(category);
  }

  Future<List<ActivityCategoryLink>> activityCategoryLinks({
    bool includeDeleted = false,
  }) async {
    return _categoryFacade.activityCategoryLinks(
      includeDeleted: includeDeleted,
    );
  }

  Future<List<ActivityCategoryLink>> linksForActivity(
    String activityId, {
    bool includeDeleted = false,
  }) async {
    return _categoryFacade.linksForActivity(
      activityId,
      includeDeleted: includeDeleted,
    );
  }

  Future<List<ActivityCategoryLink>> setActivityCategories({
    required String activityId,
    required String? primaryCategoryId,
    required List<String> secondaryCategoryIds,
    String? userId,
  }) async {
    return _categoryFacade.setActivityCategories(
      activityId: activityId,
      primaryCategoryId: primaryCategoryId,
      secondaryCategoryIds: secondaryCategoryIds,
      userId: userId,
    );
  }

  Future<List<ActivityCategory>> categoriesSince(DateTime since) async {
    return _categoryFacade.categoriesSince(since);
  }

  Future<List<ActivityCategoryLink>> categoryLinksSince(DateTime since) async {
    return _categoryFacade.categoryLinksSince(since);
  }

  Future<void> replaceCategoryIfRemoteNewer(ActivityCategory remote) async {
    await _categoryFacade.replaceCategoryIfRemoteNewer(remote);
  }

  Future<void> replaceCategoryLinkIfRemoteNewer(
    ActivityCategoryLink remote,
  ) async {
    await _categoryFacade.replaceCategoryLinkIfRemoteNewer(remote);
  }
}
