import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/activity_mutation_state.dart';
import 'package:timetrack/data/repository_undo.dart';
import 'package:timetrack/domain/activity.dart';

void main() {
  test('AppState activity mutation facade stays separate', () {
    final mutationFacade =
        File('lib/app/app_state_activity_mutation_facade.dart');
    final activityFacade = File('lib/app/app_state_activity_facade.dart');

    expect(mutationFacade.existsSync(), isTrue);

    final mutationSource = mutationFacade.readAsStringSync();
    final activitySource = activityFacade.readAsStringSync();

    expect(mutationSource, contains('mixin AppStateActivityMutationFacade'));
    expect(
        mutationSource, contains('Future<void> switchTo(Activity activity)'));
    expect(mutationSource, contains('Future<void> stopCurrent()'));
    expect(mutationSource, contains('Future<Activity> createActivity('));
    expect(mutationSource, contains('Future<Activity> createOneOffActivity('));
    expect(mutationSource, contains('Future<Activity> createEntryActivity('));
    expect(mutationSource, contains('Future<Activity> updateActivity('));
    expect(mutationSource, contains('Future<void> deleteActivity('));
    expect(
      mutationSource,
      contains('Future<List<Activity>> entryActivityChoices()'),
    );
    expect(activitySource, isNot(contains('Future<void> switchTo(')));
    expect(activitySource, isNot(contains('Future<void> stopCurrent()')));
    expect(activitySource, isNot(contains('Future<Activity> createActivity(')));
    expect(
      activitySource,
      isNot(contains('Future<Activity> createOneOffActivity(')),
    );
    expect(
      activitySource,
      isNot(contains('Future<Activity> createEntryActivity(')),
    );
    expect(activitySource, isNot(contains('Future<Activity> updateActivity(')));
    expect(activitySource, isNot(contains('Future<void> deleteActivity(')));
    expect(
      activitySource,
      isNot(contains('Future<List<Activity>> entryActivityChoices()')),
    );
  });

  test('switchTo and stopCurrent record labels with active entry scope',
      () async {
    final activity = _activity(name: 'Focus');
    final harness = _Harness();

    await harness.state.switchTo(activity);
    await harness.state.stopCurrent();

    expect(harness.labels, ['切换到 Focus', '停止当前事项']);
    expect(harness.scopes, [harness.activeScope, harness.activeScope]);
    expect(harness.activeScopeCalls, 2);
    expect(harness.switchedActivities, [activity]);
    expect(harness.stopCount, 1);
  });

  test('createActivity records undo and assigns categories when requested',
      () async {
    final harness = _Harness(activityToCreate: _activity(id: 'created'));

    final activity = await harness.state.createActivity(
      'Deep Work',
      0xff2563eb,
      primaryCategoryId: 'primary',
      secondaryCategoryIds: ['secondary'],
    );

    expect(activity.id, 'created');
    expect(harness.labels, ['新增事项']);
    expect(harness.scopes.single, isNull);
    expect(harness.createCalls, [('Deep Work', 0xff2563eb)]);
    final categoryCall = harness.categoryCalls.single;
    expect(categoryCall.activityId, 'created');
    expect(categoryCall.primaryCategoryId, 'primary');
    expect(categoryCall.secondaryCategoryIds, ['secondary']);

    final emptyHarness = _Harness(activityToCreate: _activity(id: 'plain'));
    await emptyHarness.state.createActivity('Plain', 0xff334155);

    expect(emptyHarness.categoryCalls, isEmpty);
  });

  test('entry activity categories are skipped for one-off activities',
      () async {
    final harness = _Harness(
      activityToCreate: _activity(id: 'normal'),
      entryActivityToCreate: _activity(id: 'entry'),
    );

    await harness.state.createOneOffActivity(
      'One-off',
      0xfff97316,
      reuseActivity: _activity(id: 'reuse'),
    );
    await harness.state.createEntryActivity(
      'Entry',
      0xff14b8a6,
      isOneOff: false,
      primaryCategoryId: 'primary',
      secondaryCategoryIds: ['secondary'],
    );
    await harness.state.createEntryActivity(
      'Skipped',
      0xff8b5cf6,
      isOneOff: true,
      primaryCategoryId: 'primary',
      secondaryCategoryIds: ['secondary'],
    );

    expect(harness.labels, ['开始临时事项', '新增事项', '新增事项']);
    expect(harness.scopes.first, harness.activeScope);
    expect(harness.scopes.skip(1), [null, null]);
    expect(harness.activeScopeCalls, 1);
    expect(harness.oneOffCreateCalls.single.name, 'One-off');
    expect(harness.entryCreateCalls.map((call) => call.isOneOff), [
      false,
      true,
    ]);
    expect(harness.categoryCalls.single.activityId, 'entry');
  });

  test(
      'updateActivity conditionally assigns categories and delete records undo',
      () async {
    final activity = _activity(id: 'activity');
    final updated = activity.copyWith(id: 'updated');
    final harness = _Harness(activityToUpdate: updated);

    final result = await harness.state.updateActivity(
      activity,
      name: 'Updated',
      color: 0xff0f172a,
      updateCategories: true,
      primaryCategoryId: null,
      secondaryCategoryIds: ['secondary'],
    );
    await harness.state.deleteActivity(activity);

    expect(result, updated);
    expect(harness.labels, ['编辑事项', '删除事项']);
    expect(harness.scopes, [null, null]);
    expect(harness.updateCalls.single.name, 'Updated');
    expect(harness.deletedActivities, [activity]);
    final categoryCall = harness.categoryCalls.single;
    expect(categoryCall.activityId, 'updated');
    expect(categoryCall.primaryCategoryId, isNull);
    expect(categoryCall.secondaryCategoryIds, ['secondary']);
  });

  test('suggestions and choices forward without undo recording', () async {
    final suggestion = _activity(id: 'suggestion');
    final choice = _activity(id: 'choice');
    final harness = _Harness(
      suggestions: [suggestion],
      choices: [choice],
    );

    final suggestions = await harness.state.oneOffActivitySuggestions();
    final choices = await harness.state.entryActivityChoices();

    expect(suggestions, [suggestion]);
    expect(choices, [choice]);
    expect(harness.labels, isEmpty);
    expect(harness.scopes, isEmpty);
  });
}

