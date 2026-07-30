import 'package:flutter/material.dart';

enum ThemePreset {
  teal('Teal', Color(0xff0d9488)),
  blue('Blue', Color(0xff2563eb)),
  purple('Purple', Color(0xff7c3aed)),
  orange('Orange', Color(0xffea580c)),
  rose('Rose', Color(0xffe11d48)),
  emerald('Emerald', Color(0xff059669)),
  slate('Slate', Color(0xff475569));

  const ThemePreset(this.label, this.seedColor);

  final String label;
  final Color seedColor;
}
