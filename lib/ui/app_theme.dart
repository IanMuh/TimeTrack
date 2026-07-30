import 'package:flutter/material.dart';

import 'theme_preset.dart';
import 'theme_tokens.dart';

class TimeTrackTheme {
  const TimeTrackTheme._();

  static ThemeData light({ThemePreset preset = ThemePreset.blue}) {
    return buildTimeTrackTheme(
      preset: preset,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark({ThemePreset preset = ThemePreset.blue}) {
    return buildTimeTrackTheme(
      preset: preset,
      brightness: Brightness.dark,
    );
  }
}