class _Harness {
  _Harness({
    Activity? activityToCreate,
    Activity? entryActivityToCreate,
    Activity? activityToUpdate,
    this.suggestions = const [],
    this.choices = const [],
  })  : activityToCreate =
            activityToCreate ?? _activity(id: 'created-activity'),
        entryActivityToCreate =
            entryActivityToCreate ?? _activity(id: 'entry-activity'),
        activityToUpdate = activityToUpdate ?? _activity(id: 'updated') {
    state = ActivityMutationState.withHandlers(
      recordUndoable: recordUndoable,
      activeEntryUndoScope: activeEntryUndoScope,
      setActivityCategories: setActivityCategories,
      switchTo: (activity) async {
        switchedActivities.add(activity);
      },
      stopCurrent: () async {
        stopCount += 1;
      },
      createActivity: (name, color) async {
        createCalls.add((name, color));
        return this.activityToCreate;
      },
      oneOffActivitySuggestions: () async => suggestions,
      createOneOffActivity: (name, color, {reuseActivity}) async {
        oneOffCreateCalls.add((
          name: name,
          color: color,
          reuseActivity: reuseActivity,
        ));
        return this.activityToCreate;
      },
      createEntryActivity: (
        name,
        color, {
        required isOneOff,
        reuseActivity,
      }) async {
        entryCreateCalls.add((
          name: name,
          color: color,
          isOneOff: isOneOff,
          reuseActivity: reuseActivity,
        ));
        return this.entryActivityToCreate;
      },
      updateActivity: (activity, {required name, required color}) async {
        updateCalls.add((
          activity: activity,
          name: name,
          color: color,
        ));
        return this.activityToUpdate;
      },
      deleteActivity: (activity) async {
        deletedActivities.add(activity);
      },
      entryActivityChoices: () async => choices,
    );
  }

  final Activity activityToCreate;
  final Activity entryActivityToCreate;
  final Activity activityToUpdate;
  final List<Activity> suggestions;
  final List<Activity> choices;
  late final ActivityMutationState state;

  final activeScope = RepositoryUndoScope(
    entryWindows: [
      RepositoryUndoWindow.forLocalDay(DateTime(2026, 1, 2)),
    ],
  );
  final labels = <String>[];
  final scopes = <RepositoryUndoScope?>[];
  final switchedActivities = <Activity>[];
  final createCalls = <(String, int)>[];
  final oneOffCreateCalls =
      <({String name, int color, Activity? reuseActivity})>[];
  final entryCreateCalls =
      <({String name, int color, bool isOneOff, Activity? reuseActivity})>[];
  final updateCalls = <({Activity activity, String name, int color})>[];
  final deletedActivities = <Activity>[];
  final categoryCalls = <({
    String activityId,
    String? primaryCategoryId,
    List<String> secondaryCategoryIds,
  })>[];
  int activeScopeCalls = 0;
  int stopCount = 0;

  Future<T> recordUndoable<T>(
    String label,
    Future<T> Function() action, {
    bool syncAfter = true,
    RepositoryUndoScope? undoScope,
  }) async {
    labels.add(label);
    scopes.add(undoScope);
    return action();
  }

  RepositoryUndoScope activeEntryUndoScope() {
    activeScopeCalls += 1;
    return activeScope;
  }

  Future<void> setActivityCategories({
    required String activityId,
    required String? primaryCategoryId,
    required List<String> secondaryCategoryIds,
  }) async {
    categoryCalls.add((
      activityId: activityId,
      primaryCategoryId: primaryCategoryId,
      secondaryCategoryIds: secondaryCategoryIds,
    ));
  }
}

Activity _activity({
  String id = 'activity',
  String name = 'Activity',
  int color = 0xff2563eb,
  bool isOneOff = false,
}) {
  return Activity(
    id: id,
    userId: null,
    name: name,
    color: color,
    isFavorite: false,
    updatedAt: DateTime(2026, 1, 2),
    isDeleted: false,
    isOneOff: isOneOff,
  );
}
