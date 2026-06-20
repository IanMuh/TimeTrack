import 'package:flutter/material.dart';

class InteropMessagePanel extends StatelessWidget {
  const InteropMessagePanel({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final details = _InteropMessageDetails.from(message);
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

  static _InteropMessageDetails from(String message) {
    const exportedPrefix = '已导出：';
    const importedPrefix = '已导入：';
    if (message.startsWith(exportedPrefix)) {
      return _InteropMessageDetails(
        title: '已导出',
        body: message.substring(exportedPrefix.length),
        icon: Icons.download_done_outlined,
      );
    }
    if (message.startsWith(importedPrefix)) {
      return _InteropMessageDetails(
        title: '已导入',
        body: message.substring(importedPrefix.length),
        icon: Icons.upload_file_outlined,
      );
    }
    return _InteropMessageDetails(
      title: message.contains('失败') ? '操作失败' : '互通状态',
      body: message,
      icon: message.contains('失败') ? Icons.error_outline : Icons.info_outline,
      isError: message.contains('失败'),
    );
  }
}
