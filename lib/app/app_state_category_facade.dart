part of 'app_state.dart';

mixin AppStateCategoryFacade on ChangeNotifier {
  CategoryState get _categoryState;
  CategoryMutationState get _categoryMutationState;

  List<ActivityCategory> get activityCategories => _categoryState.categories;

  set activityCategories(List<ActivityCategory> value) {
    _categoryState.categories = value;
  }

  List<ActivityCategoryLink> get activityCategoryLinks => _categoryState.links;

  set activityCategoryLinks(List<ActivityCategoryLink> value) {
    _categoryState.links = value;
  }

  ActivityCategory? categoryById(String id) {
    return _categoryState.categoryById(id);
  }

  ActivityCategory? primaryCategoryForActivity(String activityId) {
    return _categoryState.primaryCategoryForActivity(activityId);
  }

  List<ActivityCategory> secondaryCategoriesForActivity(String activityId) {
    return _categoryState.secondaryCategoriesForActivity(activityId);
  }

  List<ActivityCategoryLink> categoryLinksForActivity(String activityId) {
    return _categoryState.linksForActivity(activityId);
  }

  Future<ActivityCategory> createCategory(String name, int color) {
    return _categoryMutationState.createCategory(name, color);
  }

  Future<ActivityCategory> updateCategory(
    ActivityCategory category, {
    required String name,
    required int color,
  }) {
    return _categoryMutationState.updateCategory(
      category,
      name: name,
      color: color,
    );
  }

  Future<void> deleteCategory(ActivityCategory category) {
    return _categoryMutationState.deleteCategory(category);
  }

  Future<void> setActivityCategories({
    required String activityId,
    required String? primaryCategoryId,
    required List<String> secondaryCategoryIds,
  }) {
    return _categoryMutationState.setActivityCategories(
      activityId: activityId,
      primaryCategoryId: primaryCategoryId,
      secondaryCategoryIds: secondaryCategoryIds,
    );
  }
}
