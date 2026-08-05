import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/app_shell.dart';
import 'package:timetrack/ui/app_theme.dart';

import '../test/app_shell_test_support.dart';
import '../test/today_reference_state.dart';

const _captureKey = ValueKey('phase2-today-shell-capture');

void main() {
  testWidgets('capture Phase 2 mobile Today shell', (tester) async {
    await tester.runAsync(_loadRobotoFonts);
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);

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
    await tester.tap(find.text('Today'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Today'), findsAtLeastNWidgets(1));
    expect(find.text('May 15, 2024'), findsOneWidget);
    expect(find.text('Top Activities'), findsOneWidget);
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/phase2-today-mobile.png'),
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
