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
    required this.icon,
  });

  final _SettingsSection section;
  final String label;
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
          for (final info in sections)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: ListTile(
                leading: Icon(info.icon),
                title: Text(info.label),
                selected: selected == info.section,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () => onSelected(info.section),
              ),
            ),
        ],
      ),
    );
  }
}
