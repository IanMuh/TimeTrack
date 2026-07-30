import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final Map<ShortcutActivator, Intent> appShellShortcuts = {
  const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
      const UndoIntent(),
  const SingleActivator(LogicalKeyboardKey.keyY, control: true):
      const RedoIntent(),
  const SingleActivator(
    LogicalKeyboardKey.keyZ,
    control: true,
    shift: true,
  ): const RedoIntent(),
  const SingleActivator(LogicalKeyboardKey.digit1, control: true):
      const SelectDestinationIntent(0),
  const SingleActivator(LogicalKeyboardKey.digit2, control: true):
      const SelectDestinationIntent(1),
  const SingleActivator(LogicalKeyboardKey.digit3, control: true):
      const SelectDestinationIntent(2),
  const SingleActivator(LogicalKeyboardKey.digit4, control: true):
      const SelectDestinationIntent(3),
  const SingleActivator(LogicalKeyboardKey.keyN, control: true):
      const TimelineAddEntryIntent(),
  const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
      const TimelinePreviousRangeIntent(),
  const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
      const TimelineNextRangeIntent(),
};

bool hasFocusedEditable(BuildContext context) {
  final focus = FocusManager.instance.primaryFocus;
  final focusedContext = focus?.context;
  if (focusedContext == null) {
    return false;
  }
  return focusedContext.widget is EditableText ||
      focusedContext.findAncestorWidgetOfExactType<EditableText>() != null;
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class SelectDestinationIntent extends Intent {
  const SelectDestinationIntent(this.index);

  final int index;
}

class TimelineAddEntryIntent extends Intent {
  const TimelineAddEntryIntent();
}

class TimelinePreviousRangeIntent extends Intent {
  const TimelinePreviousRangeIntent();
}

class TimelineNextRangeIntent extends Intent {
  const TimelineNextRangeIntent();
}
