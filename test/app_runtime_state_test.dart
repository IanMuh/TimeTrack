import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/app_runtime_state.dart';

void main() {
  test('runtime state stores loading and error message', () {
    final state = AppRuntimeState();

    expect(state.isLoading, isTrue);
    expect(state.errorMessage, isNull);

    state
      ..isLoading = false
      ..errorMessage = 'failed';

    expect(state.isLoading, isFalse);
    expect(state.errorMessage, 'failed');
  });

  test('AppState runtime facade owns loading and error accessors', () {
    final appState = File('lib/app/app_state.dart');
    final runtimeFacade = File('lib/app/app_state_runtime_facade.dart');

    expect(runtimeFacade.existsSync(), isTrue);

    final appStateSource = appState.readAsStringSync();
    final runtimeSource = runtimeFacade.readAsStringSync();

    expect(runtimeSource, contains('AppRuntimeState get _runtimeState'));
    expect(runtimeSource, contains('bool get isLoading'));
    expect(runtimeSource, contains('set isLoading(bool value)'));
    expect(runtimeSource, contains('String? get errorMessage'));
    expect(runtimeSource, contains('set errorMessage(String? value)'));
    expect(runtimeSource, contains('ActivityState get _activityState'));
    expect(runtimeSource, contains('EntryState get _entryState'));
    expect(runtimeSource, contains('LanState get _lanState'));
    expect(runtimeSource, contains('void _onSubStateChanged()'));
    expect(runtimeSource, contains('void dispose()'));
    expect(appStateSource, isNot(contains('bool isLoading = true;')));
    expect(appStateSource, isNot(contains('String? errorMessage;')));
    expect(appStateSource, isNot(contains('void dispose()')));
  });

  test('AppState shell passes refresh callbacks without wrapper methods', () {
    final appStateSource = File('lib/app/app_state.dart').readAsStringSync();
    final factorySource =
        File('lib/app/app_state_module_factory.dart').readAsStringSync();

    expect(factorySource, contains('onFullRefresh: appState.refresh'));
    expect(
        factorySource, contains('onDailyRefresh: appState._refreshDailyData'));
    expect(
      appStateSource,
      isNot(contains('Future<void> _onFullRefresh()')),
    );
    expect(
      appStateSource,
      isNot(contains('Future<void> _onDailyRefresh()')),
    );
  });

  test('AppState runtime facade owns sub-state listener lifecycle', () {
    final appStateSource = File('lib/app/app_state.dart').readAsStringSync();
    final runtimeSource =
        File('lib/app/app_state_runtime_facade.dart').readAsStringSync();

    expect(runtimeSource, contains('void _bindSubStateListeners()'));
    expect(
      runtimeSource,
      contains('void _onSubStateChanged() => _notifyStateListeners();'),
    );
    expect(runtimeSource, contains('void _notifyStateListeners()'));
    expect(appStateSource, contains('_bindSubStateListeners();'));
    expect(
      appStateSource,
      isNot(contains('_activityState.addListener(_onSubStateChanged)')),
    );
    expect(
      appStateSource,
      isNot(contains('_entryState.addListener(_onSubStateChanged)')),
    );
    expect(
      appStateSource,
      isNot(contains('void _onSubStateChanged()')),
    );
  });

  test('AppState shell delegates module assembly to modules builder', () {
    final appStateSource = File('lib/app/app_state.dart').readAsStringSync();
    final modulesSource =
        File('lib/app/app_state_module_factory.dart').readAsStringSync();

    expect(modulesSource, contains('AppStateModules buildAppStateModules({'));
    expect(
      appStateSource,
      contains('_modules = buildAppStateModules('),
    );
    expect(appStateSource, isNot(contains('_modules = AppStateModules(')));
    expect(appStateSource, isNot(contains('onFullRefresh: refresh')));
    expect(
      appStateSource,
      isNot(
        contains(
          'shouldStartLanServer: () => '
          'Platform.isWindows && !isLanServerRunning',
        ),
      ),
    );
    expect(
      appStateSource,
      isNot(contains('setInteropMessage: (message)')),
    );
    expect(modulesSource,
        contains('notifyListeners: appState._notifyStateListeners'));
    expect(
      modulesSource,
      isNot(contains('notifyListeners: appState.notifyListeners')),
    );
  });

  test('AppState module factory lives outside the module container', () {
    final appStateSource = File('lib/app/app_state.dart').readAsStringSync();
    final modulesFile = File('lib/app/app_state_modules.dart');
    final factoryFile = File('lib/app/app_state_module_factory.dart');

    expect(factoryFile.existsSync(), isTrue);
    expect(appStateSource, contains("part 'app_state_module_factory.dart';"));

    final modulesSource = modulesFile.readAsStringSync();
    final factorySource = factoryFile.readAsStringSync();
    final modulePureLineCount = modulesSource.split('\n').where((line) {
      final trimmed = line.trim();
      return trimmed.isNotEmpty &&
          !trimmed.startsWith('//') &&
          !trimmed.startsWith('#') &&
          !trimmed.startsWith('--');
    }).length;

    expect(modulePureLineCount, lessThanOrEqualTo(250));
    expect(
      modulesSource,
      isNot(contains('factory AppStateModules.forAppState({')),
    );
    expect(factorySource, contains('AppStateModules buildAppStateModules({'));
    expect(factorySource, contains('required AppState appState'));
    expect(factorySource, contains('return AppStateModules('));
    expect(appStateSource, contains('_modules = buildAppStateModules('));
    expect(appStateSource, isNot(contains('AppStateModules.forAppState(')));
  });

  test('AppStateModules constructor receives aggregate inputs', () {
    final appStateSource = File('lib/app/app_state.dart').readAsStringSync();
    final modulesSource =
        File('lib/app/app_state_modules.dart').readAsStringSync();
    final inputsFile = File('lib/app/app_state_module_inputs.dart');
    final factorySource =
        File('lib/app/app_state_module_factory.dart').readAsStringSync();

    expect(inputsFile.existsSync(), isTrue);
    expect(appStateSource, contains("part 'app_state_module_inputs.dart';"));
    expect(
      inputsFile.readAsStringSync(),
      contains('final class AppStateModuleInputs'),
    );
    expect(
      modulesSource,
      contains('AppStateModules(AppStateModuleInputs inputs)'),
    );
    expect(
      modulesSource,
      isNot(contains('required IActivityCatalogRepository activityCatalog')),
    );
    expect(
      modulesSource,
      isNot(contains('required Future<void> Function() onFullRefresh')),
    );
    expect(
      factorySource,
      contains('final inputs = AppStateModuleInputs('),
    );
    expect(factorySource, contains('return AppStateModules(inputs);'));
  });

  test('AppState constructor receives focused repository dependencies', () {
    final appStateSource = File('lib/app/app_state.dart').readAsStringSync();
    final dependenciesSource =
        File('lib/app/app_dependencies.dart').readAsStringSync();
    final factorySource =
        File('lib/app/app_state_module_factory.dart').readAsStringSync();
    final inputsSource =
        File('lib/app/app_state_module_inputs.dart').readAsStringSync();

    for (final expected in [
      'required IActivityCatalogRepository activityCatalog',
      'required IActivityCommandRepository activityCommands',
      'required ITimeEntryQueryRepository entryQueries',
      'required ITimeEntryCommandRepository entryCommands',
    ]) {
      expect(appStateSource, contains(expected));
      expect(factorySource, contains(expected));
    }

    expect(appStateSource, isNot(contains('required IActivityRepository')));
    expect(appStateSource, isNot(contains('required ITimeEntryRepository')));
    expect(inputsSource, contains('final IActivityCatalogRepository'));
    expect(inputsSource, contains('final IActivityCommandRepository'));
    expect(inputsSource, contains('final ITimeEntryQueryRepository'));
    expect(inputsSource, contains('final ITimeEntryCommandRepository'));
    expect(
      dependenciesSource,
      contains('activityCatalog: container<ActivityRepository>()'),
    );
    expect(
      dependenciesSource,
      contains('activityCommands: container<ActivityRepository>()'),
    );
    expect(
      dependenciesSource,
      contains('entryQueries: container<TimeEntryRepository>()'),
    );
    expect(
      dependenciesSource,
      contains('entryCommands: container<TimeEntryRepository>()'),
    );
  });
}
