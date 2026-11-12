import 'package:flutter/material.dart';

/// One option inside a [FilterChipMenu].
class FilterOption<T> {
  const FilterOption(this.value, this.label);

  final T value;
  final String label;
}

/// A chip that opens a popup menu of options (UI_SPEC §7).
///
/// Used by every filter bar (type, project, tag, status). The chip shows the
/// placeholder until a value is picked, and the trailing "×" clears the
/// selection. Picking the "all" entry clears it as well.
class FilterChipMenu<T> extends StatelessWidget {
  const FilterChipMenu({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.placeholder,
    this.allLabel,
  });

  /// Label of the entry that clears the filter (hidden when null).
  final String? allLabel;

  final String tooltip;
  final IconData icon;
  final List<FilterOption<T>> options;
  final T? selected;
  final ValueChanged<T?> onSelected;

  /// Text shown while nothing is selected.
  final String placeholder;

  /// Sentinel for the "all" entry — a popup item with a null value would be
  /// swallowed by `PopupMenuButton` (it reports a cancellation instead).
  static const Object _all = Object();

  @override
  Widget build(BuildContext context) {
    final label = options
        .where((o) => o.value == selected)
        .map((o) => o.label)
        .firstOrNull;

    return PopupMenuButton<Object>(
      tooltip: tooltip,
      initialValue: selected,
      onSelected: (value) => onSelected(
        identical(value, _all) ? null : value as T?,
      ),
      itemBuilder: (context) => [
        if (allLabel != null)
          PopupMenuItem<Object>(value: _all, child: Text(allLabel!)),
        for (final o in options)
          PopupMenuItem<Object>(value: o.value, child: Text(o.label)),
      ],
      child: InputChip(
        avatar: Icon(icon, size: 16),
        label: Text(label ?? placeholder),
        onDeleted: selected == null ? null : () => onSelected(null),
      ),
    );
  }
}
