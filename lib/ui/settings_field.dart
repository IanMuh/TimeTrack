import 'package:flutter/material.dart';

class SettingsField extends StatelessWidget {
  const SettingsField({
    required this.icon,
    required this.label,
    required this.value,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
