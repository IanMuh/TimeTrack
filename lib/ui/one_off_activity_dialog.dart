import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../domain/activity.dart';
import '../l10n/app_localizations.dart';
import 'activity_color_picker.dart';
import 'activity_colors.dart';
import 'ui_components.dart';

class OneOffActivityTile extends StatelessWidget {
  const OneOffActivityTile({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.flash_on_outlined),
      label: Text(AppLocalizations.of(context)!.oneOffActivity),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class AddActivityTile extends StatelessWidget {
  const AddActivityTile({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(AppLocalizations.of(context)!.newActivity),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

Future<Activity?> showOneOffActivityDialog(
  BuildContext context,
  AppState state,
) async {
  final suggestions = await state.oneOffActivitySuggestions();
  if (!context.mounted) {
    return null;
  }
  final controller = TextEditingController();
  var selectedColor =
      nextActivityColor(state.activities.map((activity) => activity.color));
  Activity? selectedSuggestion;
  Activity? saved;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final query = controller.text.trim().toLowerCase();
          final filteredSuggestions = query.isEmpty
              ? <Activity>[]
              : [
                  for (final activity in suggestions)
                    if (activity.name.toLowerCase().contains(query)) activity,
                ];
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.oneOffActivity),
            content: SizedBox(
              width: dialogContentWidth(context, maxWidth: 420),
              child: DialogContentScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.name,
                        prefixIcon: const Icon(Icons.bolt_outlined),
                      ),
                      onChanged: (_) {
                        setState(() => selectedSuggestion = null);
                      },
                      autofocus: true,
                    ),
                    if (filteredSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final activity in filteredSuggestions)
                              ChoiceChip(
                                avatar: Icon(
                                  Icons.bolt_outlined,
                                  size: 18,
                                  color: Color(activity.color),
                                ),
                                label: _OneOffSuggestionLabel(
                                  name: activity.name,
                                ),
                                selected: selectedSuggestion?.id == activity.id,
                                onSelected: (_) {
                                  setState(() {
                                    selectedSuggestion = activity;
                                    selectedColor = activity.color;
                                    controller.text = activity.name;
                                    controller.selection =
                                        TextSelection.collapsed(
                                      offset: controller.text.length,
                                    );
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ActivityColorPicker(
                      selectedColor: selectedColor,
                      onColorChanged: (color) => setState(() {
                        selectedSuggestion = null;
                        selectedColor = color;
                      }),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    return;
                  }
                  saved = await state.createOneOffActivity(
                    name,
                    selectedColor,
                    reuseActivity: selectedSuggestion,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(AppLocalizations.of(context)!.start),
              ),
            ],
          );
        },
      );
    },
  );
  return saved;
}

class _OneOffSuggestionLabel extends StatelessWidget {
  const _OneOffSuggestionLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            AppLocalizations.of(context)!.oneOff,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
          ),
        ),
      ],
    );
  }
}
