part of 'timeline_page.dart';

Future<void> showEntryEditor(
  BuildContext context,
  AppState state, {
  TimeEntry? entry,
}) async {
  var activities = [
    for (final activity in state.activities)
      if (!activity.isUnassigned && !activity.isOneOff) activity,
  ];
  var oneOffActivities = <Activity>[];
  final selectedDay = state.selectedDay;
  final editingGeneratedGap = entry?.deviceId == 'unassigned-gap';
  var loadedActivityChoices = false;
  Activity? selectedActivity;
  String activityQuery = '';
  var activityQueryAllowsCreate = false;

  Activity? findActivityIn(Iterable<Activity> source, String? id) {
    if (id == null) {
      return null;
    }
    for (final item in source) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Activity? findActivity(String? id) {
    return findActivityIn(activities, id) ??
        findActivityIn(oneOffActivities, id) ??
        (selectedActivity?.id == id ? selectedActivity : null);
  }

  String? selectedActivityId;
  if (entry == null) {
    selectedActivity = activities.isEmpty ? null : activities.first;
    selectedActivityId = selectedActivity?.id;
  } else {
    final selected = state.activityById(entry.activityId);
    if (selected != null && !selected.isUnassigned) {
      selectedActivity = selected;
      selectedActivityId = selected.id;
      activityQuery = selected.name;
    } else if (selected == null && entry.activityNameSnapshot.isNotEmpty) {
      activityQuery = entry.activityNameSnapshot;
    }
  }
  var start = entry?.startAt ?? _defaultEntryStart(selectedDay, state.now);
  var end = entry?.endAt ?? _defaultEntryEnd(start, selectedDay, state.now);
  var keepRunning = entry?.isRunning ?? false;
  var note = entry?.note ?? '';
  String? formError;

  Future<void> pickDateTime({
    required bool isStart,
    required StateSetter setState,
  }) async {
    final base = isStart ? start : end;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) {
      return;
    }
    final next =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        start = next;
        if (!keepRunning && !end.isAfter(start)) {
          end = start.add(const Duration(minutes: 30));
        }
      } else {
        end = next;
        keepRunning = false;
      }
      formError = null;
    });
  }

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> refreshActivities([
            String? preferredActivityId,
          ]) async {
            final refreshed = await state.entryActivityChoices();
            final refreshedOneOffs = await state.oneOffActivitySuggestions();
            if (!context.mounted) {
              return;
            }
            final preferred = preferredActivityId ?? selectedActivityId;
            final preferredActivity = findActivityIn(refreshed, preferred) ??
                findActivityIn(refreshedOneOffs, preferred);
            setState(() {
              activities = refreshed;
              oneOffActivities = refreshedOneOffs;
              selectedActivity = preferredActivity;
              selectedActivityId = preferredActivity?.id;
              activityQuery = preferredActivity?.name ?? activityQuery;
              activityQueryAllowsCreate = false;
            });
          }

          if (!loadedActivityChoices) {
            loadedActivityChoices = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                unawaited(refreshActivities());
              }
            });
          }

          return AlertDialog(
            title: Text(entry == null
                ? AppLocalizations.of(context)!.addEntryTitle
                : AppLocalizations.of(context)!.editEntryTitle),
            content: SizedBox(
              width: dialogContentWidth(context, maxWidth: 460),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _EntryActivitySelector(
                      activities: activities,
                      oneOffActivities: oneOffActivities,
                      selectedActivityId: selectedActivityId,
                      initialQuery: activityQuery,
                      onQueryChanged: (value) {
                        setState(() {
                          activityQuery = value;
                          activityQueryAllowsCreate = true;
                          selectedActivity = null;
                          selectedActivityId = null;
                          formError = null;
                        });
                      },
                      onActivitySelected: (activity) {
                        setState(() {
                          selectedActivity = activity;
                          selectedActivityId = activity.id;
                          activityQuery = activity.name;
                          activityQueryAllowsCreate = false;
                          formError = null;
                        });
                      },
                      onEditActivity: selectedActivityId == null ||
                              selectedActivity == null ||
                              selectedActivity!.isOneOff
                          ? null
                          : () async {
                              final selected = findActivity(selectedActivityId);
                              if (selected == null || selected.isOneOff) {
                                setState(
                                  () => formError =
                                      AppLocalizations.of(context)!
                                          .selectValidActivity,
                                );
                                return;
                              }
                              final updated = await showActivityEditorDialog(
                                context,
                                state,
                                activity: selected,
                              );
                              if (context.mounted) {
                                await refreshActivities(updated?.id);
                                setState(() => formError = null);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_arrow),
                      title: Text(AppLocalizations.of(context)!.start),
                      subtitle: Text(_formatDateTime(start)),
                      onTap: () =>
                          pickDateTime(isStart: true, setState: setState),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.stop),
                      title: Text(AppLocalizations.of(context)!.endTime),
                      subtitle: Text(
                        keepRunning
                            ? AppLocalizations.of(context)!.keepRunning
                            : _formatDateTime(end),
                      ),
                      enabled: !keepRunning,
                      onTap: keepRunning
                          ? null
                          : () => pickDateTime(
                                isStart: false,
                                setState: setState,
                              ),
                    ),
                    if (entry?.isRunning ?? false)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.timelapse_outlined),
                        title: Text(AppLocalizations.of(context)!.keepRunning),
                        subtitle:
                            Text(AppLocalizations.of(context)!.closeToSaveHint),
                        value: keepRunning,
                        onChanged: (value) {
                          setState(() {
                            keepRunning = value;
                            if (!keepRunning && !end.isAfter(start)) {
                              end = _defaultEntryEnd(
                                start,
                                selectedDay,
                                state.now,
                              );
                            }
                            formError = null;
                          });
                        },
                      ),
                    TextFormField(
                      initialValue: note,
                      onChanged: (value) => note = value,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.note,
                        prefixIcon: const Icon(Icons.notes_outlined),
                      ),
                    ),
                    if (entry != null &&
                        !editingGeneratedGap &&
                        !entry.isRunning) ...[
                      const SizedBox(height: 12),
                      _EntryEditActions(
                        state: state,
                        entry: entry,
                        onChanged: () {
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                    if (formError != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          formError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (entry != null && !editingGeneratedGap)
                TextButton.icon(
                  onPressed: () async {
                    await state.deleteEntry(entry);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: Text(AppLocalizations.of(context)!.delete),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final refreshed = await state.entryActivityChoices();
                  final refreshedOneOffs =
                      await state.oneOffActivitySuggestions();
                  if (!context.mounted) {
                    return;
                  }
                  activities = refreshed;
                  oneOffActivities = refreshedOneOffs;
                  Activity? selectedForSave =
                      findActivityIn(refreshed, selectedActivityId) ??
                          findActivityIn(refreshedOneOffs, selectedActivityId);
                  final trimmedActivityQuery = activityQuery.trim();
                  if (selectedForSave == null &&
                      trimmedActivityQuery.isNotEmpty) {
                    selectedForSave = _exactActivityMatch(
                      refreshed,
                      refreshedOneOffs,
                      trimmedActivityQuery,
                    );
                  }
                  if (selectedForSave == null && !activityQueryAllowsCreate) {
                    setState(() => formError =
                        AppLocalizations.of(context)!.selectValidActivity);
                    return;
                  }
                  var shouldCreateActivity = false;
                  if (selectedForSave == null &&
                      trimmedActivityQuery.isNotEmpty) {
                    final matches = _entryActivityMatches(
                      refreshed,
                      refreshedOneOffs,
                      trimmedActivityQuery,
                    );
                    if (matches.isNotEmpty) {
                      setState(() => formError =
                          AppLocalizations.of(context)!.selectExistingOrNew);
                      return;
                    }
                    shouldCreateActivity = true;
                  }
                  if (selectedForSave == null && !shouldCreateActivity) {
                    setState(() => formError =
                        AppLocalizations.of(context)!.selectValidActivity);
                    return;
                  }
                  if (keepRunning && start.isAfter(state.now)) {
                    setState(() => formError =
                        AppLocalizations.of(context)!.runningCannotStartFuture);
                    return;
                  }
                  if (!keepRunning && !end.isAfter(start)) {
                    setState(() => formError =
                        AppLocalizations.of(context)!.endMustBeAfterStart);
                    return;
                  }
                  final trimmedNote = note.trim();
                  final next = TimeEntry(
                    id: entry?.id ?? 'preview',
                    userId: entry?.userId,
                    activityId: selectedForSave?.id ?? 'preview-activity',
                    startAt: start,
                    endAt: keepRunning ? null : end,
                    note: trimmedNote,
                    deviceId: entry?.deviceId ?? 'manual-entry',
                    updatedAt: DateTime.now(),
                    isDeleted: false,
                  );
                  final overlaps = await state.overlaps(next);
                  if (!context.mounted) {
                    return;
                  }
                  if (overlaps.isNotEmpty && formError == null) {
                    setState(() {
                      formError = AppLocalizations.of(context)!.overlapWarning;
                    });
                    return;
                  }
                  var saved = false;
                  await state.runUndoBatch(() async {
                    if (shouldCreateActivity) {
                      final created = await _showCreateEntryActivityDialog(
                        context,
                        state,
                        initialName: trimmedActivityQuery,
                      );
                      if (!context.mounted || created == null) {
                        return;
                      }
                      selectedForSave = created;
                      setState(() {
                        if (created.isOneOff) {
                          oneOffActivities = [created, ...oneOffActivities];
                        } else {
                          activities = [created, ...activities];
                        }
                        selectedActivity = created;
                        selectedActivityId = created.id;
                        activityQuery = created.name;
                        activityQueryAllowsCreate = false;
                        formError = null;
                      });
                    }
                    final activityForSave = selectedForSave;
                    if (activityForSave == null) {
                      return;
                    }
                    if (activityForSave.isOneOff && activityForSave.isDeleted) {
                      final restoredActivity = await state.createEntryActivity(
                        activityForSave.name,
                        activityForSave.color,
                        isOneOff: true,
                        reuseActivity: activityForSave,
                      );
                      if (!context.mounted) {
                        return;
                      }
                      selectedForSave = restoredActivity;
                      setState(() {
                        selectedActivity = restoredActivity;
                        selectedActivityId = restoredActivity.id;
                        activityQuery = restoredActivity.name;
                        oneOffActivities = [
                          restoredActivity,
                          for (final activity in oneOffActivities)
                            if (activity.id != restoredActivity.id) activity,
                        ];
                      });
                    }
                    final finalActivity = selectedForSave;
                    if (finalActivity == null) {
                      return;
                    }
                    if (entry == null || editingGeneratedGap) {
                      await state.createManualEntry(
                        activityId: finalActivity.id,
                        startAt: start,
                        endAt: end,
                        note: trimmedNote,
                      );
                    } else {
                      await state.saveEntry(
                        next.copyWith(activityId: finalActivity.id),
                      );
                    }
                    saved = true;
                  },
                      label: entry == null || editingGeneratedGap
                          ? AppLocalizations.of(context)!.addEntryTitle
                          : AppLocalizations.of(context)!.editEntryTitle);
                  if (!saved) {
                    return;
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: Text(AppLocalizations.of(context)!.save),
              ),
            ],
          );
        },
      );
    },
  );
}

