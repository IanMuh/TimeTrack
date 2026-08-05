import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../l10n/app_localizations.dart';
import 'current_status_card_helpers.dart';

class RunningTimerBar extends StatelessWidget {
  const RunningTimerBar({
    required this.state,
    required this.onPressed,
    this.trailing,
    super.key,
  });

  final AppState state;
  final VoidCallback onPressed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final dark = colorScheme.brightness == Brightness.dark;
        final background =
            dark ? const Color(0xff087f7f) : const Color(0xff0f9f9f);
        final runningActivity = state.runningActivity;
        return ValueListenableBuilder<DateTime>(
          valueListenable: state.clockNotifier,
          builder: (context, now, _) {
            final duration = runningActivity == null
                ? Duration.zero
                : state.runningDuration(at: now);
            return Material(
              color: background,
              child: InkWell(
                onTap: onPressed,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 150;
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    runningActivity?.name ??
                                        AppLocalizations.of(context)!
                                            .notStartedRecord,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  if (!compact) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      AppLocalizations.of(context)!
                                          .timerBarSwitchHint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.78,
                                            ),
                                          ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          formatTimerText(duration),
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_up,
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 4),
                          trailing!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
