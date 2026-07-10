import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/domain/activity_category.dart';

import 'test_fixtures.dart';

void main() {
  test('AppState category facade stays separate from activity facade', () {
    final categoryFacade = File('lib/app/app_state_category_facade.dart');
    final activityFacade = File('lib/app/app_state_activity_facade.dart');

    expect(categoryFacade.existsSync(), isTrue);

    final categorySource = categoryFacade.readAsStringSync();
    final activitySource = activityFacade.readAsStringSync();

    expect(categorySource, contains('mixin AppStateCategoryFacade'));
    expect(
      categorySource,
      contains('List<ActivityCategory> get activityCategories'),
    );
    expect(categorySource, contains('Future<void> setActivityCategories({'));
    expect(
      activitySource,
      isNot(contains('List<ActivityCategory> get activityCategories')),
    );
    expect(activitySource, isNot(contains('ActivityCategory? categoryById')));
    expect(
      activitySource,
      isNot(contains('Future<ActivityCategory> createCategory')),
    );
    expect(
      activitySource,
      isNot(contains('Future<void> setActivityCategories({')),
    );
  });

  test('AppState category cache filters deleted rows and keeps link order',
      () async {
    final fixture = await buildTestAppFixture(
      seedData: false,
      refresh: false,
    );
    final state = fixture.state;
    addTearDown(fixture.dispose);
    final now = DateTime.utc(2026, 1, 1);

    state.activityCategories = [
      ActivityCategory(
        id: 'cat-primary',
        userId: null,
        name: 'Primary',
        color: 0xff2563eb,
        updatedAt: now,
        isDeleted: false,
      ),
      ActivityCategory(
        id: 'cat-secondary-a',
        userId: null,
        name: 'Secondary A',
        color: 0xff16a34a,
        updatedAt: now,
        isDeleted: false,
      ),
      ActivityCategory(
        id: 'cat-secondary-b',
        userId: null,
        name: 'Secondary B',
        color: 0xffdc2626,
        updatedAt: now,
        isDeleted: false,
      ),
      ActivityCategory(
        id: 'cat-deleted',
        userId: null,
        name: 'Deleted',
        color: 0xff64748b,
        updatedAt: now,
        isDeleted: true,
      ),
    ];
    state.activityCategoryLinks = [
      _link(
        'link-secondary-b',
        activityId: 'activity-1',
        categoryId: 'cat-secondary-b',
        sortOrder: 3,
        now: now,
      ),
      _link(
        'link-primary',
        activityId: 'activity-1',
        categoryId: 'cat-primary',
        isPrimary: true,
        sortOrder: 9,
        now: now,
      ),
      _link(
        'link-secondary-a',
        activityId: 'activity-1',
        categoryId: 'cat-secondary-a',
        sortOrder: 1,
        now: now,
      ),
      _link(
        'link-deleted-category',
        activityId: 'activity-1',
        categoryId: 'cat-deleted',
        sortOrder: 0,
        now: now,
      ),
      _link(
        'link-deleted',
        activityId: 'activity-1',
        categoryId: 'cat-secondary-a',
        sortOrder: 0,
        now: now,
        isDeleted: true,
      ),
      _link(
        'link-missing-category',
        activityId: 'activity-1',
        categoryId: 'cat-missing',
        sortOrder: 0,
        now: now,
      ),
    ];

    expect(state.categoryById('cat-deleted'), isNull);
    expect(state.primaryCategoryForActivity('activity-1')?.id, 'cat-primary');
    expect(
      state
          .secondaryCategoriesForActivity('activity-1')
          .map((category) => category.id),
      ['cat-secondary-a', 'cat-secondary-b'],
    );
    expect(
      state.categoryLinksForActivity('activity-1').map((link) => link.id),
      ['link-primary', 'link-secondary-a', 'link-secondary-b'],
    );
  });
}

ActivityCategoryLink _link(
  String id, {
  required String activityId,
  required String categoryId,
  required int sortOrder,
  required DateTime now,
  bool isPrimary = false,
  bool isDeleted = false,
}) {
  return ActivityCategoryLink(
    id: id,
    userId: null,
    activityId: activityId,
    categoryId: categoryId,
    isPrimary: isPrimary,
    sortOrder: sortOrder,
    updatedAt: now,
    isDeleted: isDeleted,
  );
}
