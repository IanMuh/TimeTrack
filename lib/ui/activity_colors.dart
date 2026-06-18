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

int nextActivityColor(Iterable<int> usedColors) {
  final used = usedColors.toSet();
  for (final color in activityPalette) {
    if (!used.contains(color)) {
      return color;
    }
  }
  return activityPalette.elementAt(used.length % activityPalette.length);
}
