import 'package:flutter/material.dart';

import '../../../core/dates.dart';
import '../../../data/database.dart';
import '../../knowledge/widgets/type_icons.dart';
import '../labels.dart';

/// Knowledge card (UI_SPEC §7: `KnowledgeCard`).
///
/// Title, snippet, saved date, tags and the linked project.
class KnowledgeCard extends StatelessWidget {
  const KnowledgeCard({
    super.key,
    required this.item,
    this.typeName,
    this.tags = const [],
    this.projectName,
    this.onTap,
  });

  final Item item;
  final String? typeName;
  final List<String> tags;
  final String? projectName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = itemDisplayTitle(context, item);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    iconForType(typeName ?? ''),
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  if ((typeName ?? '').isNotEmpty)
                    Text(
                      typeName!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    formatRelativeTime(item.updatedAt),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (item.title.trim().isNotEmpty && item.bodyMd.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.bodyMd.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (tags.isNotEmpty || (projectName ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if ((projectName ?? '').isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.folder_outlined, size: 14),
                        label: Text(projectName!),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    for (final t in tags)
                      Chip(
                        label: Text(t),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
