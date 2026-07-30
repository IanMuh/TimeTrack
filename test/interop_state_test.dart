import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/interop_state.dart';

void main() {
  const exportedPrefix = 'EXPORTED:';
  const importedPrefix = 'IMPORTED:';
  const exportCanceled = 'EXPORT_CANCELED';
  const importCanceled = 'IMPORT_CANCELED';
  const exportFailedPrefix = 'EXPORT_FAILED:';
  const importFailedPrefix = 'IMPORT_FAILED:';

  test('exportFile records exported path', () async {
    final state = InteropState.withHandlers(
      exportToFile: () async => 'C:/tmp/timetrack.json',
      importFromFile: () async => null,
    );

    await state.exportFile(
      exportedPrefix: exportedPrefix,
      canceledMessage: exportCanceled,
      failedPrefix: exportFailedPrefix,
    );

    expect(state.message, '${exportedPrefix}C:/tmp/timetrack.json');
  });

  test('exportFile records cancellation and failure messages', () async {
    final canceled = InteropState.withHandlers(
      exportToFile: () async => null,
      importFromFile: () async => null,
    );
    await canceled.exportFile(
      exportedPrefix: exportedPrefix,
      canceledMessage: exportCanceled,
      failedPrefix: exportFailedPrefix,
    );

    expect(canceled.message, exportCanceled);

    final failed = InteropState.withHandlers(
      exportToFile: () async => throw StateError('disk full'),
      importFromFile: () async => null,
    );
    await failed.exportFile(
      exportedPrefix: exportedPrefix,
      canceledMessage: exportCanceled,
      failedPrefix: exportFailedPrefix,
    );

    expect(failed.message, '${exportFailedPrefix}Bad state: disk full');
  });

  test('importFile reports whether AppState should refresh', () async {
    final imported = InteropState.withHandlers(
      exportToFile: () async => null,
      importFromFile: () async => 'C:/tmp/timetrack.json',
    );

    expect(
      await imported.importFile(
        importedPrefix: importedPrefix,
        canceledMessage: importCanceled,
        failedPrefix: importFailedPrefix,
      ),
      isTrue,
    );
    expect(imported.message, '${importedPrefix}C:/tmp/timetrack.json');

    final canceled = InteropState.withHandlers(
      exportToFile: () async => null,
      importFromFile: () async => null,
    );

    expect(
      await canceled.importFile(
        importedPrefix: importedPrefix,
        canceledMessage: importCanceled,
        failedPrefix: importFailedPrefix,
      ),
      isFalse,
    );
    expect(canceled.message, importCanceled);
  });

  test('importFile captures failure without requesting refresh', () async {
    final state = InteropState.withHandlers(
      exportToFile: () async => null,
      importFromFile: () async => throw const FormatException('bad json'),
    );

    expect(
      await state.importFile(
        importedPrefix: importedPrefix,
        canceledMessage: importCanceled,
        failedPrefix: importFailedPrefix,
      ),
      isFalse,
    );
    expect(state.message, '${importFailedPrefix}FormatException: bad json');
  });
}
