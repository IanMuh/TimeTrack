import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/interop_state.dart';

void main() {
  test('exportFile records exported path', () async {
    final state = InteropState.withHandlers(
      exportToFile: () async => 'C:/tmp/timetrack.json',
      importFromFile: () async => null,
    );

    await state.exportFile();

    expect(state.message, '已导出：C:/tmp/timetrack.json');
  });

  test('exportFile records cancellation and failure messages', () async {
    final canceled = InteropState.withHandlers(
      exportToFile: () async => null,
      importFromFile: () async => null,
    );
    await canceled.exportFile();

    expect(canceled.message, '已取消导出。');

    final failed = InteropState.withHandlers(
      exportToFile: () async => throw StateError('disk full'),
      importFromFile: () async => null,
    );
    await failed.exportFile();

    expect(failed.message, '导出失败：Bad state: disk full');
  });

  test('importFile reports whether AppState should refresh', () async {
    final imported = InteropState.withHandlers(
      exportToFile: () async => null,
      importFromFile: () async => 'C:/tmp/timetrack.json',
    );

    expect(await imported.importFile(), isTrue);
    expect(imported.message, '已导入：C:/tmp/timetrack.json');

    final canceled = InteropState.withHandlers(
      exportToFile: () async => null,
      importFromFile: () async => null,
    );

    expect(await canceled.importFile(), isFalse);
    expect(canceled.message, '已取消导入。');
  });

  test('importFile captures failure without requesting refresh', () async {
    final state = InteropState.withHandlers(
      exportToFile: () async => null,
      importFromFile: () async => throw const FormatException('bad json'),
    );

    expect(await state.importFile(), isFalse);
    expect(state.message, '导入失败：FormatException: bad json');
  });
}
