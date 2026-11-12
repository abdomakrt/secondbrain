import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../../data/database.dart';
import '../../../domain/progress.dart';
import '../labels.dart';
import 'progress_bar.dart';

/// Project card (UI_SPEC §7: `ProjectCard`).
///
/// Shows the name, a short description, the status, the progress bar, the
/// done/remaining task counts, the last activity and the recorded next step.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.progress,
    required this.doneTasks,
    required this.remainingTasks,
    this.lastActivityAt,
    this.onTap,
    this.onToggleStatus,
    this.onEdit,
    this.onDelete,
    this.tasksLoaded = true,
  });

  final Project project;
  final Progress progress;
  final int doneTasks;
  final int remainingTasks;
  final int? lastActivityAt;
  final VoidCallback? onTap;
  final VoidCallback? onToggleStatus;

  /// Opens the edit form (project card menu).
  final VoidCallback? onEdit;

  /// Moves the project to the trash (project card menu).
  final VoidCallback? onDelete;

  /// False while the task list is still loading: the progress is unknown and
  /// must not be presented as «لا مهام».
  final bool tasksLoaded;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    projectStatusIcon(project.status),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onToggleStatus != null)
                    PopupMenuButton<String>(
                      tooltip: l.changeStatus,
                      onSelected: (_) => onToggleStatus!(),
                      itemBuilder: (context) => [
                        for (final s in const [
                          'planned',
                          'active',
                          'paused',
                          'completed',
                          'archived',
                        ])
                          PopupMenuItem<String>(
                            value: s,
                            child: Text(projectStatusLabel(context, s)),
                          ),
                      ],
                      child: Chip(
                        label: Text(projectStatusLabel(context, project.status)),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  else
                    Chip(
                      label: Text(projectStatusLabel(context, project.status)),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onEdit != null || onDelete != null)
                    PopupMenuButton<String>(
                      tooltip: l.options,
                      onSelected: (value) {
                        if (value == 'edit') onEdit?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text(l.editProject),
                          ),
                        if (onDelete != null)
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(l.deleteProject),
                          ),
                      ],
                    ),
                ],
              ),
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 10),
              if (tasksLoaded)
                ProgressBar(progress: progress)
              else
                const LinearProgressIndicator(minHeight: 8),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    l.tasksDoneOf(doneTasks, remainingTasks),
                    style: theme.textTheme.labelSmall,
                  ),
                  if (lastActivityAt != null)
                    Text(
                      '${l.lastActivity}: ${_relative(lastActivityAt!)}',
                      style: theme.textTheme.labelSmall,
                    ),
                ],
              ),
              if ((project.nextStep ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_forward, size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${l.nextStep}: ${project.nextStep}',
                        style: theme.textTheme.labelSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  static String _relative(int ms) {
    final diff = DateTime.now().millisecondsSinceEpoch - ms;
    if (diff < 60 * 1000) return 'الآن';
    if (diff < 60 * 60 * 1000) return 'قبل ${diff ~/ 60000} د';
    if (diff < 24 * 60 * 60 * 1000) return 'قبل ${diff ~/ 3600000} س';
    final days = diff ~/ 86400000;
    if (days == 1) return 'أمس';
    return 'قبل $days يوم';
  }
}