class _EntryEditActions extends StatelessWidget {
  const _EntryEditActions({
    required this.state,
    required this.entry,
    required this.onChanged,
  });

  final AppState state;
  final TimeEntry entry;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final endAt = entry.endAt;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _EntryMergeButton(
          state: state,
          entry: entry,
          direction: EntryMergeDirection.previous,
          onMerged: onChanged,
        ),
        _EntryMergeButton(
          state: state,
          entry: entry,
          direction: EntryMergeDirection.next,
          onMerged: onChanged,
        ),
        if (endAt != null && entry.startAt.isBefore(endAt))
          _EntrySplitButton(
            state: state,
            entry: entry,
            onSplit: onChanged,
          ),
        if (endAt != null && endAt.isBefore(state.now))
          _EntryExtendToNowButton(
            state: state,
            entry: entry,
            onExtended: onChanged,
          ),
      ],
    );
  }
}

class _EntrySplitButton extends StatelessWidget {
  const _EntrySplitButton({
    required this.state,
    required this.entry,
    required this.onSplit,
  });

  final AppState state;
  final TimeEntry entry;
  final VoidCallback onSplit;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _splitEntry(context, state, entry, onSplit),
      icon: const Icon(Icons.call_split_outlined),
      label: Text(AppLocalizations.of(context)!.split),
    );
  }
}

