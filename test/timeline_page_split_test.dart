import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TimelinePage header and surface widgets live outside the page shell',
      () {
    final page = File('lib/ui/timeline_page.dart');
    final header = File('lib/ui/timeline_header.dart');
    final surfaceWidgets = File('lib/ui/timeline_surface_widgets.dart');

    expect(header.existsSync(), isTrue);
    expect(surfaceWidgets.existsSync(), isTrue);

    final pageSource = page.readAsStringSync();
    final headerSource = header.readAsStringSync();
    final surfaceSource = surfaceWidgets.readAsStringSync();

    expect(pageSource, contains("part 'timeline_header.dart';"));
    expect(pageSource, contains("part 'timeline_surface_widgets.dart';"));
    expect(pageSource, isNot(contains('class TimelineHeader')));
    expect(pageSource, isNot(contains('class _TimelineDisplayOptions')));
    expect(pageSource, isNot(contains('class _TimelineModeControl')));
    expect(pageSource, isNot(contains('class FutureDayBanner')));
    expect(pageSource, isNot(contains('class TimelineEmptyState')));
    expect(headerSource, contains('class TimelineHeader'));
    expect(headerSource, contains('class _TimelineDisplayOptions'));
    expect(headerSource, contains('class _TimelineModeControl'));
    expect(surfaceSource, contains('class FutureDayBanner'));
    expect(surfaceSource, contains('class TimelineCardHeader'));
    expect(surfaceSource, contains('class TimelineEmptyState'));
    expect(surfaceSource, contains('class TimelineSurface'));
    expect(_pureLineCount(page), lessThanOrEqualTo(500));
  });
}

int _pureLineCount(File file) {
  return file.readAsLinesSync().where((line) {
    final trimmed = line.trim();
    return trimmed.isNotEmpty &&
        !trimmed.startsWith('//') &&
        !trimmed.startsWith('#') &&
        !trimmed.startsWith('--');
  }).length;
}
