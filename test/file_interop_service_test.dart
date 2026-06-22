import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timetrack/data/file_interop_service.dart';
import 'package:timetrack/data/local_database.dart';
import 'package:timetrack/data/time_repository.dart';

Future<TimeRepository> buildFileInteropRepository() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await LocalDatabase.createSchema(db);
  final database = LocalDatabase(database: db);
  final repository = TimeRepository(database: database, deviceId: 'source');
  await repository.ensureSeedData();
  final activity = (await repository.activities()).first;
  await repository.createManualEntry(
    activityId: activity.id,
    startAt: DateTime(2026, 1, 1, 9),
    endAt: DateTime(2026, 1, 1, 10),
    note: 'export me',
  );
  return repository;
}

void main() {
  test('file export writes to save dialog path when available', () async {
    final repository = await buildFileInteropRepository();
    final exportDir =
        await Directory.systemTemp.createTemp('timetrack-export-');
    addTearDown(() => exportDir.delete(recursive: true));
    final exportPath = p.join(exportDir.path, 'chosen.timetrack.json');
    var directoryPickerCalled = false;

    final service = FileInteropService(
      repository: repository,
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
    final repository = await buildFileInteropRepository();
    final exportDir =
        await Directory.systemTemp.createTemp('timetrack-export-');
    addTearDown(() => exportDir.delete(recursive: true));
    String? pickedConfirmButtonText;
    bool? pickedCanCreateDirectories;

    final service = FileInteropService(
      repository: repository,
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
    final repository = await buildFileInteropRepository();
    var directoryPickerCalled = false;

    final service = FileInteropService(
      repository: repository,
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
    final repository = await buildFileInteropRepository();
    final exportDir =
        await Directory.systemTemp.createTemp('timetrack-export-');
    addTearDown(() => exportDir.delete(recursive: true));

    final service = FileInteropService(
      repository: repository,
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
}
