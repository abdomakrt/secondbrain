import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../data/database.dart';
import '../../domain/progress.dart';
import '../common/labels.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/db_stream_builder.dart';
import '../common/widgets/project_card.dart';
import '../shell/app_shell.dart';
import 'project_detail_screen.dart';
import 'project_edit_screen.dart';

/// Projects screen (UI_SPEC §5, UI-05).
///
/// Views: active, planned, paused, completed, archived. Every card shows the
/// progress, the done/remaining task counts, the last activity and the
/// recorded next step.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  String _status = 'active';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: l.searchProjectsHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'active', label: Text(l.activeProjects)),
              ButtonSegment(value: 'planned', label: Text(l.plannedProjects)),
              ButtonSegment(value: 'paused', label: Text(l.pausedProjects)),
              ButtonSegment(value: 'completed', label: Text(l.completedProjects)),
              ButtonSegment(value: 'archived', label: Text(l.archivedProjects)),
            ],
            selected: {_status},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Project>>(
            stream: scope.projects.watchList(status: _status),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const LoadingView();
              }
              final projects = snap.data!
                  .where((p) =>
                      _query.isEmpty ||
                      p.name.contains(_query) ||
                      p.goal.contains(_query))
                  .toList();
              if (projects.isEmpty) {
                return EmptyState(
                  icon: Icons.folder_outlined,
                  title: l.emptyProjects,
                  message: l.emptyProjectsHint,
                );
              }
              return DbStreamBuilder<List<Task>>(
                streamFactory: () => scope.tasks.watchAll(),
                builder: (context, taskSnap) {
                  final tasks = taskSnap.data;
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 96),
                    itemCount: projects.length,
                    itemBuilder: (context, i) {
                      final project = projects[i];
                      final projectTasks = tasks == null
                          ? const <Task>[]
                          : tasks
                              .where((t) => t.projectId == project.id)
                              .toList();
                      final progress = computeProgress(
                        progressMode: project.progressMode,
                        manualProgress: project.manualProgress,
                        tasks: projectTasks,
                      );
                      final done = projectTasks.where((t) => t.status == 'done').length;
                      final remaining = projectTasks
                          .where((t) => t.status != 'done' &&
                              t.status != 'canceled')
                          .length;
                      final lastActivity = _lastActivity(project, projectTasks);
                      return ProjectCard(
                        project: project,
                        progress: progress,
                        doneTasks: done,
                        remainingTasks: remaining,
                        lastActivityAt: lastActivity,
                        tasksLoaded: tasks != null,
                        onTap: () => openDetail(
                          context,
                          title: project.name,
                          builder: (_) =>
                              ProjectDetailScreen(projectId: project.id),
                        ),
                        onToggleStatus: () => _cycleStatus(context, project),
                        onEdit: () => _edit(context, project),
                        onDelete: () => _delete(context, project),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  int? _lastActivity(Project project, List<Task> tasks) {
    var latest = project.updatedAt;
    for (final t in tasks) {
      if (t.updatedAt > latest) latest = t.updatedAt;
    }
    return latest;
  }

  /// Opens the edit form of a project.
  Future<void> _edit(BuildContext context, Project project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectEditScreen(projectId: project.id),
      ),
    );
  }

  /// Moves a project to the trash (soft delete — the children survive).
  Future<void> _delete(BuildContext context, Project project) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final confirmed = await confirmDialog(
      context,
      title: l.deleteProject,
      message: l.deleteProjectConfirm,
      confirmLabel: l.deleteProject,
      destructive: true,
    );
    if (!confirmed) return;
    await scope.projects.trash(project.id);
    if (!context.mounted) return;
    showToast(context, l.movedToTrash);
  }

  Future<void> _cycleStatus(BuildContext context, Project project) async {    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    const order = ['planned', 'active', 'paused', 'completed', 'archived'];
    final next = order[(order.indexOf(project.status) + 1) % order.length];
    await scope.projects.update(project, status: next);
    if (!context.mounted) return;
    showToast(
      context,
      '${l.statusChanged}: ${projectStatusLabel(context, next)}',
    );
  }
}