class _EntryExtendToNowButton extends StatelessWidget {
  const _EntryExtendToNowButton({
    required this.state,
    required this.entry,
    required this.onExtended,
  });

  final AppState state;
  final TimeEntry entry;
  final VoidCallback onExtended;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _extendEntryToNow(context, state, entry, onExtended),
      icon: const Icon(Icons.update),
      label: Text(AppLocalizations.of(context)!.extendToNow),
    );
  }
}

class _EntryMergeButton extends StatelessWidget {
  const _EntryMergeButton({
    required this.state,
    required this.entry,
    required this.direction,
    required this.onMerged,
  });

  final AppState state;
  final TimeEntry entry;
  final EntryMergeDirection direction;
  final VoidCallback onMerged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _mergeEntryWithNeighbor(
        context,
        state,
        entry,
        direction,
        onMerged,
      ),
      icon: Icon(
        direction == EntryMergeDirection.previous
            ? Icons.keyboard_arrow_left
            : Icons.keyboard_arrow_right,
      ),
      label: Text(
        direction == EntryMergeDirection.previous
            ? AppLocalizations.of(context)!.mergeLeft
            : AppLocalizations.of(context)!.mergeRight,
      ),
    );
  }
}

Future<void> _mergeEntryWithNeighbor(
  BuildContext context,
  AppState state,
  TimeEntry entry,
  EntryMergeDirection direction,
  VoidCallback onMerged,
) async {
  final candidate = await state.mergeCandidate(entry.id, direction);
  if (!context.mounted) {
    return;
  }
  if (candidate == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.noAdjacentRecord)),
    );
    return;
  }
  final neighborName = state.activityNameForEntry(candidate.neighbor);
  if (candidate.requiresConfirmation) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final directionText =
            candidate.direction == EntryMergeDirection.previous
                ? AppLocalizations.of(context)!.left
                : AppLocalizations.of(context)!.right;
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!
              .mergeDirectionRecord(directionText)),
          content: Text(
            AppLocalizations.of(context)!.mergeConfirm(
              neighborName,
              formatDurationCompact(candidate.neighborDuration),
              candidate.threshold.inMinutes,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.merge_type_outlined),
              label: Text(AppLocalizations.of(context)!.merge),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
  }
  await state.mergeEntryWithNeighbor(
    entryId: candidate.current.id,
    direction: candidate.direction,
    confirmed: true,
  );
  if (context.mounted) {
    onMerged();
  }
}

