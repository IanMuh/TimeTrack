import '../data/repository_undo.dart';
import '../domain/activity.dart';
import 'activity_state.dart';
import 'undo_state.dart';

typedef ActiveEntryUndoScopeBuilder = RepositoryUndoScope Function();
typedef ActivityCategoryAssigner = Future<void> Function({
  required String activityId,
  required String? primaryCategoryId,
  required List<String> secondaryCategoryIds,
});
typedef ActivitySwitcher = Future<void> Function(Activity activity);
typedef CurrentActivityStopper = Future<void> Function();
typedef ActivityCreator = Future<Activity> Function(String name, int color);
typedef OneOffActivitySuggestionLoader = Future<List<Activity>> Function();
typedef OneOffActivityCreator = Future<Activity> Function(
  String name,
  int color, {
  Activity? reuseActivity,
});
typedef EntryActivityCreator = Future<Activity> Function(
  String name,
  int color, {
  required bool isOneOff,
  Activity? reuseActivity,
});
typedef ActivityUpdater = Future<Activity> Function(
  Activity activity, {
  required String name,
  required int color,
});
typedef ActivityDeleter = Future<void> Function(Activity activity);
typedef EntryActivityChoiceLoader = Future<List<Activity>> Function();

class ActivityMutationState {
  ActivityMutationState({
    required ActivityState activityState,
    required UndoableRecorder recordUndoable,
    required ActiveEntryUndoScopeBuilder activeEntryUndoScope,
    required ActivityCategoryAssigner setActivityCategories,
  }) : this.withHandlers(
          recordUndoable: recordUndoable,
          activeEntryUndoScope: activeEntryUndoScope,
          setActivityCategories: setActivityCategories,
          switchTo: activityState.switchTo,
          stopCurrent: activityState.stopCurrent,
          createActivity: activityState.createActivity,
          oneOffActivitySuggestions: activityState.oneOffActivitySuggestions,
          createOneOffActivity: activityState.createOneOffActivity,
          createEntryActivity: activityState.createEntryActivity,
          updateActivity: activityState.updateActivity,
          deleteActivity: activityState.deleteActivity,
          entryActivityChoices: activityState.entryActivityChoices,
        );

  ActivityMutationState.withHandlers({
    required UndoableRecorder recordUndoable,
    required ActiveEntryUndoScopeBuilder activeEntryUndoScope,
    required ActivityCategoryAssigner setActivityCategories,
    required ActivitySwitcher switchTo,
    required CurrentActivityStopper stopCurrent,
    required ActivityCreator createActivity,
    required OneOffActivitySuggestionLoader oneOffActivitySuggestions,
    required OneOffActivityCreator createOneOffActivity,
    required EntryActivityCreator createEntryActivity,
    required ActivityUpdater updateActivity,
    required ActivityDeleter deleteActivity,
    required EntryActivityChoiceLoader entryActivityChoices,
  })  : _recordUndoable = recordUndoable,
        _activeEntryUndoScope = activeEntryUndoScope,
        _setActivityCategories = setActivityCategories,
        _switchTo = switchTo,
        _stopCurrent = stopCurrent,
        _createActivity = createActivity,
        _oneOffActivitySuggestions = oneOffActivitySuggestions,
        _createOneOffActivity = createOneOffActivity,
        _createEntryActivity = createEntryActivity,
        _updateActivity = updateActivity,
        _deleteActivity = deleteActivity,
        _entryActivityChoices = entryActivityChoices;

  final UndoableRecorder _recordUndoable;
  final ActiveEntryUndoScopeBuilder _activeEntryUndoScope;
  final ActivityCategoryAssigner _setActivityCategories;
  final ActivitySwitcher _switchTo;
  final CurrentActivityStopper _stopCurrent;
  final ActivityCreator _createActivity;
  final OneOffActivitySuggestionLoader _oneOffActivitySuggestions;
  final OneOffActivityCreator _createOneOffActivity;
  final EntryActivityCreator _createEntryActivity;
  final ActivityUpdater _updateActivity;
  final ActivityDeleter _deleteActivity;
  final EntryActivityChoiceLoader _entryActivityChoices;

  Future<void> switchTo(Activity activity) async {
    await _recordUndoable('切换到 ${activity.name}', () async {
      await _switchTo(activity);
    }, undoScope: _activeEntryUndoScope());
  }

  Future<void> stopCurrent() async {
    await _recordUndoable('停止当前事项', () async {
      await _stopCurrent();
    }, undoScope: _activeEntryUndoScope());
  }

  Future<Activity> createActivity(
    String name,
    int color, {
    String? primaryCategoryId,
    List<String> secondaryCategoryIds = const [],
  }) async {
    return _recordUndoable('新增事项', () async {
      final activity = await _createActivity(name, color);
      if (primaryCategoryId != null || secondaryCategoryIds.isNotEmpty) {
        await _setActivityCategories(
          activityId: activity.id,
          primaryCategoryId: primaryCategoryId,
          secondaryCategoryIds: secondaryCategoryIds,
        );
      }
      return activity;
    });
  }

  Future<List<Activity>> oneOffActivitySuggestions() {
    return _oneOffActivitySuggestions();
  }

  Future<Activity> createOneOffActivity(
    String name,
    int color, {
    Activity? reuseActivity,
  }) async {
    return _recordUndoable('开始临时事项', () async {
      return _createOneOffActivity(
        name,
        color,
        reuseActivity: reuseActivity,
      );
    }, undoScope: _activeEntryUndoScope());
  }

  Future<Activity> createEntryActivity(
    String name,
    int color, {
    required bool isOneOff,
    Activity? reuseActivity,
    String? primaryCategoryId,
    List<String> secondaryCategoryIds = const [],
  }) async {
    return _recordUndoable('新增事项', () async {
      final activity = await _createEntryActivity(
        name,
        color,
        isOneOff: isOneOff,
        reuseActivity: reuseActivity,
      );
      if (!isOneOff &&
          (primaryCategoryId != null || secondaryCategoryIds.isNotEmpty)) {
        await _setActivityCategories(
          activityId: activity.id,
          primaryCategoryId: primaryCategoryId,
          secondaryCategoryIds: secondaryCategoryIds,
        );
      }
      return activity;
    });
  }

  Future<Activity> updateActivity(
    Activity activity, {
    required String name,
    required int color,
    bool updateCategories = false,
    String? primaryCategoryId,
    List<String> secondaryCategoryIds = const [],
  }) async {
    return _recordUndoable('编辑事项', () async {
      final updated = await _updateActivity(
        activity,
        name: name,
        color: color,
      );
      if (updateCategories) {
        await _setActivityCategories(
          activityId: updated.id,
          primaryCategoryId: primaryCategoryId,
          secondaryCategoryIds: secondaryCategoryIds,
        );
      }
      return updated;
    });
  }

  Future<void> deleteActivity(Activity activity) async {
    await _recordUndoable('删除事项', () async {
      await _deleteActivity(activity);
    });
  }

  Future<List<Activity>> entryActivityChoices() {
    return _entryActivityChoices();
  }
}
