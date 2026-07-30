import 'package:flutter/material.dart';

/// Shows a unified app snack bar with the given [message].
///
/// If [actionLabel] and [onAction] are provided, a snack bar action is added.
/// The caller can await the returned controller's [closed] future to know when
/// the snack bar has been dismissed.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    ),
  );
}

/// Shows a snack bar for an error [message].
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showErrorSnackBar(
  BuildContext context, {
  required String message,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return messenger.showSnackBar(
    SnackBar(content: Text(message)),
  );
}
