import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

/// The Eisenhower matrix as a set of choices (UI_SPEC §5 UI-03).
///
/// Each quadrant carries its own label so the meaning never depends on the
/// colour alone.
class PrioritySelector extends StatelessWidget {
  const PrioritySelector({
    super.key,
    required this.important,
    required this.urgent,
    required this.onChanged,
  });

  final bool important;
  final bool urgent;
  final void Function({required bool important, required bool urgent}) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.priorityLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Quadrant(
              label: l.priorityImportantUrgent,
              icon: Icons.priority_high_rounded,
              selected: important && urgent,
              onTap: () => onChanged(important: true, urgent: true),
            ),
            _Quadrant(
              label: l.priorityImportantNotUrgent,
              icon: Icons.star_rounded,
              selected: important && !urgent,
              onTap: () => onChanged(important: true, urgent: false),
            ),
            _Quadrant(
              label: l.priorityNotImportantUrgent,
              icon: Icons.schedule_rounded,
              selected: !important && urgent,
              onTap: () => onChanged(important: false, urgent: true),
            ),
            _Quadrant(
              label: l.priorityNotImportantNotUrgent,
              icon: Icons.remove_circle_outline,
              selected: !important && !urgent,
              onTap: () => onChanged(important: false, urgent: false),
            ),
          ],
        ),
      ],
    );
  }
}

class _Quadrant extends StatelessWidget {
  const _Quadrant({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        fontWeight: selected ? FontWeight.bold : null,
      ),
    );
  }
}
