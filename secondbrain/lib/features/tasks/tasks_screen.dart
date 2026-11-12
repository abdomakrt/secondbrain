import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../core/dates.dart';
import '../../data/database.dart';
import '../../domain/task_rules.dart';
import '../common/labels.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/db_stream_builder.dart';
import '../common/widgets/filter_chip_menu.dart';
import '../common/widgets/task_tile.dart';
import '../shell/app_shell.dart';
import 'task_detail_screen.dart';

/// Tasks screen (UI_SPEC §5, UI-03).
///
/// Four views — today, upcoming, overdue, all — with filters by project,
/// status and priority. The day plan can be reordered and every task can be
/// completed straight from the list.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  TaskView _view = TaskView.today;
  String? _projectId;
  String? _status;
  bool? _importantOnly;
  Map<String, String> _projectNames = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final scope = AppScope.of(context);
    final projects = await scope.projects.all();
    if (!mounted) return;
    setState(() {
      _projectNames = {for (final p in projects) p.id: p.name};
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return Column(
      children: [
        _ViewBar(
          view: _view,
          onChanged: (v) => setState(() => _view = v),
        ),
        _FilterBar(
          selectedProject: _projectId,
          selectedStatus: _status,
          importantOnly: _importantOnly,
          onProject: (v) => setState(() => _projectId = v),
          onStatus: (v) => setState(() => _status = v),
          onImportant: (v) => setState(() => _importantOnly = v),
          onClear: () => setState(() {
            _projectId = null;
            _status = null;
            _importantOnly = null;
          }),
        ),
        Expanded(
          child: StreamBuilder<List<Task>>(
            stream: _stream(scope),
            builder: (context, snap) {
              if (snap.hasError) {
                return EmptyState(
                  icon: Icons.error_outline,
                  title: l.errorTitle,
                  message: '${snap.error}',
                  actionLabel: l.retry,
                  onAction: () => setState(() {}),
                );
              }
              if (!snap.hasData) {
                return const LoadingView();
              }
              final tasks = _applyFilters(snap.data!);
              if (tasks.isEmpty) {
                return EmptyState(
                  icon: Icons.checklist_outlined,
                  title: l.emptyTasks,
                  message: l.emptyTasksHint,
                );
              }
              return _TaskList(
                tasks: tasks,
                projectNames: _projectNames,
                onToggle: (task) async {
                  await scope.tasks.setDone(task, task.status != 'done');
                },
                onOpen: (task) => openDetail(
                  context,
                  title: task.title,
                  builder: (_) => TaskDetailScreen(taskId: task.id),
                ),
                onPostpone: (task) async {
                  await scope.tasks.postponeToTomorrow(task);
                  if (context.mounted) showToast(context, l.postponedToTomorrow);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Stream<List<Task>> _stream(AppScope scope) {
    switch (_view) {
      case TaskView.today:
        return scope.tasks.watchPlannedOn(startOfToday(),
            projectId: _projectId);
      case TaskView.upcoming:
        return scope.tasks.watchUpcoming(projectId: _projectId);
      case TaskView.overdue:
        return scope.tasks.watchOverdue(projectId: _projectId);
      case TaskView.all:
        return scope.tasks.watchAll(projectId: _projectId);
    }
  }

  List<Task> _applyFilters(List<Task> tasks) {
    final out = <Task>[];
    for (final t in tasks) {
      if (t.parentTaskId != null) continue; // subtasks live in the detail
      if (_status != null && t.status != _status) continue;
      if (_importantOnly == true && !t.isImportant) continue;
      if (_importantOnly == false && t.isImportant) continue;
      out.add(t);
    }
    out.sort(compareTasks);
    return out;
  }
}

/// The list itself, with reorder support in the "today" view.
class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.tasks,
    required this.projectNames,
    required this.onToggle,
    required this.onOpen,
    required this.onPostpone,
  });

  final List<Task> tasks;
  final Map<String, String> projectNames;
  final void Function(Task) onToggle;
  final void Function(Task) onOpen;
  final void Function(Task) onPostpone;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final task = tasks[i];
        return TaskItemTile(
          task: task,
          projectName: task.projectId == null
              ? null
              : projectNames[task.projectId],
          onToggle: () => onToggle(task),
          onTap: () => onOpen(task),
          onPostpone: task.status == 'done' ? null : () => onPostpone(task),
        );
      },
    );
  }
}

class _ViewBar extends StatelessWidget {
  const _ViewBar({required this.view, required this.onChanged});

  final TaskView view;
  final ValueChanged<TaskView> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SegmentedButton<TaskView>(
        segments: [
          ButtonSegment(value: TaskView.today, label: Text(l.today)),
          ButtonSegment(value: TaskView.upcoming, label: Text(l.upcoming)),
          ButtonSegment(value: TaskView.overdue, label: Text(l.overdue)),
          ButtonSegment(value: TaskView.all, label: Text(l.allTasks)),
        ],
        selected: {view},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedProject,
    required this.selectedStatus,
    required this.importantOnly,
    required this.onProject,
    required this.onStatus,
    required this.onImportant,
    required this.onClear,
  });

  final String? selectedProject;
  final String? selectedStatus;
  final bool? importantOnly;
  final ValueChanged<String?> onProject;
  final ValueChanged<String?> onStatus;
  final ValueChanged<bool?> onImportant;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final active = selectedProject != null ||
        selectedStatus != null ||
        importantOnly != null;

    return SizedBox(
      height: 52,
      child: DbStreamBuilder<List<Project>>(
        streamFactory: () => scope.projects.watchList(),
        builder: (context, snap) {
          final list = snap.data ?? const <Project>[];
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              FilterChipMenu<String>(
                tooltip: l.filterProject,
                icon: Icons.folder_outlined,
                placeholder: l.filterProject,
                allLabel: l.all,
                selected: selectedProject,
                onSelected: onProject,
                options: [
                  for (final p in list) FilterOption(p.id, p.name),
                ],
              ),
              const SizedBox(width: 8),
              FilterChipMenu<String>(
                tooltip: l.filterStatus,
                icon: Icons.flag_outlined,
                placeholder: l.filterStatus,
                allLabel: l.all,
                selected: selectedStatus,
                onSelected: onStatus,
                options: [
                  for (final s in const ['todo', 'doing', 'done', 'canceled'])
                    FilterOption(s, taskStatusLabel(context, s)),
                ],
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.star_outline, size: 16),
                label: Text(l.importantOnly),
                selected: importantOnly == true,
                onSelected: (v) => onImportant(v ? true : null),
              ),
              if (active) ...[
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(l.clearFilters),
                  onPressed: onClear,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
