import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class AppShellDestination {
  const AppShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

List<AppShellDestination> buildAppShellDestinations(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    AppShellDestination(
      label: l10n.navTimer,
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer,
    ),
    AppShellDestination(
      label: l10n.navToday,
      icon: Icons.today_outlined,
      selectedIcon: Icons.today,
    ),
    AppShellDestination(
      label: l10n.navTimeline,
      icon: Icons.view_timeline_outlined,
      selectedIcon: Icons.view_timeline,
    ),
    AppShellDestination(
      label: l10n.navStats,
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
    ),
    AppShellDestination(
      label: l10n.navSettings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];
}
