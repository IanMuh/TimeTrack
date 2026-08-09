import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_state.dart';
import '../data/app_update_service.dart';
import '../data/sync_status_store.dart';
import '../domain/profile_settings.dart';
import '../l10n/app_localizations.dart';
import 'adaptive_layout.dart';
import 'interop_settings_card.dart';
import 'reminder_settings_card.dart';
import 'sync_settings_cards.dart';
import 'timeline_settings_card.dart';
import 'ui_components.dart';
import 'version_update_settings_card.dart';

export 'interop_settings_card.dart';
export 'reminder_settings_card.dart';
export 'sync_settings_cards.dart';
export 'timeline_settings_card.dart';
export 'version_update_settings_card.dart';

part 'settings_section_list.dart';
part 'settings_page_sections.dart';
part 'mobile_settings_page.dart';
part 'desktop_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.state, super.key});

  final AppState state;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  _SettingsSection? _selectedCompactSection;
  _SettingsSection _selectedExpandedSection = _SettingsSection.reminders;
  bool _compactSectionListRequested = false;
  bool _expandedSectionSelectedByUser = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= expandedBreakpoint;
        return AnimatedBuilder(
          animation: state,
          builder: (context, _) {
            return AdaptivePage(
              pageKey: const PageStorageKey('settings-page'),
              maxWidth: 1040,
              children: desktop &&
                      !_expandedSectionSelectedByUser &&
                      !_shouldOpenUpdateSection(state)
                  ? [
                      PageHeader(
                        title: AppLocalizations.of(context)!.settings,
                        subtitle:
                            AppLocalizations.of(context)!.settingsSubtitle,
                      ),
                      const SectionGap(),
                      DesktopSettingsOverview(
                        state: state,
                        onOpenSection: _openDesktopSection,
                      ),
                    ]
                  : [
                      PageHeader(
                        title: AppLocalizations.of(context)!.settings,
                        subtitle:
                            AppLocalizations.of(context)!.settingsSubtitle,
                      ),
                      const SectionGap(),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final mobile =
                              constraints.maxWidth < compactBreakpoint;
                          final expanded =
                              constraints.maxWidth >= expandedBreakpoint;
                          final sections = _settingsSections(
                            context,
                            includeDesktopGeneral: expanded,
                          );
                          if (mobile) {
                            final selected = _selectedCompactSection ??
                                (!_compactSectionListRequested &&
                                        _shouldOpenUpdateSection(state)
                                    ? _SettingsSection.updates
                                    : null);
                            if (selected == null) {
                              return _MobileSettingsPage(
                                state: state,
                                onOpenSection: (section) {
                                  setState(() {
                                    _selectedCompactSection = section;
                                    _compactSectionListRequested = false;
                                  });
                                },
                              );
                            }
                            return _compactSectionDetail(
                              context,
                              selected,
                              state,
                            );
                          }
                          if (!expanded) {
                            final selected = _selectedCompactSection ??
                                (!_compactSectionListRequested &&
                                        _shouldOpenUpdateSection(state)
                                    ? _SettingsSection.updates
                                    : null);
                            if (selected == null) {
                              return _SettingsSectionList(
                                sections: sections,
                                selected: null,
                                onSelected: (section) {
                                  setState(() {
                                    _selectedCompactSection = section;
                                    _compactSectionListRequested = false;
                                  });
                                },
                              );
                            }
                            return _compactSectionDetail(
                              context,
                              selected,
                              state,
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 284,
                                child: _SettingsSectionList(
                                  sections: sections,
                                  selected: _effectiveExpandedSection(state),
                                  onSelected: (section) {
                                    setState(() {
                                      _selectedExpandedSection = section;
                                      _expandedSectionSelectedByUser = true;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _sectionWidget(
                                  _effectiveExpandedSection(state),
                                  state,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  void _openDesktopSection(DesktopSettingsSection section) {
    setState(() {
      _selectedExpandedSection = switch (section) {
        DesktopSettingsSection.general => _SettingsSection.general,
        DesktopSettingsSection.data => _SettingsSection.data,
        DesktopSettingsSection.reminders => _SettingsSection.reminders,
        DesktopSettingsSection.timeline => _SettingsSection.timeline,
        DesktopSettingsSection.sync => _SettingsSection.cloudSync,
        DesktopSettingsSection.interop => _SettingsSection.interop,
        DesktopSettingsSection.about => _SettingsSection.updates,
      };
      _expandedSectionSelectedByUser = true;
    });
  }

  Widget _compactSectionDetail(
    BuildContext context,
    _SettingsSection selected,
    AppState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Tooltip(
            message: AppLocalizations.of(context)!.settings,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCompactSection = null;
                  _compactSectionListRequested = true;
                });
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(
                AppLocalizations.of(context)!.settings,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionWidget(selected, state),
      ],
    );
  }
}
