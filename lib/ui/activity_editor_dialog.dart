import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../domain/activity.dart';
import '../domain/activity_category.dart';
import '../l10n/app_localizations.dart';
import 'activity_color_picker.dart';
import 'activity_colors.dart';
import 'ui_components.dart';

Future<Activity?> showActivityEditorDialog(
  BuildContext context,
  AppState state, {
  Activity? activity,
}) async {
  if (activity?.isUnassigned ?? false) {
    return activity;
  }
  final controller = TextEditingController(text: activity?.name ?? '');
  final categoryController = TextEditingController();
  var selectedColor = activity?.color ??
      nextActivityColor(state.activities.map((activity) => activity.color));
  var selectedCategoryColor = nextCategoryColor(
    state.activityCategories.map((category) => category.color),
  );
  var primaryCategoryId = activity == null
      ? null
      : state.primaryCategoryForActivity(activity.id)?.id;
  final secondaryCategoryIds = activity == null
      ? <String>{}
      : {
          for (final category
              in state.secondaryCategoriesForActivity(activity.id))
            category.id,
        };
  Activity? saved;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> createCategory() async {
            final name = categoryController.text.trim();
            if (name.isEmpty) {
              return;
            }
            final category = await state.createCategory(
              name,
              selectedCategoryColor,
            );
            if (!context.mounted) {
              return;
            }
            categoryController.clear();
            setState(() {
              primaryCategoryId ??= category.id;
              selectedCategoryColor = nextCategoryColor(
                state.activityCategories.map((category) => category.color),
              );
            });
          }

          Future<void> deleteCategory(ActivityCategory category) async {
            setState(() {
              if (primaryCategoryId == category.id) {
                primaryCategoryId = null;
              }
              secondaryCategoryIds.remove(category.id);
            });
            await state.deleteCategory(category);
            if (context.mounted) {
              setState(() {});
            }
          }

          Future<void> saveActivity() async {
            final name = controller.text.trim();
            if (name.isEmpty) {
              return;
            }
            saved = activity == null
                ? await state.createActivity(
                    name,
                    selectedColor,
                    primaryCategoryId: primaryCategoryId,
                    secondaryCategoryIds:
                        secondaryCategoryIds.toList(growable: false),
                  )
                : await state.updateActivity(
                    activity,
                    name: name,
                    color: selectedColor,
                    updateCategories: true,
                    primaryCategoryId: primaryCategoryId,
                    secondaryCategoryIds:
                        secondaryCategoryIds.toList(growable: false),
                  );
            if (context.mounted) {
              Navigator.pop(context);
            }
          }

          Future<void> deleteActivity() async {
            if (activity == null || activity.isUnassigned) {
              return;
            }
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(AppLocalizations.of(context)!.deleteActivityTitle),
                content: Text(
                  AppLocalizations.of(context)!
                      .confirmDeleteActivity(activity.name),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(AppLocalizations.of(context)!.cancel),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(AppLocalizations.of(context)!.delete),
                  ),
                ],
              ),
            );
            if (confirmed != true) {
              return;
            }
            await state.deleteActivity(activity);
            if (context.mounted) {
              Navigator.pop(context);
            }
          }

          return AlertDialog(
            title: Text(activity == null
                ? AppLocalizations.of(context)!.newActivity
                : AppLocalizations.of(context)!.editActivityTitle),
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
                        prefixIcon: const Icon(Icons.label_outline),
                      ),
                      autofocus: true,
                    ),
                    _ActivityCategoryEditor(
                      state: state,
                      categoryController: categoryController,
                      primaryCategoryId: primaryCategoryId,
                      secondaryCategoryIds: secondaryCategoryIds,
                      selectedCategoryColor: selectedCategoryColor,
                      onPrimaryChanged: (value) {
                        setState(() {
                          primaryCategoryId = value;
                          secondaryCategoryIds.remove(value);
                        });
                      },
                      onSecondaryToggled: (category, selected) {
                        setState(() {
                          if (selected) {
                            secondaryCategoryIds.add(category.id);
                          } else {
                            secondaryCategoryIds.remove(category.id);
                          }
                        });
                      },
                      onCategoryColorChanged: (color) {
                        setState(() => selectedCategoryColor = color);
                      },
                      onCreateCategory: createCategory,
                      onDeleteCategory: deleteCategory,
                    ),
                    const SizedBox(height: 16),
                    ActivityColorPicker(
                      selectedColor: selectedColor,
                      onColorChanged: (color) =>
                          setState(() => selectedColor = color),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actions: [
              _ActivityEditorActionRow(
                showDelete: activity != null && !activity.isUnassigned,
                onDelete: deleteActivity,
                onCancel: () => Navigator.pop(context),
                onSave: saveActivity,
                saveIcon: activity == null ? Icons.add : Icons.save_outlined,
                saveLabel: activity == null
                    ? AppLocalizations.of(context)!.create
                    : AppLocalizations.of(context)!.save,
              ),
            ],
          );
        },
      );
    },
  );
  return saved;
}

