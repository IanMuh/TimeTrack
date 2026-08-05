import '../app/app_state.dart';
import '../domain/activity.dart';

class TodaySummary {
  const TodaySummary({
    required this.totalDuration,
    required this.sessionCount,
    required this.focusDuration,
    required this.breakDuration,
    required this.activities,
  });

  final Duration totalDuration;
  final int sessionCount;
  final Duration focusDuration;
  final Duration breakDuration;
  final List<TodayActivityTotal> activities;

  factory TodaySummary.fromState(AppState state, DateTime now) {
    final entries = [
      for (final entry in state.dayEntries)
        if (!entry.isDeleted) entry,
    ];
    final grouped = <String, _ActivityAccumulator>{};
    var totalDuration = Duration.zero;
    var favoriteDuration = Duration.zero;
    var breakDuration = Duration.zero;

    for (final entry in entries) {
      final duration = entry.durationUntil(now);
      if (duration == Duration.zero) {
        continue;
      }
      final activity = state.activityById(entry.activityId);
      final name = state.activityNameForEntry(entry);
      final color = state.activityColorForEntry(entry);
      final key = '${entry.activityId}|$name|$color';
      grouped
          .putIfAbsent(key, () => _ActivityAccumulator(name, color))
          .add(duration);
      totalDuration += duration;

      if (_isBreakLike(name, activity)) {
        breakDuration += duration;
      } else if (activity?.isFavorite ?? false) {
        favoriteDuration += duration;
      }
    }

    final focusDuration = favoriteDuration == Duration.zero
        ? totalDuration - breakDuration
        : favoriteDuration;
    final activities = grouped.values
        .map((activity) => activity.toTotal(totalDuration))
        .toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));

    return TodaySummary(
      totalDuration: totalDuration,
      sessionCount: entries.length,
      focusDuration: focusDuration,
      breakDuration: breakDuration,
      activities: activities.take(5).toList(),
    );
  }
}

class TodayActivityTotal {
  const TodayActivityTotal({
    required this.name,
    required this.color,
    required this.duration,
    required this.percent,
  });

  final String name;
  final int color;
  final Duration duration;
  final int percent;
}

class _ActivityAccumulator {
  _ActivityAccumulator(this.name, this.color);

  final String name;
  final int color;
  Duration duration = Duration.zero;

  void add(Duration value) {
    duration += value;
  }

  TodayActivityTotal toTotal(Duration totalDuration) {
    final percent = totalDuration == Duration.zero
        ? 0
        : (duration.inSeconds / totalDuration.inSeconds * 100).round();
    return TodayActivityTotal(
      name: name,
      color: color,
      duration: duration,
      percent: percent,
    );
  }
}

bool _isBreakLike(String name, Activity? activity) {
  if (activity?.isUnassigned ?? false) {
    return true;
  }
  final normalized = name.toLowerCase();
  return normalized.contains('break') ||
      normalized.contains('rest') ||
      normalized.contains('personal') ||
      normalized.contains('admin') ||
      normalized.contains('休息') ||
      normalized.contains('个人') ||
      normalized.contains('未安排');
}
