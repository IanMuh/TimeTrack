import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/data/sync_status_store.dart';
import 'package:timetrack/l10n/app_localizations.dart';
import 'package:timetrack/ui/app_shell.dart';
import 'package:timetrack/ui/app_theme.dart';

import '../test/app_shell_test_support.dart';
import '../test/today_reference_state.dart';

const _todayCaptureKey = ValueKey('phase7-desktop-today-shell-capture');
const _settingsCaptureKey = ValueKey('phase7-desktop-settings-shell-capture');
const _todayZhCaptureKey = ValueKey('phase7-desktop-today-zh-shell-capture');
const _settingsZhCaptureKey =
    ValueKey('phase7-desktop-settings-zh-shell-capture');

void main() {
  testWidgets('capture Phase 7 desktop Today shell', (tester) async {
    await tester.runAsync(_loadRobotoFonts);
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);

    _setDesktopViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: _captureTheme(const Locale('en')),
        home: RepaintBoundary(
          key: _todayCaptureKey,
          child: AppShell(state: state),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Today'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Today'), findsAtLeastNWidgets(1));
    expect(find.text('Time by Activity'), findsOneWidget);
    expect(find.text('View full timeline'), findsOneWidget);
    expect(find.text('Top Activities'), findsOneWidget);
    await expectLater(
      find.byKey(_todayCaptureKey),
      matchesGoldenFile('goldens/phase7-today-desktop.png'),
    );
  });

  testWidgets('capture Phase 7 desktop Settings shell', (tester) async {
    await tester.runAsync(_loadRobotoFonts);
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);
    state.currentAppVersion = '1.0.0';
    state.syncStatus = SyncStatus(
      lastSuccessfulSyncAt: DateTime(2024, 5, 15, 9, 30),
      lastTarget: SyncTarget.cloud,
    );

    _setDesktopViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: _captureTheme(const Locale('en')),
        home: RepaintBoundary(
          key: _settingsCaptureKey,
          child: AppShell(state: state),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Settings'), findsAtLeastNWidgets(1));
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    await expectLater(
      find.byKey(_settingsCaptureKey),
      matchesGoldenFile('goldens/phase7-settings-desktop.png'),
    );
  });

  testWidgets('capture Phase 7 desktop Today shell in Chinese', (tester) async {
    await tester.runAsync(_loadRobotoFonts);
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);

    _setDesktopViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: _captureTheme(const Locale('zh')),
        home: RepaintBoundary(
          key: _todayZhCaptureKey,
          child: AppShell(state: state),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('今天'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('今天'), findsAtLeastNWidgets(1));
    expect(find.text('事项用时'), findsOneWidget);
    expect(find.text('查看完整时间线'), findsOneWidget);
    expect(find.text('高频事项'), findsOneWidget);
    await expectLater(
      find.byKey(_todayZhCaptureKey),
      matchesGoldenFile('goldens/phase7-today-desktop-zh.png'),
    );
  });

  testWidgets('capture Phase 7 desktop Settings shell in Chinese', (
    tester,
  ) async {
    await tester.runAsync(_loadRobotoFonts);
    final state = ShellTestState();
    addTearDown(state.dispose);
    seedTodayReferenceState(state);
    state.currentAppVersion = '1.0.0';
    state.syncStatus = SyncStatus(
      lastSuccessfulSyncAt: DateTime(2024, 5, 15, 9, 30),
      lastTarget: SyncTarget.cloud,
    );

    _setDesktopViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: _captureTheme(const Locale('zh')),
        home: RepaintBoundary(
          key: _settingsZhCaptureKey,
          child: AppShell(state: state),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('设置'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('设置'), findsAtLeastNWidgets(1));
    expect(find.text('通用'), findsOneWidget);
    expect(find.text('数据'), findsOneWidget);
    expect(find.text('同步'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    await expectLater(
      find.byKey(_settingsZhCaptureKey),
      matchesGoldenFile('goldens/phase7-settings-desktop-zh.png'),
    );
  });
}

void _setDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ThemeData _captureTheme(Locale locale) {
  final theme = TimeTrackTheme.light();
  if (locale.languageCode != 'zh') {
    return theme;
  }
  return theme.copyWith(
    primaryTextTheme: theme.primaryTextTheme.apply(
      fontFamily: 'Noto Sans SC',
    ),
    textTheme: theme.textTheme.apply(fontFamily: 'Noto Sans SC'),
  );
}

Future<void> _loadRobotoFonts() async {
  final loader = FontLoader('Roboto')
    ..addFont(
      _fontData(
        r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-regular.ttf',
      ),
    )
    ..addFont(
      _fontData(
        r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-medium.ttf',
      ),
    )
    ..addFont(
      _fontData(
        r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-bold.ttf',
      ),
    )
    ..addFont(
      _fontData(
        r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\roboto-black.ttf',
      ),
    )
    ..addFont(
      _fontData(
        r'C:\Windows\Fonts\Noto Sans SC (TrueType).otf',
      ),
    )
    ..addFont(
      _fontData(
        r'C:\Windows\Fonts\Noto Sans SC Medium (TrueType).otf',
      ),
    )
    ..addFont(
      _fontData(
        r'C:\Windows\Fonts\Noto Sans SC Bold (TrueType).otf',
      ),
    );
  await loader.load();

  final cjkLoader = FontLoader('Noto Sans SC')
    ..addFont(
      _fontData(
        r'C:\Windows\Fonts\Noto Sans SC (TrueType).otf',
      ),
    )
    ..addFont(
      _fontData(
        r'C:\Windows\Fonts\Noto Sans SC Medium (TrueType).otf',
      ),
    )
    ..addFont(
      _fontData(
        r'C:\Windows\Fonts\Noto Sans SC Bold (TrueType).otf',
      ),
    );
  await cjkLoader.load();

  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(
      _fontData(
        r'C:\flutter\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
      ),
    );
  await iconLoader.load();
}

Future<ByteData> _fontData(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}
