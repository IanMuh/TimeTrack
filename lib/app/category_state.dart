import '../data/time_repository.dart';
import '../domain/activity_category.dart';
import 'category_cache.dart';

typedef CategoryLoader = Future<List<ActivityCategory>> Function();
typedef CategoryLinkLoader = Future<List<ActivityCategoryLink>> Function();
typedef CategoryCreator = Future<ActivityCategory> Function({
  required String name,
  required int color,
});
typedef CategoryUpdater = Future<ActivityCategory> Function({
  required ActivityCategory category,
  required String name,
  required int color,
});
typedef CategoryDeleter = Future<void> Function(ActivityCategory category);
typedef ActivityCategoriesSetter = Future<List<ActivityCategoryLink>> Function({
  required String activityId,
  required String? primaryCategoryId,
  required List<String> secondaryCategoryIds,
});

class CategoryState {
  CategoryState({
    required TimeRepository repository,
  }) : this.withHandlers(
          loadCategories: repository.categories,
          loadLinks: repository.activityCategoryLinks,
          createCategory: ({required name, required color}) {
            return repository.createCategory(name: name, color: color);
          },
          updateCategory: ({
            required category,
            required name,
            required color,
          }) {
            return repository.updateCategory(
              category: category,
              name: name,
              color: color,
            );
          },
          deleteCategory: repository.deleteCategory,
          setActivityCategories: ({
            required activityId,
            required primaryCategoryId,
            required secondaryCategoryIds,
          }) {
            return repository.setActivityCategories(
              activityId: activityId,
              primaryCategoryId: primaryCategoryId,
              secondaryCategoryIds: secondaryCategoryIds,
            );
          },
        );

  CategoryState.withHandlers({
    required CategoryLoader loadCategories,
    required CategoryLinkLoader loadLinks,
    required CategoryCreator createCategory,
    required CategoryUpdater updateCategory,
    required CategoryDeleter deleteCategory,
    required ActivityCategoriesSetter setActivityCategories,
  })  : _loadCategories = loadCategories,
        _loadLinks = loadLinks,
        _createCategory = createCategory,
        _updateCategory = updateCategory,
        _deleteCategory = deleteCategory,
        _setActivityCategories = setActivityCategories;

  final CategoryLoader _loadCategories;
  final CategoryLinkLoader _loadLinks;
  final CategoryCreator _createCategory;
  final CategoryUpdater _updateCategory;
  final CategoryDeleter _deleteCategory;
  final ActivityCategoriesSetter _setActivityCategories;

  CategoryCache _cache = CategoryCache.empty;

  List<ActivityCategory> get categories => _cache.categories;

  set categories(List<ActivityCategory> value) {
    _setCache(categories: value, links: _cache.links);
  }

  List<ActivityCategoryLink> get links => _cache.links;

  set links(List<ActivityCategoryLink> value) {
    _setCache(categories: _cache.categories, links: value);
  }

  ActivityCategory? categoryById(String id) {
    return _cache.categoryById(id);
  }

  ActivityCategory? primaryCategoryForActivity(String activityId) {
    return _cache.primaryCategoryForActivity(activityId);
  }

  List<ActivityCategory> secondaryCategoriesForActivity(String activityId) {
    return _cache.secondaryCategoriesForActivity(activityId);
  }

  List<ActivityCategoryLink> linksForActivity(String activityId) {
    return _cache.linksForActivity(activityId);
  }

  Future<void> refresh() async {
    _setCache(
      categories: await _loadCategories(),
      links: await _loadLinks(),
    );
  }

  Future<ActivityCategory> createCategory(String name, int color) async {
    final category = await _createCategory(name: name, color: color);
    await refresh();
    return category;
  }

  Future<ActivityCategory> updateCategory(
    ActivityCategory category, {
    required String name,
    required int color,
  }) async {
    final updated = await _updateCategory(
      category: category,
      name: name,
      color: color,
    );
    await refresh();
    return updated;
  }

  Future<void> deleteCategory(ActivityCategory category) async {
    await _deleteCategory(category);
    await refresh();
  }

  Future<void> setActivityCategories({
    required String activityId,
    required String? primaryCategoryId,
    required List<String> secondaryCategoryIds,
  }) async {
    await _setActivityCategories(
      activityId: activityId,
      primaryCategoryId: primaryCategoryId,
      secondaryCategoryIds: secondaryCategoryIds,
    );
    await refresh();
  }

  void _setCache({
    required List<ActivityCategory> categories,
    required List<ActivityCategoryLink> links,
  }) {
    _cache = CategoryCache.from(
      categories: categories,
      links: links,
    );
  }
}
