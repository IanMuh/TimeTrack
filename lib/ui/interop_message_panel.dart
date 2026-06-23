import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class InteropMessagePanel extends StatelessWidget {
  const InteropMessagePanel({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final details = _InteropMessageDetails.from(context, message);
    final colorScheme = Theme.of(context).colorScheme;
    final color = details.isError ? colorScheme.error : colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(details.icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    details.body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteropMessageDetails {
  const _InteropMessageDetails({
    required this.title,
    required this.body,
    required this.icon,
    this.isError = false,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool isError;

  static _InteropMessageDetails from(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context)!;
    const exportedPrefix = '已导出：';
    const importedPrefix = '已导入：';
    if (message.startsWith(exportedPrefix)) {
      return _InteropMessageDetails(
        title: l10n.exported,
        body: message.substring(exportedPrefix.length),
        icon: Icons.download_done_outlined,
      );
    }
    if (message.startsWith(importedPrefix)) {
      return _InteropMessageDetails(
        title: l10n.imported,
        body: message.substring(importedPrefix.length),
        icon: Icons.upload_file_outlined,
      );
    }
    return _InteropMessageDetails(
      title: message.contains(l10n.failed) ? l10n.operationFailed : l10n.interopStatus,
      body: message,
      icon: message.contains(l10n.failed) ? Icons.error_outline : Icons.info_outline,
      isError: message.contains(l10n.failed),
    );
  }
}
