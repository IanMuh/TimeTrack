const activityPalette = <int>[
  0xff2563eb,
  0xff0891b2,
  0xff059669,
  0xff65a30d,
  0xffd97706,
  0xffea580c,
  0xffdc2626,
  0xffe11d48,
  0xffc026d3,
  0xff9333ea,
  0xff7c3aed,
  0xff4f46e5,
  0xff0f766e,
  0xff15803d,
  0xffa16207,
  0xffb45309,
  0xffbe123c,
  0xff475569,
];

const categoryPalette = <int>[
  0xffdc2626,
  0xffea580c,
  0xffca8a04,
  0xff16a34a,
  0xff0891b2,
  0xff2563eb,
  0xff9333ea,
];

int nextActivityColor(Iterable<int> usedColors) {
  return nextPaletteColor(usedColors, activityPalette);
}

int nextCategoryColor(Iterable<int> usedColors) {
  return nextPaletteColor(usedColors, categoryPalette);
}

int nextPaletteColor(Iterable<int> usedColors, List<int> palette) {
  final used = usedColors.toSet();
  for (final color in palette) {
    if (!used.contains(color)) {
      return color;
    }
  }
  return palette.elementAt(used.length % palette.length);
}
