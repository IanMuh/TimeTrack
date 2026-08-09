import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:timetrack/data/file_interop_service.dart';
import 'package:timetrack/data/sync_bundle.dart';
import 'package:timetrack/data/sync_bundle_store.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/domain/profile_settings.dart';
import 'test_fixtures.dart';

Future<TestRepositoryFixture> buildFileInteropFixture() async {
  final fixture = await buildTestRepositoryFixture();
  final repository = fixture.repository;
  final activity = (await repository.activities()).first;
  await repository.createManualEntry(
    activityId: activity.id,
    startAt: DateTime(2026, 1, 1, 9),
    endAt: DateTime(2026, 1, 1, 10),
    note: 'export me',
  );
  return fixture;
}

void main() {
  test('file export only requires a sync bundle store', () async {
    final exportDir =
        await Directory.systemTemp.createTemp('timetrack-export-');
    addTearDown(() => exportDir.delete(recursive: true));
    final exportPath = p.join(exportDir.path, 'narrow-store.timetrack.json');
    final bundleStore = _FakeSyncBundleStore(_emptyBundle('narrow-store'));

    final service = FileInteropService(
      bundleStore: bundleStore,
      saveLocationPicker: ({
        List<XTypeGroup> acceptedTypeGroups = const <XTypeGroup>[],
        String? suggestedName,
      }) async {
        return FileSaveLocation(exportPath);
      },
    );

    final path = await service.exportToFile();

    expect(path, exportPath);
    expect(bundleStore.exportCount, 1);
    expect(await File(exportPath).readAsString(), contains('narrow-store'));
  });

  test('file export writes to save dialog path when available', () async {
    final fixture = await buildFileInteropFixture();
    addTearDown(fixture.close);
    final exportDir =
        await Directory.systemTemp.createTemp('timetrack-export-');
    addTearDown(() => exportDir.delete(recursive: true));
    final exportPath = p.join(exportDir.path, 'chosen.timetrack.json');
    var directoryPickerCalled = false;

    final service = FileInteropService(
      bundleStore: fixture.syncBundleRepository,
      saveLocationPicker: ({
        List<XTypeGroup> acceptedTypeGroups = const <XTypeGroup>[],
        String? suggestedName,
      }) async {
        return FileSaveLocation(exportPath);
      },
      exportDirectoryPicker: ({
        String? initialDirectory,
        String? confirmButtonText,
        bool? canCreateDirectories,
      }) async {
        directoryPickerCalled = true;
        return exportDir.path;
      },
    );

    final path = await service.exportToFile();

    expect(path, exportPath);
    expect(directoryPickerCalled, isFalse);
    expect(await File(exportPath).readAsString(), contains('export me'));
  });

  test('file export uses directory picker when save dialog is unavailable',
      () async {
    final fixture = await buildFileInteropFixture();
    addTearDown(fixture.close);
    final exportDir =
        await Directory.systemTemp.createTemp('timetrack-export-');
    addTearDown(() => exportDir.delete(recursive: true));
    String? pickedConfirmButtonText;
    bool? pickedCanCreateDirectories;

    final service = FileInteropService(
      bundleStore: fixture.syncBundleRepository,
      saveLocationPicker: ({
        List<XTypeGroup> acceptedTypeGroups = const <XTypeGroup>[],
        String? suggestedName,
      }) async {
        throw UnimplementedError('getSavePath() has not been implemented.');
      },
      exportDirectoryPicker: ({
        String? initialDirectory,
        String? confirmButtonText,
        bool? canCreateDirectories,
      }) async {
        pickedConfirmButtonText = confirmButtonText;
        pickedCanCreateDirectories = canCreateDirectories;
        return exportDir.path;
      },
      exportDirectoryProvider: () async {
        throw StateError('default directory should not be used');
      },
    );

    final path = await service.exportToFile();

    expect(path, isNotNull);
    expect(path, startsWith(exportDir.path));
    expect(pickedConfirmButtonText, '选择导出位置');
    expect(pickedCanCreateDirectories, isTrue);
    expect(await File(path!).readAsString(), contains('export me'));
  });

  test('file export cancels when fallback directory picker is cancelled',
      () async {
    final fixture = await buildFileInteropFixture();
    addTearDown(fixture.close);
    var directoryPickerCalled = false;

    final service = FileInteropService(
      bundleStore: fixture.syncBundleRepository,
      saveLocationPicker: ({
        List<XTypeGroup> acceptedTypeGroups = const <XTypeGroup>[],
        String? suggestedName,
      }) async {
        throw UnimplementedError('getSavePath() has not been implemented.');
      },
      exportDirectoryPicker: ({
        String? initialDirectory,
        String? confirmButtonText,
        bool? canCreateDirectories,
      }) async {
        directoryPickerCalled = true;
        return null;
      },
      exportDirectoryProvider: () async {
        throw StateError('default directory should not be used after cancel');
      },
    );

    final path = await service.exportToFile();

    expect(path, isNull);
    expect(directoryPickerCalled, isTrue);
  });

  test('file export falls back to app documents when all pickers unavailable',
      () async {
    final fixture = await buildFileInteropFixture();
    addTearDown(fixture.close);
    final exportDir =
        await Directory.systemTemp.createTemp('timetrack-export-');
    addTearDown(() => exportDir.delete(recursive: true));

    final service = FileInteropService(
      bundleStore: fixture.syncBundleRepository,
      saveLocationPicker: ({
        List<XTypeGroup> acceptedTypeGroups = const <XTypeGroup>[],
        String? suggestedName,
      }) async {
        throw UnimplementedError('getSavePath() has not been implemented.');
      },
      exportDirectoryPicker: ({
        String? initialDirectory,
        String? confirmButtonText,
        bool? canCreateDirectories,
      }) async {
        throw UnimplementedError(
            'getDirectoryPath() has not been implemented.');
      },
      exportDirectoryProvider: () async => exportDir,
    );

    final path = await service.exportToFile();

    expect(path, isNotNull);
    expect(path, startsWith(exportDir.path));
    expect(await File(path!).readAsString(), contains('export me'));
  });

  test('file import reads the selected bundle and merges it', () async {
    final importDir =
        await Directory.systemTemp.createTemp('timetrack-import-');
    addTearDown(() => importDir.delete(recursive: true));
    final importPath = p.join(importDir.path, 'chosen.timetrack.json');
    final bundle = _emptyBundle('import-source');
    await File(importPath)
        .writeAsString(const SyncBundleCodec().encode(bundle));
    final bundleStore = _FakeSyncBundleStore(bundle);

    final service = FileInteropService(
      bundleStore: bundleStore,
      openFilePicker: ({
        List<XTypeGroup> acceptedTypeGroups = const <XTypeGroup>[],
      }) async {
        return XFile(importPath);
      },
    );

    final path = await service.importFromFile();

    expect(path, importPath);
    expect(bundleStore.mergedBundle?.sourceDeviceId, 'import-source');
  });

  test('file import decodes Android picker bytes as UTF-8 before merging',
      () async {
    const activityName = '学习中文';
    final bundle = SyncBundle(
      schemaVersion: SyncBundle.currentSchemaVersion,
      exportedAt: DateTime(2026, 1, 1),
      sourceDeviceId: 'android-picker',
      activities: [
        Activity(
          id: 'activity-1',
          userId: null,
          name: activityName,
          color: 0xFF2F80ED,
          isFavorite: true,
          updatedAt: DateTime(2026, 1, 1),
          isDeleted: false,
        ),
      ],
      timeEntries: const [],
      actionLogs: const [],
      profileSettings: ProfileSettings.defaults(),
    );
    final bytes = Uint8List.fromList(
      utf8.encode(const SyncBundleCodec().encode(bundle)),
    );
    final bundleStore = _FakeSyncBundleStore(_emptyBundle('unused'));

    final service = FileInteropService(
      bundleStore: bundleStore,
      openFilePicker: ({
        List<XTypeGroup> acceptedTypeGroups = const <XTypeGroup>[],
      }) async {
        return XFile.fromData(
          bytes,
          name: 'android.timetrack.json',
          path: 'android.timetrack.json',
        );
      },
    );

    final path = await service.importFromFile();

    expect(path, 'android.timetrack.json');
    expect(bundleStore.mergedBundle?.activities.single.name, activityName);
  });

  test('file import rejects invalid bundle data before merging', () async {
    final importDir =
        await Directory.systemTemp.createTemp('timetrack-import-invalid-');
    addTearDown(() => importDir.delete(recursive: true));
    final importPath = p.join(importDir.path, 'invalid.timetrack.json');
    await File(importPath).writeAsString('[]');
    final bundleStore = _FakeSyncBundleStore(_emptyBundle('unused'));

    final service = FileInteropService(
      bundleStore: bundleStore,
      openFilePicker: ({
        List<XTypeGroup> acceptedTypeGroups = const <XTypeGroup>[],
      }) async {
        return XFile(importPath);
      },
    );

    expect(service.importFromFile, throwsFormatException);
    expect(bundleStore.mergedBundle, isNull);
  });
}

class _FakeSyncBundleStore implements SyncBundleStore {
  _FakeSyncBundleStore(this.bundle);

  final SyncBundle bundle;
  var exportCount = 0;
  SyncBundle? mergedBundle;

  @override
  Future<SyncBundle> exportBundle() async {
    exportCount += 1;
    return bundle;
  }

  @override
  Future<void> mergeBundle(SyncBundle bundle) async {
    mergedBundle = bundle;
  }
}

SyncBundle _emptyBundle(String sourceDeviceId) {
  return SyncBundle(
    schemaVersion: SyncBundle.currentSchemaVersion,
    exportedAt: DateTime(2026, 1, 1),
    sourceDeviceId: sourceDeviceId,
    activities: const [],
    timeEntries: const [],
    actionLogs: const [],
    profileSettings: ProfileSettings.defaults(),
  );
}
