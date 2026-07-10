part of 'app_state.dart';

mixin AppStateActivityMutationFacade on ChangeNotifier {
  ActivityMutationState get _activityMutationState;

  Future<void> switchTo(Activity activity) {
    return _activityMutationState.switchTo(activity);
  }

  Future<void> stopCurrent() {
    return _activityMutationState.stopCurrent();
  }

  Future<Activity> createActivity(
    String name,
    int color, {
    String? primaryCategoryId,
    List<String> secondaryCategoryIds = const [],
  }) {
    return _activityMutationState.createActivity(
      name,
      color,
      primaryCategoryId: primaryCategoryId,
      secondaryCategoryIds: secondaryCategoryIds,
    );
  }

  Future<List<Activity>> oneOffActivitySuggestions() {
    return _activityMutationState.oneOffActivitySuggestions();
  }

  Future<Activity> createOneOffActivity(
    String name,
    int color, {
    Activity? reuseActivity,
  }) {
    return _activityMutationState.createOneOffActivity(
      name,
      color,
      reuseActivity: reuseActivity,
    );
  }

  Future<Activity> createEntryActivity(
    String name,
    int color, {
    required bool isOneOff,
    Activity? reuseActivity,
    String? primaryCategoryId,
    List<String> secondaryCategoryIds = const [],
  }) {
    return _activityMutationState.createEntryActivity(
      name,
      color,
      isOneOff: isOneOff,
      reuseActivity: reuseActivity,
      primaryCategoryId: primaryCategoryId,
      secondaryCategoryIds: secondaryCategoryIds,
    );
  }

  Future<Activity> updateActivity(
    Activity activity, {
    required String name,
    required int color,
    bool updateCategories = false,
    String? primaryCategoryId,
    List<String> secondaryCategoryIds = const [],
  }) {
    return _activityMutationState.updateActivity(
      activity,
      name: name,
      color: color,
      updateCategories: updateCategories,
      primaryCategoryId: primaryCategoryId,
      secondaryCategoryIds: secondaryCategoryIds,
    );
  }

  Future<void> deleteActivity(Activity activity) {
    return _activityMutationState.deleteActivity(activity);
  }

  Future<List<Activity>> entryActivityChoices() {
    return _activityMutationState.entryActivityChoices();
  }
}
