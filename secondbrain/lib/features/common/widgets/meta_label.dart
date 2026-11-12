import 'package:flutter/material.dart';

/// A small icon + text pair (project name, date, duration, …).
///
/// Shared by the task row, the inbox card and the knowledge card so the
/// metadata always looks the same.
class MetaLabel extends StatelessWidget {
  const MetaLabel({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 3),
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(color: c),
        ),
      ],
    );
  }
}