Future<void> _splitEntry(
  BuildContext context,
  AppState state,
  TimeEntry entry,
  VoidCallback onSplit,
) async {
  final splitAt = await _showSplitEntryDialog(context, entry);
  if (splitAt == null || !context.mounted) {
    return;
  }
  await state.splitEntry(entryId: entry.id, splitAt: splitAt);
  if (context.mounted) {
    onSplit();
  }
}

Future<DateTime?> _showSplitEntryDialog(
  BuildContext context,
  TimeEntry entry,
) async {
  final endAt = entry.endAt;
  if (endAt == null || !entry.startAt.isBefore(endAt)) {
    return null;
  }
  final midpoint = entry.startAt.add(
    Duration(milliseconds: endAt.difference(entry.startAt).inMilliseconds ~/ 2),
  );
  var splitAt = midpoint;
  String? error;

  Future<void> pickSplitAt(StateSetter setState) async {
    final date = await showDatePicker(
      context: context,
      initialDate: splitAt,
      firstDate: entry.startAt,
      lastDate: endAt,
    );
    if (date == null || !context.mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(splitAt),
    );
    if (time == null) {
      return;
    }
    final next = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      splitAt = next;
      error = null;
    });
  }

  return showDialog<DateTime>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.splitEntryTitle),
            content: SizedBox(
              width: dialogContentWidth(context, maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.call_split_outlined),
                    title: Text(AppLocalizations.of(context)!.splitPoint),
                    subtitle: Text(_formatDateTime(splitAt)),
                    onTap: () => pickSplitAt(setState),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (!entry.startAt.isBefore(splitAt) ||
                      !splitAt.isBefore(endAt)) {
                    setState(() =>
                        error = AppLocalizations.of(context)!.splitPointError);
                    return;
                  }
                  Navigator.pop(context, splitAt);
                },
                icon: const Icon(Icons.call_split_outlined),
                label: Text(AppLocalizations.of(context)!.split),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _extendEntryToNow(
  BuildContext context,
  AppState state,
  TimeEntry entry,
  VoidCallback onExtended,
) async {
  if (!entry.startAt.isBefore(state.now)) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.extendEntryError)),
    );
    return;
  }
  await state.extendEntryToNow(entry);
  if (context.mounted) {
    onExtended();
  }
}

