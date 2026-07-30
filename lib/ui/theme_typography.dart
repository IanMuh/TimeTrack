import 'package:flutter/material.dart';

TextTheme compactTextTheme(TextTheme textTheme) {
  return textTheme.copyWith(
    displayLarge: textTheme.displayLarge?.copyWith(
      fontSize: 36,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    displayMedium: textTheme.displayMedium?.copyWith(
      fontSize: 28,
      height: 1.22,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    headlineMedium: textTheme.headlineMedium?.copyWith(
      fontSize: 20,
      height: 1.35,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    headlineSmall: textTheme.headlineSmall?.copyWith(
      fontSize: 19,
      height: 1.35,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    titleLarge: textTheme.titleLarge?.copyWith(
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    titleMedium: textTheme.titleMedium?.copyWith(
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    bodyLarge: textTheme.bodyLarge?.copyWith(
      fontSize: 14,
      height: 1.5,
      letterSpacing: 0,
    ),
    bodyMedium: textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      height: 1.5,
      letterSpacing: 0,
    ),
    labelLarge: textTheme.labelLarge?.copyWith(
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
  );
}
