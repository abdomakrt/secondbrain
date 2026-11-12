import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../core/dates.dart';
import '../../data/database.dart';
import '../../domain/progress.dart';
import '../../domain/task_rules.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/db_stream_builder.dart';
import '../common/widgets/knowledge_card.dart';
import '../common/widgets/progress_bar.dart';
import '../common/widgets/task_tile.dart';
import '../knowledge/item_detail_screen.dart';
import '../projects/project_detail_screen.dart';
import '../shell/app_shell.dart';
import '../tasks/task_detail_screen.dart';

/// Dashboard (UI_SPEC §5, UI-02).
///
/// Answers «what deserves my attention right now?» — today's summary, the
/// most important tasks, the day timeline, the active projects, the current
/// course, the latest saved knowledge, the inbox and short alerts.
///
/// Nothing is shown "all at once": every section is limited and links to the
/// full list.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onSelectSection});

  final ValueChanged<AppSection> onSelectSection;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final now = DateTime.now();
    final today = startOfToday();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        _Greeting(date: now),
        const SizedBox(height: 16),
        StreamBuilder<List<Task>>(
          stream: scope.tasks.watchAll(),
          builder: (context, snap) {
            final tasks = snap.data ?? const <Task>[];
            final topLevel = tasks.where((t) => t.parentTaskId == null).toList();
            final todayTasks = topLevel
                .where((t) => t.plannedDate == today)
                .toList()
              ..sort(compareTasks);
            final overdue = topLevel.where((t) => isOverdue(t)).toList()
              ..sort((a, b) => (a.dueAt ?? 0).compareTo(b.dueAt ?? 0));
            final doneCount = todayTasks.where((t) => t.status == 'done').length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: l.todaySummary,
                  icon: Icons.today_outlined,
                  actionLabel: l.viewAll,
                  onAction: () => widget.onSelectSection(AppSection.tasks),
                ),
                _SummaryRow(
                  total: todayTasks.length,
                  done: doneCount,
                  remaining: todayTasks.length - doneCount,
                  overdue: overdue.length,
                ),
                const SizedBox(height: 16),
                SectionHeader(
                  title: l.topTasksToday,
                  icon: Icons.priority_high_rounded,
                ),
                if (todayTasks.isEmpty)
                  _Hint(text: l.noTasksToday)
                else
                  for (final task in todayTasks.take(5))
                    TaskItemTile(
                      task: task,
                      onToggle: () =>
                          scope.tasks.setDone(task, task.status != 'done'),
                      onTap: () => openDetail(
                        context,
                        title: task.title,
                        builder: (_) => TaskDetailScreen(taskId: task.id),
                      ),
                    ),
                const SizedBox(height: 16),
                SectionHeader(
                  title: l.dayTimeline,
                  icon: Icons.schedule_outlined,
                ),
                _Timeline(tasks: todayTasks),
                if (overdue.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionHeader(
                    title: l.overdueTasks,
                    icon: Icons.warning_amber_outlined,
                  ),
                  for (final task in overdue.take(3))
                    TaskItemTile(
                      task: task,
                      onToggle: () =>
                          scope.tasks.setDone(task, task.status != 'done'),
                      onTap: () => openDetail(
                        context,
                        title: task.title,
                        builder: (_) => TaskDetailScreen(taskId: task.id),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _ActiveProjects(onSelectSection: widget.onSelectSection),
        const SizedBox(height: 16),
        const _CurrentCourse(),
        const SizedBox(height: 16),
        const _RecentKnowledge(),
        const SizedBox(height: 16),
        _InboxSummary(onSelectSection: widget.onSelectSection),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hour = date.hour;
    final greeting = hour < 12
        ? l.greetingMorning
        : hour < 18
            ? l.greetingAfternoon
            : l.greetingEvening;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${weekdayNameAr(date)} ${date.day} ${monthNameAr(date)} ${date.year}',
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 2),
        Text(
          greeting,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.total,
    required this.done,
    required this.remaining,
    required this.overdue,
  });

  final int total;
  final int done;
  final int remaining;
  final int overdue;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        _SummaryTile(
          label: l.totalTasks,
          value: '$total',
          icon: Icons.list_alt_outlined,
        ),
        _SummaryTile(
          label: l.completedTasks,
          value: '$done',
          icon: Icons.check_circle_outline,
        ),
        _SummaryTile(
          label: l.remainingTasks,
          value: '$remaining',
          icon: Icons.pending_outlined,
        ),
        _SummaryTile(
          label: l.overdueTasks,
          value: '$overdue',
          icon: Icons.warning_amber_outlined,
          highlight: overdue > 0,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight
                ? theme.colorScheme.error
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: highlight
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: theme.textTheme.labelSmall, maxLines: 1),
          ],
        ),
      ),
    );
  }
}

