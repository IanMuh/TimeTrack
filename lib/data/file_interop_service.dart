import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

import 'sync_bundle.dart';
import 'time_repository.dart';

class FileInteropService {
  FileInteropService({required TimeRepository repository})
      : _repository = repository;

  static const _typeGroup = XTypeGroup(
    label: 'TimeTrack JSON',
    extensions: ['json'],
    mimeTypes: ['application/json'],
  );

  final TimeRepository _repository;
  final SyncBundleCodec _codec = const SyncBundleCodec();

  Future<String?> exportToFile() async {
    final timestamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final fileName = 'timetrack-$timestamp.timetrack.json';
    final location = await getSaveLocation(
      acceptedTypeGroups: const [_typeGroup],
      suggestedName: fileName,
    );
    if (location == null) {
      return null;
    }

    final json = _codec.encode(await _repository.exportBundle());
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(json)),
      name: fileName,
      mimeType: 'application/json',
    );
    await file.saveTo(location.path);
    return location.path;
  }

  Future<String?> importFromFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [_typeGroup],
    );
    if (file == null) {
      return null;
    }

    final bundle = _codec.decode(await file.readAsString());
    await _repository.mergeBundle(bundle);
    return file.path;
  }
}
