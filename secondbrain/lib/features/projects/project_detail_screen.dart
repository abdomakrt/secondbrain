import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../common/widgets/content_width.dart';
import '../../data/database.dart';
import '../../data/repositories/local_paths_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/progress.dart';
import '../common/labels.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/db_stream_builder.dart';
import '../common/widgets/knowledge_card.dart';
import '../common/widgets/linked_folders.dart';
import '../common/widgets/progress_bar.dart';
import '../common/widgets/source_link_tile.dart';
import '../common/widgets/task_tile.dart';
import '../knowledge/item_detail_screen.dart';
import '../knowledge/item_edit_screen.dart';
import '../shell/app_shell.dart';
import '../tasks/task_detail_screen.dart';
import 'project_edit_screen.dart';

/// Project details (UI_SPEC §5, UI-06).
///
/// The workspace of a project: goal, status, progress, last activity, the
/// stop point and the next step, plus tabs for tasks, knowledge, decisions,
/// attachments and the activity log.
class ProjectDetailView extends StatefulWidget {
  const ProjectDetailView({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends State<ProjectDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return StreamBuilder<Project?>(
      stream: (scope.db.select(scope.db.projects)
            ..where((p) =>
                p.id.equals(widget.projectId) & p.deletedAt.isNull()))
          .watchSingleOrNull(),
      builder: (context, snap) {
        final project = snap.data;
        if (project == null) {
          return const LoadingView();
        }
        return Column(
          children: [
            _Header(project: project),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: l.overview),
                Tab(text: l.tasksTitle),
                Tab(text: l.knowledgeTitle),
                Tab(text: l.decisions),
                Tab(text: l.filesAndAttachments),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _OverviewTab(project: project),
                  _TasksTab(project: project),
                  _KnowledgeTab(project: project),
                  _DecisionsTab(project: project),
                  _FilesTab(project: project),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Full-screen route wrapper around [ProjectDetailView].
class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.projectDetails)),
      body: ContentWidth(
        maxWidth: ContentWidths.details,
        child: ProjectDetailView(projectId: projectId),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);

    return DbStreamBuilder<List<Task>>(
      streamFactory: () => scope.tasks.watchAll(projectId: project.id),
      builder: (context, snap) {
        final tasks = snap.data ?? const <Task>[];
        final progress = computeProgress(
          progressMode: project.progressMode,
          manualProgress: project.manualProgress,
          tasks: tasks,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Chip(
                    label: Text(projectStatusLabel(context, project.status)),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (project.goal.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(project.goal, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 10),
              ProgressBar(progress: progress),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _editStopPoint(context, project),
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(l.stopPointAndNextStep),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _toggleCaptureProject(context, project),
                    icon: const Icon(Icons.center_focus_strong_outlined),
                    label: Text(l.setActiveCaptureProject),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _changeStatus(context, project),
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(l.changeStatus),
                  ),
                  PopupMenuButton<String>(
                    tooltip: l.options,
                    onSelected: (value) {
                      if (value == 'edit') _editProject(context, project);
                      if (value == 'delete') _deleteProject(context, project);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text(l.editProject),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text(l.deleteProject),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editProject(BuildContext context, Project project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectEditScreen(projectId: project.id),
      ),
    );
  }

  /// Moves the project to the trash (soft delete — tasks and knowledge
  /// survive, detached).
  Future<void> _deleteProject(BuildContext context, Project project) async {
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
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _editStopPoint(BuildContext context, Project project) async {
    final scope = AppScope.of(context);
    final result = await showDialog<_StopPoint>(
      context: context,
      builder: (_) => _StopPointDialog(
        lastStop: project.lastStop ?? '',
        nextStep: project.nextStep ?? '',
      ),
    );
    if (result == null) return;
    await scope.projects.update(
      project,
      lastStop: result.lastStop,
      clearLastStop: result.lastStop.isEmpty,
      nextStep: result.nextStep,
      clearNextStep: result.nextStep.isEmpty,
    );
  }

  Future<void> _toggleCaptureProject(BuildContext context, Project project) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final current =
        await scope.settings.get(SettingsRepository.keyActiveCaptureProject);
    final next = current == project.id ? null : project.id;
    await scope.settings.set(
        SettingsRepository.keyActiveCaptureProject, next ?? '');
    if (!context.mounted) return;
    showToast(
      context,
      next == null ? l.captureProjectCleared : l.captureProjectSet,
    );
  }

  Future<void> _changeStatus(BuildContext context, Project project) async {
    final scope = AppScope.of(context);
    const order = ['planned', 'active', 'paused', 'completed', 'archived'];
    final next = order[(order.indexOf(project.status) + 1) % order.length];
    await scope.projects.update(project, status: next);
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (project.description.isNotEmpty) ...[
          Text(l.descriptionLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(project.description),
          const SizedBox(height: 16),
        ],
        _Row(
          label: l.lastStop,
          value: (project.lastStop ?? '').isEmpty ? '—' : project.lastStop!,
        ),
        _Row(
          label: l.nextStep,
          value: (project.nextStep ?? '').isEmpty ? '—' : project.nextStep!,
        ),
        _Row(label: l.status, value: projectStatusLabel(context, project.status)),
        const SizedBox(height: 16),
        Text(l.sourceUrl, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        SourceLinkTile(url: project.sourceUrl),
        const SizedBox(height: 20),
        LinkedFoldersSection(
          ownerType: LocalPathsRepository.ownerProject,
          ownerId: project.id,
        ),
        const SizedBox(height: 12),
        Text(l.activityLogUnavailable, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TasksTab extends StatelessWidget {
  const _TasksTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return DbStreamBuilder<List<Task>>(
      streamFactory: () => scope.tasks.watchAll(projectId: project.id),
      builder: (context, snap) {
        final tasks = (snap.data ?? const <Task>[])
            .where((t) => t.parentTaskId == null)
            .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final task = await scope.tasks.create(
                      title: l.newTask,
                      projectId: project.id,
                    );
                    if (!context.mounted) return;
                    await openDetail(
                      context,
                      title: task.title,
                      builder: (_) => TaskDetailScreen(taskId: task.id),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(l.addTaskToProject),
                ),
              ),
            ),
            if (tasks.isEmpty)
              Expanded(
                child: EmptyState(
                  icon: Icons.checklist_outlined,
                  title: l.noTasksInProject,
                  message: l.noTasksInProjectHint,
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    return TaskItemTile(
                      task: task,
                      showProject: false,
                      onToggle: () =>
                          scope.tasks.setDone(task, task.status != 'done'),
                      onTap: () => openDetail(
                        context,
                        title: task.title,
                        builder: (_) => TaskDetailScreen(taskId: task.id),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KnowledgeTab extends StatelessWidget {
  const _KnowledgeTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return StreamBuilder<List<Item>>(
      stream: (scope.db.select(scope.db.items)
            ..where((i) =>
                i.deletedAt.isNull() & i.projectId.equals(project.id)))
          .watch(),
      builder: (context, snap) {
        final items = snap.data ?? const <Item>[];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ItemEditScreen(initialProjectId: project.id),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l.addKnowledgeToProject),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? EmptyState(
                      icon: Icons.lightbulb_outline,
                      title: l.noKnowledgeInProject,
                      message: l.noKnowledgeInProjectHint,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return KnowledgeCard(
                          item: item,
                          projectName: project.name,
                          onTap: () => openDetail(
                            context,
                            title: item.title,
                            builder: (_) => ItemDetailScreen(itemId: item.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DecisionsTab extends StatelessWidget {
  const _DecisionsTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return DbStreamBuilder<List<ItemType>>(
      streamFactory: () => scope.itemTypes.watchBuiltin(),
      builder: (context, typeSnap) {
        final decisionType =
            (typeSnap.data ?? const <ItemType>[]).where((t) => t.name == 'قرار');
        return DbStreamBuilder<List<Item>>(
          streamFactory: () => (scope.db.select(scope.db.items)
                ..where((i) =>
                    i.deletedAt.isNull() & i.projectId.equals(project.id)))
              .watch(),
          builder: (context, snap) {
            final all = snap.data ?? const <Item>[];
            final items = decisionType.isEmpty
                ? all
                : all.where((i) => i.typeId == decisionType.first.id).toList();
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.gavel_outlined,
                title: l.noDecisions,
                message: l.noDecisionsHint,
              );
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return KnowledgeCard(
                  item: item,
                  typeName: 'قرار',
                  onTap: () => openDetail(
                    context,
                    title: item.title,
                    builder: (_) => ItemDetailScreen(itemId: item.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _FilesTab extends StatelessWidget {
  const _FilesTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return DbStreamBuilder<List<Attachment>>(
      streamFactory: () => scope.attachments.watchFor('project', project.id),
      builder: (context, snap) {
        final rows = snap.data ?? const <Attachment>[];
        if (rows.isEmpty) {
          return EmptyState(
            icon: Icons.attach_file,
            title: l.noAttachments,
            message: l.noAttachmentsHint,
          );
        }
        return ListView(
          children: rows
              .map((a) => ListTile(
                    leading: const Icon(Icons.attach_file),
                    title: Text(a.filename),
                    subtitle: Text('${a.size} bytes'),
                  ))
              .toList(),
        );
      },
    );
  }
}


/// The stop point and the next step of a project (one dialog, two fields).
class _StopPoint {
  const _StopPoint(this.lastStop, this.nextStep);

  final String lastStop;
  final String nextStep;
}

class _StopPointDialog extends StatefulWidget {
  const _StopPointDialog({required this.lastStop, required this.nextStep});

  final String lastStop;
  final String nextStep;

  @override
  State<_StopPointDialog> createState() => _StopPointDialogState();
}

class _StopPointDialogState extends State<_StopPointDialog> {
  late final TextEditingController _lastStop =
      TextEditingController(text: widget.lastStop);
  late final TextEditingController _nextStep =
      TextEditingController(text: widget.nextStep);

  @override
  void dispose() {
    _lastStop.dispose();
    _nextStep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.stopPointAndNextStep),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _lastStop,
            decoration: InputDecoration(labelText: l.lastStop),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nextStep,
            decoration: InputDecoration(labelText: l.nextStep),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _StopPoint(_lastStop.text.trim(), _nextStep.text.trim()),
          ),
          child: Text(l.save),
        ),
      ],
    );
  }
}
