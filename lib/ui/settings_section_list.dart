part of 'settings_page.dart';

enum _SettingsSection {
  reminders,
  timeline,
  cloudSync,
  interop,
  updates,
}

class _SettingsSectionInfo {
  const _SettingsSectionInfo({
    required this.section,
    required this.label,
    required this.hint,
    required this.icon,
  });

  final _SettingsSection section;
  final String label;
  final String hint;
  final IconData icon;
}

class _SettingsSectionList extends StatelessWidget {
  const _SettingsSectionList({
    required this.sections,
    required this.selected,
    required this.onSelected,
  });

  final List<_SettingsSectionInfo> sections;
  final _SettingsSection? selected;
  final ValueChanged<_SettingsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return QuietPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (final (index, info) in sections.indexed) ...[
            _SettingsSectionTile(
              info: info,
              selected: selected == info.section,
              onTap: () => onSelected(info.section),
            ),
            if (index != sections.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _SettingsSectionTile extends StatelessWidget {
  const _SettingsSectionTile({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final _SettingsSectionInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon: info.icon, color: accent, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: selected ? colorScheme.primary : null,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      info.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  selected ? Icons.check_circle : Icons.chevron_right,
                  size: 18,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
