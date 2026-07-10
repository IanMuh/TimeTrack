import 'dart:async';

import '../domain/activity_category.dart';
import 'category_state.dart';
import 'undo_state.dart';

typedef CategoryChangeNotifier = void Function();
typedef CategorySyncRunner = Future<void> Function();
typedef CategoryMutationCreator = Future<ActivityCategory> Function(
  String name,
  int color,
);
typedef CategoryMutationUpdater = Future<ActivityCategory> Function(
  ActivityCategory category, {
  required String name,
  required int color,
});
typedef CategoryMutationDeleter = Future<void> Function(
  ActivityCategory category,
);
typedef ActivityCategoryAssigner = Future<void> Function({
  required String activityId,
  required String? primaryCategoryId,
  required List<String> secondaryCategoryIds,
});

class CategoryMutationState {
  CategoryMutationState({
    required CategoryState categoryState,
    required UndoableRecorder recordUndoable,
    required CategoryChangeNotifier notifyListeners,
    required CategorySyncRunner sync,
  }) : this.withHandlers(
          recordUndoable: recordUndoable,
          notifyListeners: notifyListeners,
          sync: sync,
          createCategory: categoryState.createCategory,
          updateCategory: categoryState.updateCategory,
          deleteCategory: categoryState.deleteCategory,
          setActivityCategories: categoryState.setActivityCategories,
        );

  CategoryMutationState.withHandlers({
    required UndoableRecorder recordUndoable,
    required CategoryChangeNotifier notifyListeners,
    required CategorySyncRunner sync,
    required CategoryMutationCreator createCategory,
    required CategoryMutationUpdater updateCategory,
    required CategoryMutationDeleter deleteCategory,
    required ActivityCategoryAssigner setActivityCategories,
  })  : _recordUndoable = recordUndoable,
        _notifyListeners = notifyListeners,
        _sync = sync,
        _createCategory = createCategory,
        _updateCategory = updateCategory,
        _deleteCategory = deleteCategory,
        _setActivityCategories = setActivityCategories;

  final UndoableRecorder _recordUndoable;
  final CategoryChangeNotifier _notifyListeners;
  final CategorySyncRunner _sync;
  final CategoryMutationCreator _createCategory;
  final CategoryMutationUpdater _updateCategory;
  final CategoryMutationDeleter _deleteCategory;
  final ActivityCategoryAssigner _setActivityCategories;

  Future<ActivityCategory> createCategory(String name, int color) {
    return _recordSyncedValue('新增分类', () {
      return _createCategory(name, color);
    });
  }

  Future<ActivityCategory> updateCategory(
    ActivityCategory category, {
    required String name,
    required int color,
  }) {
    return _recordSyncedValue('编辑分类', () {
      return _updateCategory(
        category,
        name: name,
        color: color,
      );
    });
  }

  Future<void> deleteCategory(ActivityCategory category) async {
    await _recordSyncedVoid('删除分类', () {
      return _deleteCategory(category);
    });
  }

  Future<void> setActivityCategories({
    required String activityId,
    required String? primaryCategoryId,
    required List<String> secondaryCategoryIds,
  }) async {
    await _recordSyncedVoid('编辑事项分类', () {
      return setActivityCategoriesRaw(
        activityId: activityId,
        primaryCategoryId: primaryCategoryId,
        secondaryCategoryIds: secondaryCategoryIds,
      );
    });
  }

  Future<void> setActivityCategoriesRaw({
    required String activityId,
    required String? primaryCategoryId,
    required List<String> secondaryCategoryIds,
  }) async {
    await _setActivityCategories(
      activityId: activityId,
      primaryCategoryId: primaryCategoryId,
      secondaryCategoryIds: secondaryCategoryIds,
    );
  }

  Future<T> _recordSyncedValue<T>(
    String label,
    Future<T> Function() action,
  ) {
    return _recordUndoable(label, () async {
      final result = await action();
      _notifyListeners();
      unawaited(_sync());
      return result;
    });
  }

  Future<void> _recordSyncedVoid(
    String label,
    Future<void> Function() action,
  ) async {
    await _recordUndoable(label, () async {
      await action();
      _notifyListeners();
      unawaited(_sync());
    });
  }
}
