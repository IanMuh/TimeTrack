import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/ui/app_theme.dart';
import 'package:timetrack/ui/theme_preset.dart';

void main() {
  test('theme presets expose stable seed colors', () {
    expect(ThemePreset.teal.seedColor, const Color(0xff14b8a6));
    expect(ThemePreset.blue.seedColor, const Color(0xff2563eb));
    expect(ThemePreset.slate.label, 'Slate');
  });

  test('light theme uses selected preset and compact typography', () {
    final theme = TimeTrackTheme.light(preset: ThemePreset.blue);

    expect(theme.colorScheme.primary, ThemePreset.blue.seedColor);
    expect(theme.colorScheme.secondary, const Color(0xff14b8a6));
    expect(theme.scaffoldBackgroundColor, const Color(0xfff8fafc));
    expect(theme.colorScheme.surfaceContainerHighest, const Color(0xfff1f5f9));
    expect(theme.textTheme.displayMedium?.fontSize, 28);
    expect(theme.textTheme.labelLarge?.fontSize, 12);
    expect(theme.navigationBarTheme.indicatorColor, isNot(Colors.transparent));
  });

  test('dark theme keeps the preset seed and dark surfaces', () {
    final theme = TimeTrackTheme.dark(preset: ThemePreset.rose);

    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, ThemePreset.rose.seedColor);
    expect(theme.colorScheme.secondary, const Color(0xff14b8a6));
    expect(theme.scaffoldBackgroundColor, const Color(0xff0f172a));
    expect(theme.cardTheme.color, const Color(0xff111827));
  });

  test('snack bar background follows the surface system', () {
    final theme = TimeTrackTheme.light(preset: ThemePreset.blue);

    expect(theme.snackBarTheme.backgroundColor, theme.colorScheme.surface);
    expect(theme.snackBarTheme.backgroundColor, isNot(const Color(0xff134e4a)));
  });
}
