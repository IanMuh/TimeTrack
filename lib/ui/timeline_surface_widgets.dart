part of 'timeline_page.dart';

class FutureDayBanner extends StatelessWidget {
  const FutureDayBanner({required this.selectedDay, super.key});

  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: QuietPanel(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            IconBadge(
              icon: Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.futureDayBanner(
                    DateFormat('yyyy-MM-dd').format(selectedDay)),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimelineCardHeader extends StatelessWidget {
  const TimelineCardHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SectionTitle(
      title: title,
      subtitle: subtitle,
      icon: icon,
    );
  }
}

class TimelineEmptyState extends StatelessWidget {
  const TimelineEmptyState({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.inbox_outlined,
      title: text,
      message: AppLocalizations.of(context)!.switchToRecordHint,
    );
  }
}

class TimelineSurface extends StatelessWidget {
  const TimelineSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return QuietPanel(
      padding: padding,
      child: child,
    );
  }
}