List<Activity> _entryActivityMatches(
  List<Activity> activities,
  List<Activity> oneOffActivities,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return activities;
  }
  final matches = <Activity>[];
  final seenIds = <String>{};
  for (final activity in [...activities, ...oneOffActivities]) {
    if (activity.name.toLowerCase().contains(normalized) &&
        seenIds.add(activity.id)) {
      matches.add(activity);
    }
  }
  return matches;
}

Activity? _exactActivityMatch(
  List<Activity> activities,
  List<Activity> oneOffActivities,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  for (final activity in [...activities, ...oneOffActivities]) {
    if (activity.name.trim().toLowerCase() == normalized) {
      return activity;
    }
  }
  return null;
}

Future<Activity?> _showCreateEntryActivityDialog(
  BuildContext context,
  AppState state, {
  required String initialName,
}) async {
  final controller = TextEditingController(text: initialName);
  var selectedColor =
      nextActivityColor(state.activities.map((activity) => activity.color));
  var isOneOff = false;
  Activity? saved;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.createActivityTitle),
            content: SizedBox(
              width: dialogContentWidth(context, maxWidth: 420),
              child: SingleChildScrollView(
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
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          icon: const Icon(Icons.bookmark_border),
                          label: Text(AppLocalizations.of(context)!.persistent),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: const Icon(Icons.bolt_outlined),
                          label: Text(AppLocalizations.of(context)!.oneOff),
                        ),
                      ],
                      selected: {isOneOff},
                      onSelectionChanged: (values) {
                        setState(() => isOneOff = values.single);
                      },
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
                  saved = await state.createEntryActivity(
                    name,
                    selectedColor,
                    isOneOff: isOneOff,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context)!.create),
              ),
            ],
          );
        },
      );
    },
  );
  return saved;
}

class _EntryActivitySelector extends StatefulWidget {
  const _EntryActivitySelector({
    required this.activities,
    required this.oneOffActivities,
    required this.selectedActivityId,
    required this.initialQuery,
    required this.onQueryChanged,
    required this.onActivitySelected,
    required this.onEditActivity,
  });

