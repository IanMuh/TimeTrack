import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/category_state.dart';
import 'package:timetrack/domain/activity_category.dart';

void main() {
  test('refresh loads categories and links into cache', () async {
    final now = DateTime.utc(2026, 1, 1);
    final category = _category('cat-work', now: now);
    final state = _buildState(
      categories: [category],
      links: [
        _link(
          'link-work',
          categoryId: category.id,
          isPrimary: true,
          now: now,
        ),
      ],
    );

    await state.refresh();

    expect(state.categories, [category]);
    expect(state.links, hasLength(1));
    expect(state.primaryCategoryForActivity('activity-1'), category);
    expect(state.linksForActivity('activity-1').single.id, 'link-work');
  });

  test('createCategory refreshes cache after writing', () async {
    final fake = _FakeCategoryHandlers();
    final state = fake.buildState();

    final category = await state.createCategory('Work', 0xff2563eb);

    expect(category.name, 'Work');
    expect(state.categories, [category]);
    expect(fake.createCalls, 1);
  });

  test('setActivityCategories refreshes ordered primary and secondary links',
      () async {
    final now = DateTime.utc(2026, 1, 1);
    final primary = _category('cat-primary', now: now);
    final secondary = _category('cat-secondary', now: now);
    final fake = _FakeCategoryHandlers(categories: [primary, secondary]);
    final state = fake.buildState();

    await state.setActivityCategories(
      activityId: 'activity-1',
      primaryCategoryId: primary.id,
      secondaryCategoryIds: [secondary.id],
    );

    expect(state.primaryCategoryForActivity('activity-1'), primary);
    expect(state.secondaryCategoriesForActivity('activity-1'), [secondary]);
    expect(
      state.linksForActivity('activity-1').map((link) => link.categoryId),
      [primary.id, secondary.id],
    );
  });
}

CategoryState _buildState({
  required List<ActivityCategory> categories,
  required List<ActivityCategoryLink> links,
}) {
  return CategoryState.withHandlers(
    loadCategories: () async => categories,
    loadLinks: () async => links,
    createCategory: ({required name, required color}) async {
      return _category('created', name: name, color: color);
    },
    updateCategory: ({required category, required name, required color}) async {
      return category.copyWith(name: name, color: color);
    },
    deleteCategory: (_) async {},
    setActivityCategories: ({
      required activityId,
      required primaryCategoryId,
      required secondaryCategoryIds,
    }) async {
      return [];
    },
  );
}

class _FakeCategoryHandlers {
  _FakeCategoryHandlers({
    List<ActivityCategory> categories = const [],
  }) : _categories = [...categories];

  final List<ActivityCategory> _categories;
  final List<ActivityCategoryLink> _links = [];
  var createCalls = 0;

  CategoryState buildState() {
    return CategoryState.withHandlers(
      loadCategories: () async => [..._categories],
      loadLinks: () async => [..._links],
      createCategory: ({required name, required color}) async {
        createCalls += 1;
        final category = _category(
          'cat-${_categories.length + 1}',
          name: name,
          color: color,
        );
        _categories.add(category);
        return category;
      },
      updateCategory: (
          {required category, required name, required color}) async {
        final updated = category.copyWith(name: name, color: color);
        _categories
          ..removeWhere((item) => item.id == category.id)
          ..add(updated);
        return updated;
      },
      deleteCategory: (category) async {
        _categories.removeWhere((item) => item.id == category.id);
        _links.removeWhere((link) => link.categoryId == category.id);
      },
      setActivityCategories: ({
        required activityId,
        required primaryCategoryId,
        required secondaryCategoryIds,
      }) async {
        _links.removeWhere((link) => link.activityId == activityId);
        var sortOrder = 0;
        if (primaryCategoryId != null) {
          _links.add(
            _link(
              'link-$activityId-$primaryCategoryId',
              activityId: activityId,
              categoryId: primaryCategoryId,
              isPrimary: true,
              sortOrder: sortOrder++,
            ),
          );
        }
        for (final categoryId in secondaryCategoryIds) {
          _links.add(
            _link(
              'link-$activityId-$categoryId',
              activityId: activityId,
              categoryId: categoryId,
              isPrimary: false,
              sortOrder: sortOrder++,
            ),
          );
        }
        return [..._links];
      },
    );
  }
}

ActivityCategory _category(
  String id, {
  String name = 'Category',
  int color = 0xff2563eb,
  DateTime? now,
}) {
  return ActivityCategory(
    id: id,
    userId: null,
    name: name,
    color: color,
    updatedAt: now ?? DateTime.utc(2026, 1, 1),
    isDeleted: false,
  );
}

ActivityCategoryLink _link(
  String id, {
  String activityId = 'activity-1',
  required String categoryId,
  bool isPrimary = false,
  int sortOrder = 0,
  DateTime? now,
}) {
  return ActivityCategoryLink(
    id: id,
    userId: null,
    activityId: activityId,
    categoryId: categoryId,
    isPrimary: isPrimary,
    sortOrder: sortOrder,
    updatedAt: now ?? DateTime.utc(2026, 1, 1),
    isDeleted: false,
  );
}
