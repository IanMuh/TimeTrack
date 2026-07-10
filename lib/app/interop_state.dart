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

  Future<void> exportFile() async {
    try {
      final path = await _exportToFile();
      message = path == null ? '已取消导出。' : '已导出：$path';
    } catch (error) {
      message = '导出失败：$error';
    }
  }

  Future<bool> importFile() async {
    try {
      final path = await _importFromFile();
      if (path == null) {
        message = '已取消导入。';
        return false;
      }
      message = '已导入：$path';
      return true;
    } catch (error) {
      message = '导入失败：$error';
      return false;
    }
  }
}
