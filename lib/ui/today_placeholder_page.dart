import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'ui_components.dart';

class TodayPlaceholderPage extends StatelessWidget {
  const TodayPlaceholderPage({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        return AdaptivePage(
          pageKey: const PageStorageKey('today-placeholder-page'),
          maxWidth: 430,
          onRefresh: state.refresh,
          children: [
            PageHeader(
              title: AppLocalizations.of(context)!.navToday,
              subtitle: AppLocalizations.of(context)!.todayPhasePlaceholder,
            ),
            const SectionGap(),
            QuietPanel(
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.today,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
