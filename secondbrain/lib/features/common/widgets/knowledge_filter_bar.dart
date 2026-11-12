import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../../app/app_scope.dart';
import '../../../data/database.dart';
import 'db_stream_builder.dart';
import 'filter_chip_menu.dart';

/// The knowledge filter bar (type / project / tag) shared by the knowledge
/// browser (UI-07) and the unified search (UI-09).
///
/// The options are read from the database, so both screens stay in sync with
/// the types, projects and tags the user actually has.
class KnowledgeFilterBar extends StatelessWidget {
  const KnowledgeFilterBar({
    super.key,
    required this.typeId,
    required this.projectId,
    required this.tagId,
    required this.onType,
    required this.onProject,
    required this.onTag,
    this.newestFirst,
    this.onNewest,
    this.onClear,
  });

  final String? typeId;
  final String? projectId;
  final String? tagId;
  final ValueChanged<String?> onType;
  final ValueChanged<String?> onProject;
  final ValueChanged<String?> onTag;

  /// Optional "newest first" toggle (search only).
  final bool? newestFirst;
  final ValueChanged<bool>? onNewest;

  /// Optional "clear all" action (shown when a filter is active).
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final active = typeId != null || projectId != null || tagId != null;

    return SizedBox(
      height: 52,
      child: DbStreamBuilder<List<ItemType>>(
        streamFactory: () => scope.itemTypes.watchBuiltin(),
        builder: (context, typeSnap) {
          final types = typeSnap.data ?? const <ItemType>[];
          return DbStreamBuilder<List<Project>>(
            streamFactory: () => scope.projects.watchList(),
            builder: (context, projectSnap) {
              final projects = projectSnap.data ?? const <Project>[];
              return DbStreamBuilder<List<Tag>>(
                streamFactory: () => scope.tags.watchAll(),
                builder: (context, tagSnap) {
                  final tags = tagSnap.data ?? const <Tag>[];
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      FilterChipMenu<String>(
                        tooltip: l.filterType,
                        icon: Icons.category_outlined,
                        placeholder: l.filterType,
                        allLabel: l.all,
                        selected: typeId,
                        onSelected: onType,
                        options: [
                          for (final t in types)
                            FilterOption(t.id, t.name),
                        ],
                      ),
                      const SizedBox(width: 8),
                      FilterChipMenu<String>(
                        tooltip: l.filterProject,
                        icon: Icons.folder_outlined,
                        placeholder: l.filterProject,
                        allLabel: l.all,
                        selected: projectId,
                        onSelected: onProject,
                        options: [
                          for (final p in projects)
                            FilterOption(p.id, p.name),
                        ],
                      ),
                      const SizedBox(width: 8),
                      FilterChipMenu<String>(
                        tooltip: l.filterTag,
                        icon: Icons.sell_outlined,
                        placeholder: l.filterTag,
                        allLabel: l.all,
                        selected: tagId,
                        onSelected: onTag,
                        options: [
                          for (final t in tags)
                            FilterOption(t.id, t.name),
                        ],
                      ),
                      if (newestFirst != null && onNewest != null) ...[
                        const SizedBox(width: 8),
                        FilterChip(
                          avatar: const Icon(Icons.new_releases_outlined, size: 16),
                          label: Text(l.newestFirst),
                          selected: newestFirst!,
                          onSelected: onNewest,
                        ),
                      ],
                      if (active && onClear != null) ...[
                        const SizedBox(width: 8),
                        ActionChip(
                          label: Text(l.clearFilters),
                          onPressed: onClear,
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