/// The day plan as a simple time line (tasks with a planned start).
class _Timeline extends StatelessWidget {
  const _Timeline({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheduled = tasks.where((t) => t.plannedStartMin != null).toList()
      ..sort((a, b) =>
          (a.plannedStartMin ?? 0).compareTo(b.plannedStartMin ?? 0));
    if (scheduled.isEmpty) {
      return _Hint(text: l.noScheduledTasks);
    }
    return Column(
      children: [
        for (final task in scheduled.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    formatMinutesOfDay(task.plannedStartMin),
                    style: theme.textTheme.labelMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  width: 3,
                  height: 22,
                  color: task.status == 'done'
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: task.status == 'done'
                        ? theme.textTheme.bodyMedium
                            ?.copyWith(decoration: TextDecoration.lineThrough)
                        : theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActiveProjects extends StatelessWidget {
  const _ActiveProjects({required this.onSelectSection});

  final ValueChanged<AppSection> onSelectSection;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return StreamBuilder<List<Project>>(
      stream: scope.projects.watchList(status: 'active'),
      builder: (context, snap) {
        final projects = snap.data ?? const <Project>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: l.activeProjects,
              icon: Icons.folder_outlined,
              actionLabel: l.viewAll,
              actionKey: const Key('dashboard-projects-all'),
              onAction: () => onSelectSection(AppSection.projects),
            ),
            if (projects.isEmpty)
              _Hint(text: l.noActiveProjects)
            else
              DbStreamBuilder<List<Task>>(
                streamFactory: () => scope.tasks.watchAll(),
                builder: (context, taskSnap) {
                  final tasks = taskSnap.data;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final project in projects.take(3))
                        _ProjectRow(
                          project: project,
                          tasks: tasks == null
                              ? const <Task>[]
                              : tasks
                                  .where((t) => t.projectId == project.id)
                                  .toList(),
                          tasksLoaded: tasks != null,
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.tasks,
    this.tasksLoaded = true,
  });

  final Project project;
  final List<Task> tasks;

  /// False while the task list is still loading — the progress is then
  /// unknown and must not be shown as «لا مهام».
  final bool tasksLoaded;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final progress = computeProgress(
      progressMode: project.progressMode,
      manualProgress: project.manualProgress,
      tasks: tasks,
    );
    return InkWell(
      onTap: () => openDetail(
        context,
        title: project.name,
        builder: (_) => ProjectDetailScreen(projectId: project.id),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formatRelativeTime(project.updatedAt),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (tasksLoaded)
              ProgressBar(progress: progress)
            else
              const LinearProgressIndicator(minHeight: 8),
            if ((project.nextStep ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${l.nextStep}: ${project.nextStep}',
                style: theme.textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentCourse extends StatelessWidget {
  const _CurrentCourse();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return StreamBuilder<List<Course>>(
      stream: scope.courses.watchList(status: 'active'),
      builder: (context, snap) {
        final courses = snap.data ?? const <Course>[];
        if (courses.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: l.currentCourse, icon: Icons.school_outlined),
              _Hint(text: l.noActiveCourses),
            ],
          );
        }
        final course = courses.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: l.currentCourse, icon: Icons.school_outlined),
            StreamBuilder<List<Lesson>>(
              stream: scope.courses.watchLessons(course.id),
              builder: (context, lessonSnap) {
                final lessons = lessonSnap.data ?? const <Lesson>[];
                final done = lessons.where((x) => x.status == 'done').length;
                final next = lessons.where((x) => x.status != 'done').toList();
                final progress = Progress(
                  done: done,
                  total: lessons.length,
                  manual: 0,
                  manualMode: false,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ProgressBar(progress: progress),
                    if (next.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${l.nextLesson}: ${next.first.title}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _RecentKnowledge extends StatelessWidget {
  const _RecentKnowledge();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l.recentKnowledge,
          icon: Icons.lightbulb_outline,
          actionLabel: l.viewAll,
          onAction: () {},
        ),
        StreamBuilder<List<Item>>(
          stream: scope.items.watchList(
            onlyInbox: false,
            onlyArchived: false,
          ),
          builder: (context, snap) {
            final items = snap.data ?? const <Item>[];
            if (items.isEmpty) {
              return _Hint(text: l.emptyKnowledgeHint);
            }
            return Column(
              children: [
                for (final item in items.take(3))
                  KnowledgeCard(
                    item: item,
                    onTap: () => openDetail(
                      context,
                      title: item.title,
                      builder: (_) => ItemDetailScreen(itemId: item.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InboxSummary extends StatelessWidget {
  const _InboxSummary({required this.onSelectSection});

  final ValueChanged<AppSection> onSelectSection;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return StreamBuilder<List<Item>>(
      stream: scope.items.watchList(onlyInbox: true, onlyArchived: false),
      builder: (context, snap) {
        final items = snap.data ?? const <Item>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: l.inboxNeedsOrganizing,
              icon: Icons.inbox_outlined,
              actionLabel: l.viewAll,
              onAction: () => onSelectSection(AppSection.inbox),
            ),
            if (items.isEmpty)
              _Hint(text: l.emptyInboxHint)
            else
              for (final item in items.take(3))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lightbulb_outline),
                  title: Text(
                    item.title.isEmpty ? item.bodyMd : item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => openDetail(
                    context,
                    title: item.title,
                    builder: (_) => ItemDetailScreen(itemId: item.id),
                  ),
                ),
          ],
        );
      },
    );
  }
}

/// A one-line hint inside a dashboard section.
class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
