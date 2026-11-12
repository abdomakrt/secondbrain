import 'package:flutter/material.dart';

/// Tag chip (UI_SPEC §7: `TagChip`).
///
/// A compact chip for the tags of an item; optionally removable or tappable.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.onDeleted,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      selected: selected,
      onPressed: onTap,
      onDeleted: onDeleted,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
