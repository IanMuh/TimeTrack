import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/app_shell.dart';
import 'package:timetrack/ui/app_theme.dart';

import '../test/app_shell_test_support.dart';
import '../test/timeline_reference_state.dart';

const _captureKey = ValueKey('phase3-timeline-shell-capture');
const _wideCaptureKey = ValueKey('phase3-timeline-wide-shell-capture');

void main() {
  testWidgets('capture Phase 3 mobile Timeline shell', (tester) async {
    await tester.runAsync(_loadRobotoFonts);
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTimelineReferenceState(state);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: TimeTrackTheme.light(),
        home: RepaintBoundary(
          key: _captureKey,
          child: AppShell(state: state),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Timeline'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Timeline'), findsAtLeastNWidgets(1));
    expect(find.text('Project Phoenix'), findsAtLeastNWidgets(1));
    expect(find.text('Team Standup'), findsOneWidget);
    expect(find.text('Emails & Planning'), findsOneWidget);
    expect(find.text('Deep Work'), findsAtLeastNWidgets(1));
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/phase3-timeline-mobile.png'),
    );
  });

  testWidgets('capture Phase 3 wide Timeline shell', (tester) async {
    await tester.runAsync(_loadRobotoFonts);
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTimelineReferenceState(state);

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: TimeTrackTheme.light(),
        home: RepaintBoundary(
          key: _wideCaptureKey,
          child: AppShell(state: state),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Timeline'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Timeline'), findsAtLeastNWidgets(1));
    expect(find.text('Project Phoenix'), findsAtLeastNWidgets(1));
    expect(find.text('Team Standup'), findsOneWidget);
    expect(find.text('Emails & Planning'), findsOneWidget);
    expect(find.text('Zoomable timeline'), findsNothing);
    await expectLater(
      find.byKey(_wideCaptureKey),
      matchesGoldenFile('goldens/phase3-timeline-wide.png'),
    );
  });
}

Future<void> _loadRobotoFonts() async {
  final loader = FontLoader('Roboto')
    ..addFont(_fontData(
      r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-regular.ttf',
    ))
    ..addFont(_fontData(
      r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-medium.ttf',
    ))
    ..addFont(_fontData(
      r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-bold.ttf',
    ))
    ..addFont(_fontData(
      r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-black.ttf',
    ));
  await loader.load();

  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(_fontData(
      r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
    ));
  await iconLoader.load();
}

Future<ByteData> _fontData(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}
