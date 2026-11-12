import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../../data/database.dart';
import '../../../app/app_scope.dart';
import 'db_stream_builder.dart';

/// A project picker used across the app.
///
/// The currently selected project is always present in the list — even before
/// the project list arrives — so the dropdown never breaks its contract.
class ProjectDropdown extends StatelessWidget {
  const ProjectDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.noneLabel,
    this.prefixIcon = Icons.folder_outlined,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String? label;
  final String? noneLabel;
  final IconData prefixIcon;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    return DbStreamBuilder<List<Project>>(
      streamFactory: () => scope.projects.watchList(),
      builder: (context, snap) {
        final projects = snap.data ?? const <Project>[];
        final items = <DropdownMenuItem<String?>>[
          DropdownMenuItem<String?>(
            value: null,
            child: Text(noneLabel ?? l.noProject),
          ),
          for (final p in projects)
            DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
        ];
        final selected = value;
        if (selected != null && !projects.any((p) => p.id == selected)) {
          items.add(
            DropdownMenuItem<String?>(
              value: selected,
              child: Text('…'),
            ),
          );
        }
        return DropdownButtonFormField<String?>(
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label ?? l.linkedProject,
            prefixIcon: Icon(prefixIcon),
            border: const OutlineInputBorder(),
          ),
          items: items,
          onChanged: onChanged,
        );
      },
    );
  }
}
