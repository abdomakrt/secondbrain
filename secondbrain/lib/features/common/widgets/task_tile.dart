import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../../core/dates.dart';
import '../../../data/database.dart';
import '../../../domain/task_rules.dart';
import 'meta_label.dart';
import 'priority_indicator.dart';

/// Task row (UI_SPEC §7: `TaskItem`).
///
/// Shows the completion box, the title, the linked project, the due/planned
/// time, the priority quadrant (icon + text) and the estimated duration.
class TaskItemTile extends StatelessWidget {
  const TaskItemTile({
    super.key,
    required this.task,
    this.projectName,
    this.onToggle,
    this.onTap,
    this.onPostpone,
    this.trailing,
    this.showProject = true,
  });

  final Task task;
  final String? projectName;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onPostpone;
  final Widget? trailing;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final done = task.status == 'done';
    final overdue = isOverdue(task);

    return ListTile(
      onTap: onTap,
      leading: Checkbox(
        value: done,
        onChanged: onToggle == null ? null : (_) => onToggle!(),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      title: Text(
        task.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: done
            ? theme.textTheme.bodyLarge?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.outline,
              )
            : theme.textTheme.bodyLarge,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (showProject && (projectName ?? '').isNotEmpty)
              MetaLabel(
                icon: Icons.folder_outlined,
                text: projectName!,
              ),
            if (task.plannedDate != null)
              MetaLabel(
                icon: Icons.event_outlined,
                text: _plannedLabel(task),
              ),
            if (task.dueAt != null)
              MetaLabel(
                icon: Icons.schedule_outlined,
                text: l.dueAt(relativeDayLabel(task.dueAt!),
                    formatClock(task.dueAt!)),
                color: overdue ? theme.colorScheme.error : null,
              ),
            if (task.estMinutes != null && task.estMinutes! > 0)
              MetaLabel(
                icon: Icons.timelapse_outlined,
                text: formatMinutes(task.estMinutes!),
              ),
            PriorityIndicator(
              important: task.isImportant,
              urgent: task.isUrgent,
              compact: true,
            ),
            if (task.postponedCount > 0)
              MetaLabel(
                icon: Icons.update,
                text: l.postponedTimes(task.postponedCount),
              ),
            if (task.status == 'doing')
              MetaLabel(icon: Icons.play_circle_outline, text: l.taskStatusDoing),
          ],
        ),
      ),
      trailing: trailing ??
          (onPostpone == null
              ? null
              : IconButton(
                  tooltip: l.postponeToTomorrow,
                  icon: const Icon(Icons.update_outlined),
                  onPressed: onPostpone,
                )),
      isThreeLine: true,
    );
  }

  static String _plannedLabel(Task task) {
    final time = formatMinutesOfDay(task.plannedStartMin);
    final day = relativeDayLabel(task.plannedDate!);
    return time.isEmpty ? day : '$day • $time';
  }
}
