import '../data/file_interop_service.dart';

typedef InteropFileExporter = Future<String?> Function();
typedef InteropFileImporter = Future<String?> Function();

class InteropState {
  InteropState({
    required FileInteropService fileInteropService,
  }) : this.withHandlers(
          exportToFile: fileInteropService.exportToFile,
          importFromFile: fileInteropService.importFromFile,
        );

  InteropState.withHandlers({
    required InteropFileExporter exportToFile,
    required InteropFileImporter importFromFile,
  })  : _exportToFile = exportToFile,
        _importFromFile = importFromFile;

  final InteropFileExporter _exportToFile;
  final InteropFileImporter _importFromFile;

  String? message;

  Future<void> exportFile({
    required String exportedPrefix,
    required String canceledMessage,
    required String failedPrefix,
  }) async {
    try {
      final path = await _exportToFile();
      message = path == null ? canceledMessage : '$exportedPrefix$path';
    } catch (error) {
      message = '$failedPrefix$error';
    }
  }

  Future<bool> importFile({
    required String importedPrefix,
    required String canceledMessage,
    required String failedPrefix,
  }) async {
    try {
      final path = await _importFromFile();
      if (path == null) {
        message = canceledMessage;
        return false;
      }
      message = '$importedPrefix$path';
      return true;
    } catch (error) {
      message = '$failedPrefix$error';
      return false;
    }
  }
}