class _ActivityCategoryEditor extends StatelessWidget {
  const _ActivityCategoryEditor({
    required this.state,
    required this.categoryController,
    required this.primaryCategoryId,
    required this.secondaryCategoryIds,
    required this.selectedCategoryColor,
    required this.onPrimaryChanged,
    required this.onSecondaryToggled,
    required this.onCategoryColorChanged,
    required this.onCreateCategory,
    required this.onDeleteCategory,
  });

  final AppState state;
  final TextEditingController categoryController;
  final String? primaryCategoryId;
  final Set<String> secondaryCategoryIds;
  final int selectedCategoryColor;
  final ValueChanged<String?> onPrimaryChanged;
  final void Function(ActivityCategory category, bool selected)
      onSecondaryToggled;
  final ValueChanged<int> onCategoryColorChanged;
  final Future<void> Function() onCreateCategory;
  final Future<void> Function(ActivityCategory category) onDeleteCategory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = state.activityCategories;
    final selectedPrimary = categories.any(
      (category) => category.id == primaryCategoryId,
    )
        ? primaryCategoryId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          key: ValueKey(selectedPrimary),
          initialValue: selectedPrimary,
          decoration: InputDecoration(
            labelText: l10n.primaryCategory,
            prefixIcon: const Icon(Icons.category_outlined),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.uncategorized),
            ),
            for (final category in categories)
              DropdownMenuItem<String?>(
                value: category.id,
                child: Text(category.name),
              ),
          ],
          onChanged: onPrimaryChanged,
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categories)
                FilterChip(
                  label: Text(category.name),
                  avatar: CircleAvatar(
                    radius: 6,
                    backgroundColor: Color(category.color),
                  ),
                  selected: secondaryCategoryIds.contains(category.id),
                  onSelected: category.id == selectedPrimary
                      ? null
                      : (selected) => onSecondaryToggled(category, selected),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: categoryController,
          decoration: InputDecoration(
            labelText: l10n.categoryName,
            prefixIcon: const Icon(Icons.add_circle_outline),
          ),
          onSubmitted: (_) => onCreateCategory(),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          key: const ValueKey('activity-category-color-picker'),
          decoration: InputDecoration(
            labelText: l10n.categoryColor,
            prefixIcon: const Icon(Icons.palette_outlined),
          ),
          child: ActivityColorPicker(
            selectedColor: selectedCategoryColor,
            onColorChanged: onCategoryColorChanged,
            palette: categoryPalette,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCreateCategory,
            icon: const Icon(Icons.add),
            label: Text(l10n.createCategory),
          ),
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categories)
                InputChip(
                  avatar: CircleAvatar(
                    backgroundColor: Color(category.color),
                  ),
                  label: Text(category.name),
                  onDeleted: () => onDeleteCategory(category),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ActivityEditorActionRow extends StatelessWidget {
  const _ActivityEditorActionRow({
    required this.showDelete,
    required this.onDelete,
    required this.onCancel,
    required this.onSave,
    required this.saveIcon,
    required this.saveLabel,
  });

  final bool showDelete;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final IconData saveIcon;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final deleteButton = TextButton.icon(
      onPressed: onDelete,
      icon: const Icon(Icons.delete_outline),
      label: Text(
        l10n.delete,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final cancelButton = TextButton(
      onPressed: onCancel,
      child: Text(
        l10n.cancel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final saveButton = FilledButton.icon(
      onPressed: onSave,
      icon: Icon(saveIcon),
      label: Text(
        saveLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final compact =
        showDelete && dialogContentWidth(context, maxWidth: 420) < 360;

    if (compact) {
      return SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: deleteButton),
                const SizedBox(width: 8),
                Expanded(child: cancelButton),
              ],
            ),
            const SizedBox(height: 8),
            saveButton,
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          if (showDelete) ...[
            Expanded(child: deleteButton),
            const SizedBox(width: 8),
          ],
          Expanded(child: cancelButton),
          const SizedBox(width: 8),
          Expanded(child: saveButton),
        ],
      ),
    );
  }
}
