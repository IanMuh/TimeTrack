part of 'time_stats.dart';

enum StatsDimension {
  activity,
  primaryCategory,
  durationBucket,
  primaryCategoryAndDurationBucket,
}

class StatsGroupRow {
  const StatsGroupRow({
    required this.id,
    required this.label,
    required this.totalDuration,
    required this.count,
    required this.color,
  });

  final String id;
  final String label;
  final Duration totalDuration;
  final int count;
  final int color;
}

class ActivityStatsSnapshot {
  const ActivityStatsSnapshot({
    required this.name,
    required this.color,
  });

  final String name;
  final int? color;
}

class StatsEntrySlice {
  const StatsEntrySlice({
    required this.activityId,
    required this.activityLabel,
    required this.activityColor,
    required this.primaryCategoryId,
    required this.primaryCategoryLabel,
    required this.primaryCategoryColor,
    required this.linkedCategoryIds,
    required this.duration,
  });

  final String activityId;
  final String activityLabel;
  final int activityColor;
  final String? primaryCategoryId;
  final String? primaryCategoryLabel;
  final int? primaryCategoryColor;
  final Set<String> linkedCategoryIds;
  final Duration duration;

  String get durationBucketLabel {
    if (duration < const Duration(minutes: 30)) {
      return '<30m';
    }
    if (duration < const Duration(hours: 1)) {
      return '30m-1h';
    }
    if (duration < const Duration(hours: 3)) {
      return '1-3h';
    }
    return '3h+';
  }

  int get durationBucketColor {
    return switch (durationBucketLabel) {
      '<30m' => 0xff94a3b8,
      '30m-1h' => 0xff0ea5e9,
      '1-3h' => 0xff7c3aed,
      _ => 0xffdc2626,
    };
  }
}

class _StatsGroupKey {
  const _StatsGroupKey({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final int color;
}

class _StatsGroupBuilder {
  _StatsGroupBuilder({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final int color;
  var totalDuration = Duration.zero;
  var count = 0;

  void add(Duration duration) {
    totalDuration += duration;
    count += 1;
  }

  StatsGroupRow toRow() {
    return StatsGroupRow(
      id: id,
      label: label,
      totalDuration: totalDuration,
      count: count,
      color: color,
    );
  }
}
