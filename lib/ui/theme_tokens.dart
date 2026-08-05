import 'package:flutter/material.dart';

import 'theme_preset.dart';
import 'theme_typography.dart';

const _lightBackground = Color(0xfff8fafc);
const _lightSurface = Color(0xffffffff);
const _lightSurfaceMuted = Color(0xfff1f5f9);
const _lightOutline = Color(0xffcbd5e1);
const _lightOutlineVariant = Color(0xffe2e8f0);
const _lightText = Color(0xff0f172a);
const _lightMutedText = Color(0xff64748b);
const _lightShadow = Color(0x1a0f172a);
const _lightSecondary = Color(0xff14b8a6);

const _darkBackground = Color(0xff0f172a);
const _darkSurface = Color(0xff111827);
const _darkSurfaceMuted = Color(0xff1f2937);
const _darkOutline = Color(0xff334155);
const _darkOutlineVariant = Color(0xff475569);
const _darkText = Color(0xfff8fafc);
const _darkMutedText = Color(0xffcbd5e1);
const _darkShadow = Color(0x40000000);
const _darkSecondary = Color(0xff14b8a6);

ThemeData buildTimeTrackTheme({
  required ThemePreset preset,
  required Brightness brightness,
}) {
  final dark = brightness == Brightness.dark;
  final background = dark ? _darkBackground : _lightBackground;
  final surface = dark ? _darkSurface : _lightSurface;
  final surfaceMuted = dark ? _darkSurfaceMuted : _lightSurfaceMuted;
  final outline = dark ? _darkOutline : _lightOutline;
  final outlineVariant = dark ? _darkOutlineVariant : _lightOutlineVariant;
  final text = dark ? _darkText : _lightText;
  final mutedText = dark ? _darkMutedText : _lightMutedText;
  final accent = preset.seedColor;
  final secondary = dark ? _darkSecondary : _lightSecondary;
  final indicator = Color.lerp(
    surfaceMuted,
    accent,
    dark ? 0.34 : 0.18,
  )!;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  ).copyWith(
    primary: accent,
    secondary: secondary,
    surface: surface,
    surfaceContainer: surface,
    surfaceContainerHighest: surfaceMuted,
    outline: outline,
    outlineVariant: outlineVariant,
    onSurface: text,
    onSurfaceVariant: mutedText,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    visualDensity: VisualDensity.standard,
  );

  final textTheme = base.textTheme.apply(
    bodyColor: text,
    displayColor: text,
  );

  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
    side: BorderSide(color: outline),
  );

  return base.copyWith(
    textTheme: compactTextTheme(textTheme),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 1,
      shadowColor: dark ? _darkShadow : _lightShadow,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      indicatorColor: indicator.withValues(alpha: dark ? 0.42 : 0.68),
      selectedIconTheme: IconThemeData(color: accent),
      selectedLabelTextStyle: TextStyle(
        color: accent,
        fontWeight: FontWeight.w700,
      ),
      unselectedIconTheme: IconThemeData(color: mutedText),
      unselectedLabelTextStyle: TextStyle(color: mutedText),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: indicator.withValues(alpha: dark ? 0.42 : 0.78),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? accent : mutedText,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? accent : mutedText);
      }),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: mutedText,
      selectedColor: accent,
      selectedTileColor: indicator.withValues(alpha: dark ? 0.30 : 0.54),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      minLeadingWidth: 24,
      horizontalTitleGap: 12,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        foregroundColor: colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: surface,
      contentTextStyle: TextStyle(color: text),
      actionTextColor: accent,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: outline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
      color: outlineVariant,
      space: 1,
      thickness: 1,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: accent,
      thumbColor: accent,
      overlayColor: accent.withValues(alpha: 0.12),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.all(BorderSide(color: outline)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return indicator.withValues(alpha: dark ? 0.30 : 0.55);
          }
          return surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? accent : mutedText;
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return indicator.withValues(alpha: dark ? 0.28 : 0.50);
        }
        return surface;
      }),
      side: BorderSide(color: outline),
      labelStyle: TextStyle(
        color: text,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      showCheckmark: false,
    ),
  );
}
