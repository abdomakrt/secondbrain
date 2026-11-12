import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../../domain/task_rules.dart';

/// Priority indicator (UI_SPEC §7: `PriorityIndicator`).
///
/// The quadrant is shown as an icon **and** as text: the meaning never
/// depends on colour alone (UI_SPEC §3.8).
class PriorityIndicator extends StatelessWidget {
  const PriorityIndicator({
    super.key,
    required this.important,
    required this.urgent,
    this.compact = false,
  });

  final bool important;
  final bool urgent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final quadrant = quadrantOf(important: important, urgent: urgent);
    final scheme = Theme.of(context).colorScheme;

    final (IconData icon, Color color, String label) = switch (quadrant) {
      PriorityQuadrant.importantUrgent => (
          Icons.priority_high_rounded,
          scheme.error,
          l.priorityImportantUrgent,
        ),
      PriorityQuadrant.importantNotUrgent => (
          Icons.star_rounded,
          scheme.primary,
          l.priorityImportantNotUrgent,
        ),
      PriorityQuadrant.notImportantUrgent => (
          Icons.schedule_rounded,
          scheme.tertiary,
          l.priorityNotImportantUrgent,
        ),
      PriorityQuadrant.notImportantNotUrgent => (
          Icons.remove_circle_outline,
          scheme.outline,
          l.priorityNotImportantNotUrgent,
        ),
    };

    if (compact) {
      return Tooltip(
        message: label,
        child: Icon(icon, size: 18, color: color),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
