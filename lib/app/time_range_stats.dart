part of 'time_stats.dart';

class TimeRangeStats {
  const TimeRangeStats({
    required this.totalsByActivity,
    required this.totalsByDay,
    required this.totalDuration,
    required this.longestBlock,
    this.activitySnapshots = const {},
    this.groupSlices = const [],
  });

  final Map<String, Duration> totalsByActivity;
  final Map<DateTime, Duration> totalsByDay;
  final Duration totalDuration;
  final Duration longestBlock;
  final Map<String, ActivityStatsSnapshot> activitySnapshots;
  final List<StatsEntrySlice> groupSlices;

  static TimeRangeStats fromEntries({
    required List<TimeEntry> entries,
    required DateTime start,
    required DateTime end,
    required DateTime effectiveNow,
    List<Activity> activities = const [],
    List<ActivityCategory> categories = const [],
    List<ActivityCategoryLink> categoryLinks = const [],
  }) {
    if (end.isBefore(start)) {
      return const TimeRangeStats(
        totalsByActivity: {},
        totalsByDay: {},
        totalDuration: Duration.zero,
        longestBlock: Duration.zero,
      );
    }

    final totalsByActivity = <String, Duration>{};
    final totalsByDay = <DateTime, Duration>{};
    final activitySnapshots = <String, ActivityStatsSnapshot>{};
    final activityById = {
      for (final activity in activities)
        if (!activity.isDeleted) activity.id: activity,
    };
    final categoryById = {
      for (final category in categories)
        if (!category.isDeleted) category.id: category,
    };
    final linksByActivity = <String, List<ActivityCategoryLink>>{};
    for (final link in categoryLinks) {
      if (link.isDeleted || !categoryById.containsKey(link.categoryId)) {
        continue;
      }
      linksByActivity.putIfAbsent(link.activityId, () => []).add(link);
    }
    for (final links in linksByActivity.values) {
      links.sort((a, b) {
        final primaryCompare =
            (b.isPrimary ? 1 : 0).compareTo(a.isPrimary ? 1 : 0);
        if (primaryCompare != 0) return primaryCompare;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    }
    for (final activity in activities) {
      if (activity.isDeleted) continue;
      activitySnapshots[activity.id] = ActivityStatsSnapshot(
        name: activity.name,
        color: activity.color,
      );
    }
    final groupSlices = <StatsEntrySlice>[];
    var totalDuration = Duration.zero;
    var longestBlock = Duration.zero;

    for (final entry in entries) {
      final clippedStart = _later(entry.startAt, start);
      final clippedEnd = _earlier(entry.endAt ?? effectiveNow, end);
      if (!clippedEnd.isAfter(clippedStart)) {
        continue;
      }

      final clippedDuration = clippedEnd.difference(clippedStart);
      final activity = activityById[entry.activityId];
      final links = linksByActivity[entry.activityId] ?? const [];
      ActivityCategory? primaryCategory;
      for (final link in links) {
        if (link.isPrimary) {
          primaryCategory = categoryById[link.categoryId];
          break;
        }
      }
      groupSlices.add(
        StatsEntrySlice(
          activityId: entry.activityId,
          activityLabel: activity?.name ??
              _snapshotName(entry) ??
              entry.activityNameSnapshot.trim(),
          activityColor: activity?.color ??
              entry.activityColorSnapshot ??
              AppConstants.defaultActivityColor,
          primaryCategoryId: primaryCategory?.id,
          primaryCategoryLabel: primaryCategory?.name,
          primaryCategoryColor: primaryCategory?.color,
          linkedCategoryIds: {
            for (final link in links) link.categoryId,
          },
          duration: clippedDuration,
        ),
      );
      totalsByActivity[entry.activityId] =
          (totalsByActivity[entry.activityId] ?? Duration.zero) +
              clippedDuration;
      if (entry.activityNameSnapshot.trim().isNotEmpty ||
          entry.activityColorSnapshot != null) {
        activitySnapshots[entry.activityId] = ActivityStatsSnapshot(
          name: entry.activityNameSnapshot.trim(),
          color: entry.activityColorSnapshot,
        );
      }
      totalDuration += clippedDuration;
      if (clippedDuration > longestBlock) {
        longestBlock = clippedDuration;
      }

      var cursor = clippedStart;
      while (cursor.isBefore(clippedEnd)) {
        final day = cursor.startOfDay;
        final nextDay = day.add(const Duration(days: 1));
        final segmentEnd = _earlier(nextDay, clippedEnd);
        final duration = segmentEnd.difference(cursor);
        totalsByDay[day] = (totalsByDay[day] ?? Duration.zero) + duration;
        cursor = segmentEnd;
      }
    }

    return TimeRangeStats(
      totalsByActivity: totalsByActivity,
      totalsByDay: totalsByDay,
      totalDuration: totalDuration,
      longestBlock: longestBlock,
      activitySnapshots: activitySnapshots,
      groupSlices: groupSlices,
    );
  }

  List<StatsGroupRow> groupRows({
    StatsDimension dimension = StatsDimension.activity,
    Set<String> selectedCategoryIds = const {},
  }) {
    final builders = <String, _StatsGroupBuilder>{};
    for (final slice in groupSlices) {
      if (selectedCategoryIds.isNotEmpty &&
          !slice.linkedCategoryIds.any(selectedCategoryIds.contains)) {
        continue;
      }
      final key = _groupKey(slice, dimension);
      final builder = builders.putIfAbsent(
        key.id,
        () => _StatsGroupBuilder(
          id: key.id,
          label: key.label,
          color: key.color,
        ),
      );
      builder.add(slice.duration);
    }

    final rows = [
      for (final builder in builders.values) builder.toRow(),
    ];
    rows.sort((a, b) {
      final durationCompare = b.totalDuration.compareTo(a.totalDuration);
      if (durationCompare != 0) return durationCompare;
      return a.label.compareTo(b.label);
    });
    return rows;
  }

  static _StatsGroupKey _groupKey(
    StatsEntrySlice slice,
    StatsDimension dimension,
  ) {
    return switch (dimension) {
      StatsDimension.activity => _StatsGroupKey(
          id: 'activity:${slice.activityId}',
          label: slice.activityLabel.trim().isEmpty
              ? '未知事项'
              : slice.activityLabel.trim(),
          color: slice.activityColor,
        ),
      StatsDimension.primaryCategory => _categoryGroupKey(slice),
      StatsDimension.durationBucket => _StatsGroupKey(
          id: 'bucket:${slice.durationBucketLabel}',
          label: slice.durationBucketLabel,
          color: slice.durationBucketColor,
        ),
      StatsDimension.primaryCategoryAndDurationBucket => _StatsGroupKey(
          id: 'category:${slice.primaryCategoryId ?? 'none'}'
              ':bucket:${slice.durationBucketLabel}',
          label: '${slice.primaryCategoryLabel ?? '未分类'} / '
              '${slice.durationBucketLabel}',
          color:
              slice.primaryCategoryColor ?? AppConstants.defaultActivityColor,
        ),
    };
  }

  static _StatsGroupKey _categoryGroupKey(StatsEntrySlice slice) {
    return _StatsGroupKey(
      id: 'category:${slice.primaryCategoryId ?? 'none'}',
      label: slice.primaryCategoryLabel ?? '未分类',
      color: slice.primaryCategoryColor ?? AppConstants.defaultActivityColor,
    );
  }

  static String? _snapshotName(TimeEntry entry) {
    final name = entry.activityNameSnapshot.trim();
    return name.isEmpty ? null : name;
  }
}
