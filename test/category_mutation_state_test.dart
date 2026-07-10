import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/category_mutation_state.dart';
import 'package:timetrack/data/repository_undo.dart';
import 'package:timetrack/domain/activity_category.dart';

void main() {
  test('create update and delete categories record undo and sync', () async {
    final category = _category(id: 'category');
    final updated = category.copyWith(id: 'updated');
    final harness = _Harness(
      categoryToCreate: category,
      categoryToUpdate: updated,
    );

    final created = await harness.state.createCategory('Work', 0xff2563eb);
    final edited = await harness.state.updateCategory(
      category,
      name: 'Updated',
      color: 0xff14b8a6,
    );
    await harness.state.deleteCategory(category);

    expect(created, category);
    expect(edited, updated);
    expect(harness.labels, ['新增分类', '编辑分类', '删除分类']);
    expect(harness.createCalls, [('Work', 0xff2563eb)]);
    expect(harness.updateCalls.single.category, category);
    expect(harness.updateCalls.single.name, 'Updated');
    expect(harness.updateCalls.single.color, 0xff14b8a6);
    expect(harness.deletedCategories, [category]);
    expect(harness.notifyCount, 3);
    expect(harness.syncCount, 3);
    expect(harness.syncAfterValues, [true, true, true]);
    expect(harness.undoScopes, [null, null, null]);
  });

  test('setActivityCategories records undo and forwards category assignment',
      () async {
    final harness = _Harness();

    await harness.state.setActivityCategories(
      activityId: 'activity',
      primaryCategoryId: 'primary',
      secondaryCategoryIds: ['secondary'],
    );

    expect(harness.labels, ['编辑事项分类']);
    expect(harness.assignmentCalls.single.activityId, 'activity');
    expect(harness.assignmentCalls.single.primaryCategoryId, 'primary');
    expect(harness.assignmentCalls.single.secondaryCategoryIds, ['secondary']);
    expect(harness.notifyCount, 1);
    expect(harness.syncCount, 1);
  });

  test('setActivityCategoriesRaw forwards without undo notify or sync',
      () async {
    final harness = _Harness();

    await harness.state.setActivityCategoriesRaw(
      activityId: 'activity',
      primaryCategoryId: null,
      secondaryCategoryIds: ['secondary'],
    );

    expect(harness.assignmentCalls.single.activityId, 'activity');
    expect(harness.assignmentCalls.single.primaryCategoryId, isNull);
    expect(harness.assignmentCalls.single.secondaryCategoryIds, ['secondary']);
    expect(harness.labels, isEmpty);
    expect(harness.notifyCount, 0);
    expect(harness.syncCount, 0);
  });
}

class _Harness {
  _Harness({
    ActivityCategory? categoryToCreate,
    ActivityCategory? categoryToUpdate,
  })  : categoryToCreate =
            categoryToCreate ?? _category(id: 'created-category'),
        categoryToUpdate = categoryToUpdate ?? _category(id: 'updated') {
    state = CategoryMutationState.withHandlers(
      recordUndoable: recordUndoable,
      notifyListeners: notifyListeners,
      sync: sync,
      createCategory: (name, color) async {
        createCalls.add((name, color));
        return this.categoryToCreate;
      },
      updateCategory: (category, {required name, required color}) async {
        updateCalls.add((
          category: category,
          name: name,
          color: color,
        ));
        return this.categoryToUpdate;
      },
      deleteCategory: (category) async {
        deletedCategories.add(category);
      },
      setActivityCategories: ({
        required activityId,
        required primaryCategoryId,
        required secondaryCategoryIds,
      }) async {
        assignmentCalls.add((
          activityId: activityId,
          primaryCategoryId: primaryCategoryId,
          secondaryCategoryIds: secondaryCategoryIds,
        ));
      },
    );
  }

  final ActivityCategory categoryToCreate;
  final ActivityCategory categoryToUpdate;
  late final CategoryMutationState state;

  final labels = <String>[];
  final syncAfterValues = <bool>[];
  final undoScopes = <RepositoryUndoScope?>[];
  final createCalls = <(String, int)>[];
  final updateCalls = <({
    ActivityCategory category,
    String name,
    int color,
  })>[];
  final deletedCategories = <ActivityCategory>[];
  final assignmentCalls = <({
    String activityId,
    String? primaryCategoryId,
    List<String> secondaryCategoryIds,
  })>[];
  int notifyCount = 0;
  int syncCount = 0;

  Future<T> recordUndoable<T>(
    String label,
    Future<T> Function() action, {
    bool syncAfter = true,
    RepositoryUndoScope? undoScope,
  }) async {
    labels.add(label);
    syncAfterValues.add(syncAfter);
    undoScopes.add(undoScope);
    return action();
  }

  void notifyListeners() {
    notifyCount += 1;
  }

  Future<void> sync() async {
    syncCount += 1;
  }
}

ActivityCategory _category({
  String id = 'category',
  String name = 'Category',
  int color = 0xff2563eb,
}) {
  return ActivityCategory(
    id: id,
    userId: null,
    name: name,
    color: color,
    updatedAt: DateTime(2026, 1, 2),
    isDeleted: false,
  );
}
