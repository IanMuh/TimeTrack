import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'sync_bundle.dart';
import 'time_repository.dart';

typedef SaveLocationPicker = Future<FileSaveLocation?> Function({
  List<XTypeGroup> acceptedTypeGroups,
  String? suggestedName,
});

typedef OpenFilePicker = Future<XFile?> Function({
  List<XTypeGroup> acceptedTypeGroups,
});

typedef ExportDirectoryPicker = Future<String?> Function({
  String? initialDirectory,
  String? confirmButtonText,
  bool? canCreateDirectories,
});

typedef ExportDirectoryProvider = Future<Directory> Function();

class FileInteropService {
  FileInteropService({
    required TimeRepository repository,
    SaveLocationPicker? saveLocationPicker,
    OpenFilePicker? openFilePicker,
    ExportDirectoryPicker? exportDirectoryPicker,
    ExportDirectoryProvider? exportDirectoryProvider,
  })  : _repository = repository,
        _saveLocationPicker = saveLocationPicker ?? _defaultSaveLocationPicker,
        _openFilePicker = openFilePicker ?? _defaultOpenFilePicker,
        _exportDirectoryPicker =
            exportDirectoryPicker ?? _defaultExportDirectoryPicker,
        _exportDirectoryProvider =
            exportDirectoryProvider ?? getApplicationDocumentsDirectory;

  static const _typeGroup = XTypeGroup(
    label: 'TimeTrack JSON',
    extensions: ['json'],
    mimeTypes: ['application/json'],
  );

  final TimeRepository _repository;
  final SaveLocationPicker _saveLocationPicker;
  final OpenFilePicker _openFilePicker;
  final ExportDirectoryPicker _exportDirectoryPicker;
  final ExportDirectoryProvider _exportDirectoryProvider;
  final SyncBundleCodec _codec = const SyncBundleCodec();

  Future<String?> exportToFile() async {
    final timestamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final fileName = 'timetrack-$timestamp.timetrack.json';
    final path = await _exportPath(fileName);
    if (path == null) {
      return null;
    }

    final json = _codec.encode(await _repository.exportBundle());
    await File(path).writeAsString(json, encoding: utf8);
    return path;
  }

  Future<String?> importFromFile() async {
    final file = await _openFilePicker(
      acceptedTypeGroups: const [_typeGroup],
    );
    if (file == null) {
      return null;
    }

    final bundle = _codec.decode(await file.readAsString());
    await _repository.mergeBundle(bundle);
    return file.path;
  }

  Future<String?> _exportPath(String fileName) async {
    try {
      final location = await _saveLocationPicker(
        acceptedTypeGroups: const [_typeGroup],
        suggestedName: fileName,
      );
      return location?.path;
    } on UnimplementedError {
      return _exportPathFromDirectoryPicker(fileName);
    }
  }

  Future<String?> _exportPathFromDirectoryPicker(String fileName) async {
    try {
      final directoryPath = await _exportDirectoryPicker(
        confirmButtonText: '选择导出位置',
        canCreateDirectories: true,
      );
      if (directoryPath == null) {
        return null;
      }

      final directory = Directory(directoryPath);
      await directory.create(recursive: true);
      return p.join(directory.path, fileName);
    } on UnimplementedError {
      final directory = await _exportDirectoryProvider();
      await directory.create(recursive: true);
      return p.join(directory.path, fileName);
    }
  }

  static Future<FileSaveLocation?> _defaultSaveLocationPicker({
    List<XTypeGroup> acceptedTypeGroups = const <XTypeGroup>[],
    String? suggestedName,
  }) {
    return getSaveLocation(
      acceptedTypeGroups: acceptedTypeGroups,
      suggestedName: suggestedName,
    );
  }

  static Future<XFile?> _defaultOpenFilePicker({
    List<XTypeGroup> acceptedTypeGroups = const <XTypeGroup>[],
  }) {
    return openFile(acceptedTypeGroups: acceptedTypeGroups);
  }

  static Future<String?> _defaultExportDirectoryPicker({
    String? initialDirectory,
    String? confirmButtonText,
    bool? canCreateDirectories,
  }) {
    return getDirectoryPath(
      initialDirectory: initialDirectory,
      confirmButtonText: confirmButtonText,
      canCreateDirectories: canCreateDirectories,
    );
  }
}