  final List<Activity> activities;
  final List<Activity> oneOffActivities;
  final String? selectedActivityId;
  final String initialQuery;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Activity> onActivitySelected;
  final VoidCallback? onEditActivity;

  @override
  State<_EntryActivitySelector> createState() => _EntryActivitySelectorState();
}

class _EntryActivitySelectorState extends State<_EntryActivitySelector> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(_EntryActivitySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery &&
        _controller.text != widget.initialQuery) {
      _controller.text = widget.initialQuery;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = dialogContentWidth(context, maxWidth: 460) < 340;
    final query = _controller.text.trim();
    final visibleActivities = _entryActivityMatches(
      widget.activities,
      widget.oneOffActivities,
      query,
    );
    final field = TextField(
      key: const ValueKey('entry-activity-search-field'),
      controller: _controller,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.entryActivityLabel,
        prefixIcon: const Icon(Icons.search),
      ),
      onChanged: widget.onQueryChanged,
    );
    final actions = IconButton(
      tooltip: AppLocalizations.of(context)!.editCurrentActivity,
      onPressed: widget.onEditActivity,
      icon: const Icon(Icons.edit_outlined),
    );
    final inputRow = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field,
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: actions,
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field),
              const SizedBox(width: 8),
              actions,
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        inputRow,
        const SizedBox(height: 10),
        if (visibleActivities.isEmpty)
          Text(
            AppLocalizations.of(context)!.noMatchingActivity,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final activity in visibleActivities)
                  _EntryActivityChoiceChip(
                    activity: activity,
                    selected: widget.selectedActivityId == activity.id,
                    onSelected: () {
                      _controller.text = activity.name;
                      _controller.selection = TextSelection.collapsed(
                        offset: activity.name.length,
                      );
                      widget.onQueryChanged(activity.name);
                      widget.onActivitySelected(activity);
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EntryActivityChoiceChip extends StatelessWidget {
  const _EntryActivityChoiceChip({
    required this.activity,
    required this.selected,
    required this.onSelected,
  });

  final Activity activity;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(
        activity.isOneOff ? Icons.bolt_outlined : Icons.label_outline,
        size: 18,
        color: Color(activity.color),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              activity.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (activity.isOneOff) ...[
            const SizedBox(width: 6),
            const _OneOffTag(),
          ],
        ],
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _OneOffTag extends StatelessWidget {
  const _OneOffTag();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
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
    );
  }
}

DateTime _defaultEntryStart(DateTime selectedDay, DateTime now) {
  if (selectedDay.isSameDate(now)) {
    final candidate = now.subtract(const Duration(hours: 1));
    if (candidate.isAfter(selectedDay.startOfDay)) {
      return DateTime(
        candidate.year,
        candidate.month,
        candidate.day,
        candidate.hour,
        candidate.minute,
      );
    }
  }
  return DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 9);
}

DateTime _defaultEntryEnd(DateTime start, DateTime selectedDay, DateTime now) {
  final dayEnd = selectedDay.startOfDay.add(const Duration(days: 1));
  final preferredEnd =
      selectedDay.isSameDate(now) ? now : start.add(const Duration(hours: 1));
  final cappedEnd = preferredEnd.isAfter(dayEnd) ? dayEnd : preferredEnd;
  if (cappedEnd.isAfter(start)) {
    return cappedEnd;
  }
  return start.add(const Duration(minutes: 30));
}

String _formatTime(DateTime value) => DateFormat('HH:mm:ss').format(value);

String _formatDateTime(DateTime value) =>
    DateFormat('yyyy-MM-dd HH:mm:ss').format(value);

String _formatVisibleEndTime(
  _VisibleEntryInterval interval,
  DateTime selectedDay,
) {
  final dayEnd = selectedDay.startOfDay.add(const Duration(days: 1));
  if (interval.end == dayEnd) {
    return '24:00:00';
  }
  return _formatTime(interval.end);
}
