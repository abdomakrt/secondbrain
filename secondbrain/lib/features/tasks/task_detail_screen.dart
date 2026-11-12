import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../common/widgets/content_width.dart';
import '../../core/dates.dart';
import '../../data/database.dart';
import '../common/labels.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/date_pickers.dart';
import '../common/widgets/priority_selector.dart';
import '../common/widgets/project_dropdown.dart';
import '../projects/project_detail_screen.dart';
import '../shell/app_shell.dart';

/// Task details (UI_SPEC §5, UI-04).
///
/// Everything is editable in place: title, notes, project, priority
/// (importance + urgency), due date, planned day, estimated duration, status
/// and optional subtasks.
class TaskDetailView extends StatefulWidget {
  const TaskDetailView({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<TaskDetailView> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _estimate = TextEditingController();
  final _subtask = TextEditingController();

  Task? _task;
  bool _important = false;
  bool _urgent = false;
  int? _dueAt;
  int? _plannedDate;
  int? _plannedStart;
  String? _projectId;
  String _status = 'todo';
  bool _loaded = false;
  bool _dirty = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final task = await scope.tasks.byId(widget.taskId);
    if (task == null) return;
    final subtasks = await scope.tasks.subtasksOf(task.id);
    if (!mounted) return;
    setState(() {
      _task = task;
      _title.text = task.title;
      _notes.text = task.notesMd ?? '';
      _estimate.text = task.estMinutes?.toString() ?? '';
      _important = task.isImportant;
      _urgent = task.isUrgent;
      _dueAt = task.dueAt;
      _plannedDate = task.plannedDate;
      _plannedStart = task.plannedStartMin;
      _projectId = task.projectId;
      _status = task.status;
      _loaded = true;
      _dirty = false;
    });
    // Subtasks are streamed separately below.
    assert(subtasks.isEmpty || subtasks.isNotEmpty);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _estimate.dispose();
    _subtask.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final task = _task;
    if (task == null) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      showToast(context, l.titleRequired);
      return;
    }
    final est = int.tryParse(_estimate.text.trim());
    await scope.tasks.update(
      task,
      title: title,
      notesMd: _notes.text.trim(),
      clearNotes: _notes.text.trim().isEmpty,
      isImportant: _important,
      isUrgent: _urgent,
      status: _status,
      estMinutes: est,
      clearDueAt: _dueAt == null,
      dueAt: _dueAt,
      clearPlannedDate: _plannedDate == null,
      plannedDate: _plannedDate,
      clearPlannedStart: _plannedStart == null,
      plannedStartMin: _plannedStart,
      clearProject: _projectId == null,
      projectId: _projectId,
    );
    if (!mounted) return;
    setState(() {
      _dirty = false;
    });
    await _load();
    if (!mounted) return;
    showToast(context, l.saved);
  }

