import '../domain/activity_category.dart';

class CategoryCache {
  const CategoryCache._({
    required this.categories,
    required this.links,
    required Map<String, ActivityCategory> categoryById,
    required Map<String, List<ActivityCategoryLink>> linksByActivity,
    required Map<String, ActivityCategory> primaryCategoryByActivity,
    required Map<String, List<ActivityCategory>> secondaryCategoriesByActivity,
  })  : _categoryById = categoryById,
        _linksByActivity = linksByActivity,
        _primaryCategoryByActivity = primaryCategoryByActivity,
        _secondaryCategoriesByActivity = secondaryCategoriesByActivity;

  static const empty = CategoryCache._(
    categories: [],
    links: [],
    categoryById: {},
    linksByActivity: {},
    primaryCategoryByActivity: {},
    secondaryCategoriesByActivity: {},
  );

  factory CategoryCache.from({
    required List<ActivityCategory> categories,
    required List<ActivityCategoryLink> links,
  }) {
    final categoryById = {
      for (final category in categories)
        if (!category.isDeleted) category.id: category,
    };

    final linksByActivity = <String, List<ActivityCategoryLink>>{};
    for (final link in links) {
      if (link.isDeleted || !categoryById.containsKey(link.categoryId)) {
        continue;
      }
      linksByActivity.putIfAbsent(link.activityId, () => []).add(link);
    }
    for (final activityLinks in linksByActivity.values) {
      activityLinks.sort(_compareCategoryLinks);
    }

    final indexedLinksByActivity = <String, List<ActivityCategoryLink>>{
      for (final entry in linksByActivity.entries)
        entry.key: List.unmodifiable(entry.value),
    };
    final primaryCategoryByActivity = <String, ActivityCategory>{
      for (final entry in indexedLinksByActivity.entries)
        if (entry.value.any((link) => link.isPrimary))
          entry.key: categoryById[
              entry.value.firstWhere((link) => link.isPrimary).categoryId]!,
    };
    final secondaryCategoriesByActivity = <String, List<ActivityCategory>>{
      for (final entry in indexedLinksByActivity.entries)
        entry.key: List.unmodifiable([
          for (final link in entry.value)
            if (!link.isPrimary) categoryById[link.categoryId]!,
        ]),
    };

    return CategoryCache._(
      categories: categories,
      links: links,
      categoryById: Map.unmodifiable(categoryById),
      linksByActivity: Map.unmodifiable(indexedLinksByActivity),
      primaryCategoryByActivity: Map.unmodifiable(primaryCategoryByActivity),
      secondaryCategoriesByActivity:
          Map.unmodifiable(secondaryCategoriesByActivity),
    );
  }

  final List<ActivityCategory> categories;
  final List<ActivityCategoryLink> links;
  final Map<String, ActivityCategory> _categoryById;
  final Map<String, List<ActivityCategoryLink>> _linksByActivity;
  final Map<String, ActivityCategory> _primaryCategoryByActivity;
  final Map<String, List<ActivityCategory>> _secondaryCategoriesByActivity;

  ActivityCategory? categoryById(String id) {
    return _categoryById[id];
  }

  ActivityCategory? primaryCategoryForActivity(String activityId) {
    return _primaryCategoryByActivity[activityId];
  }

  List<ActivityCategory> secondaryCategoriesForActivity(String activityId) {
    return _secondaryCategoriesByActivity[activityId] ?? const [];
  }

  List<ActivityCategoryLink> linksForActivity(String activityId) {
    return _linksByActivity[activityId] ?? const [];
  }

  static int _compareCategoryLinks(
    ActivityCategoryLink first,
    ActivityCategoryLink second,
  ) {
    final primaryCompare =
        (second.isPrimary ? 1 : 0).compareTo(first.isPrimary ? 1 : 0);
    if (primaryCompare != 0) return primaryCompare;
    return first.sortOrder.compareTo(second.sortOrder);
  }
}
