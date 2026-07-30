import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../l10n/app_localizations.dart';

class CompactHistoryMenu extends StatelessWidget {
  const CompactHistoryMenu(
      {required this.state, this.dense = false, super.key});

  final AppState state;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final undoLabel = state.undoLabel;
        final redoLabel = state.redoLabel;
        return SizedBox.square(
          dimension: dense ? 36 : 48,
          child: Material(
            elevation: 0,
            color: dense
                ? Colors.white.withValues(alpha: 0.16)
                : colorScheme.surface,
            shape: dense
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                  )
                : CircleBorder(
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
            child: PopupMenuButton<_HistoryAction>(
              padding: EdgeInsets.zero,
              iconSize: dense ? 20 : 24,
              tooltip:
                  '${AppLocalizations.of(context)!.undoHint} / ${AppLocalizations.of(context)!.redoHint}',
              icon: Icon(
                Icons.history,
                color: dense ? Colors.white : colorScheme.onSurfaceVariant,
              ),
              onSelected: (action) {
                switch (action) {
                  case _HistoryAction.undo:
                    unawaited(state.undo());
                  case _HistoryAction.redo:
                    unawaited(state.redo());
                }
              },
              itemBuilder: (context) {
                return [
                  PopupMenuItem(
                    value: _HistoryAction.undo,
                    enabled: state.canUndo,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.undo),
                      title: Text(
                        undoLabel == null
                            ? AppLocalizations.of(context)!.undoHint
                            : AppLocalizations.of(context)!.undoWithLabel(
                                undoLabel,
                              ),
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: _HistoryAction.redo,
                    enabled: state.canRedo,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.redo),
                      title: Text(
                        redoLabel == null
                            ? AppLocalizations.of(context)!.redoHint
                            : AppLocalizations.of(context)!.redoWithLabel(
                                redoLabel,
                              ),
                      ),
                    ),
                  ),
                ];
              },
            ),
          ),
        );
      },
    );
  }
}

enum _HistoryAction { undo, redo }