  Future<void> _addSubtask() async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final task = _task;
    final text = _subtask.text.trim();
    if (task == null || text.isEmpty) return;
    await scope.tasks.create(
      title: text,
      parentTaskId: task.id,
      projectId: task.projectId,
    );
    _subtask.clear();
    if (mounted) showToast(context, l.subtaskAdded);
  }

  Future<void> _toggleSubtask(Task sub, bool done) async {
    final scope = AppScope.of(context);
    await scope.tasks.setDone(sub, done);
  }

  Future<void> _postpone() async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final task = _task;
    if (task == null) return;
    await scope.tasks.postponeToTomorrow(task);
    if (!mounted) return;
    setState(() {
      _plannedDate = dayOffset(1);
      _dirty = true;
    });
    showToast(context, l.postponedToTomorrow);
  }

  Future<void> _trash() async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final task = _task;
    if (task == null) return;
    final ok = await confirmDialog(
      context,
      title: l.moveToTrash,
      message: l.moveTaskToTrashConfirm,
      destructive: true,
      confirmLabel: l.moveToTrash,
    );
    if (!ok) return;
    await scope.tasks.trash(task.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final task = _task;

    if (task == null) {
      return const LoadingView();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        TextField(
          controller: _title,
          onChanged: (_) => _markDirty(),
          textInputAction: TextInputAction.next,
          style: Theme.of(context).textTheme.titleLarge,
          decoration: InputDecoration(
            labelText: l.titleLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        _StatusRow(
          status: _status,
          onChanged: (s) {
            setState(() {
              _status = s;
              _dirty = true;
            });
          },
          onComplete: () async {
            await scope.tasks.setDone(task, task.status != 'done');
            if (!mounted) return;
            setState(() {
              _status = task.status == 'done' ? 'done' : 'todo';
              _dirty = true;
            });
          },
        ),
        const SizedBox(height: 16),
        PrioritySelector(
          important: _important,
          urgent: _urgent,
          onChanged: ({required bool important, required bool urgent}) {
            setState(() {
              _important = important;
              _urgent = urgent;
              _dirty = true;
            });
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            DateField(
              label: l.dueDate,
              value: _dueAt,
              icon: Icons.schedule_outlined,
              onChanged: (v) {
                setState(() {
                  _dueAt = v;
                  _dirty = true;
                });
              },
            ),
            _DayField(
              label: l.plannedDay,
              value: _plannedDate,
              onChanged: (v) {
                setState(() {
                  _plannedDate = v;
                  _dirty = true;
                });
              },
            ),
            _StartField(
              label: l.plannedStart,
              value: _plannedStart,
              onChanged: (v) {
                setState(() {
                  _plannedStart = v;
                  _dirty = true;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _estimate,
          keyboardType: TextInputType.number,
          onChanged: (_) => _markDirty(),
          decoration: InputDecoration(
            labelText: l.estimatedMinutes,
            hintText: l.estimatedMinutesHint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.timelapse_outlined),
          ),
        ),
        const SizedBox(height: 16),
        _ProjectPicker(
          value: _projectId,
          onChanged: (v) {
            setState(() {
              _projectId = v;
              _dirty = true;
            });
          },
        ),
        const SizedBox(height: 16),
        _SubtasksSection(
          taskId: task.id,
          onToggle: _toggleSubtask,
          controller: _subtask,
          onAdd: _addSubtask,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notes,
          minLines: 3,
          maxLines: 8,
          onChanged: (_) => _markDirty(),
          decoration: InputDecoration(
            labelText: l.notesLabel,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('task-save'),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(l.save),
            ),
            OutlinedButton.icon(
              onPressed: _postpone,
              icon: const Icon(Icons.update_outlined),
              label: Text(l.postponeToTomorrow),
            ),
            if (task.projectId != null)
              OutlinedButton.icon(
                onPressed: () => openDetail(
                  context,
                  title: l.openProject,
                  builder: (_) => ProjectDetailScreen(projectId: task.projectId!),
                ),
                icon: const Icon(Icons.folder_outlined),
                label: Text(l.openProject),
              ),
            OutlinedButton.icon(
              onPressed: _trash,
              icon: const Icon(Icons.delete_outline),
              label: Text(l.moveToTrash),
            ),
          ],
        ),
      ],
    );
  }
}

/// Full-screen route wrapper around [TaskDetailView].
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.taskDetails)),
      body: ContentWidth(
        maxWidth: ContentWidths.details,
        child: TaskDetailView(taskId: taskId),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.status,
    required this.onChanged,
    required this.onComplete,
  });

  final String status;
  final ValueChanged<String> onChanged;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final s in const ['todo', 'doing', 'done', 'canceled'])
          ChoiceChip(
            selected: status == s,
            showCheckmark: true,
            label: Text(taskStatusLabel(context, s)),
            onSelected: (_) => onChanged(s),
          ),
        TextButton.icon(
          onPressed: onComplete,
          icon: Icon(status == 'done'
              ? Icons.check_box_outline_blank
              : Icons.check_box_outlined),
          label: Text(status == 'done' ? l.markNotDone : l.markDone),
        ),
      ],
    );
  }
}

class _DayField extends StatelessWidget {
  const _DayField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final day = await pickDay(context, current: value);
        if (day != null) onChanged(day);
      },
      icon: const Icon(Icons.event_outlined),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value == null ? '—' : relativeDayLabel(value!)),
        ],
      ),
    );
  }
}

class _StartField extends StatelessWidget {
  const _StartField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final time = await pickTimeOfDay(context, current: value);
        if (time != null) onChanged(time);
      },
      icon: const Icon(Icons.schedule_outlined),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(formatMinutesOfDay(value).isEmpty ? '—' : formatMinutesOfDay(value)),
        ],
      ),
    );
  }
}

class _ProjectPicker extends StatelessWidget {
  const _ProjectPicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ProjectDropdown(value: value, onChanged: onChanged);
  }
}

class _SubtasksSection extends StatelessWidget {
  const _SubtasksSection({
    required this.taskId,
    required this.onToggle,
    required this.controller,
    required this.onAdd,
  });

  final String taskId;
  final void Function(Task, bool) onToggle;
  final TextEditingController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.subtasks,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Task>>(
          stream: scope.tasks.watchAll(),
          builder: (context, snap) {
            final all = snap.data ?? const <Task>[];
            final subs =
                all.where((t) => t.parentTaskId == taskId).toList();
            if (subs.isEmpty) {
              return Text(
                l.noSubtasks,
                style: Theme.of(context).textTheme.bodySmall,
              );
            }
            return Column(
              children: [
                for (final s in subs)
                  CheckboxListTile(
                    value: s.status == 'done',
                    onChanged: (v) => onToggle(s, v ?? false),
                    title: Text(
                      s.title,
                      style: TextStyle(
                        decoration: s.status == 'done'
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
              ],
            );
          },
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('subtask-field'),
                controller: controller,
                decoration: InputDecoration(
                  hintText: l.newSubtaskHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: const Key('add-subtask'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              tooltip: l.addSubtask,
            ),
          ],
        ),
      ],
    );
  }
}
