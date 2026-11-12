import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../core/dates.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/content_width.dart';
import '../common/widgets/date_pickers.dart';
import '../common/widgets/priority_selector.dart';
import '../common/widgets/project_dropdown.dart';

/// Create a task (quick form used by the quick-add menu and the FAB).
class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({super.key});

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _title = TextEditingController();
  final _estimate = TextEditingController();

  bool _important = false;
  bool _urgent = false;
  int? _dueAt;
  int? _plannedDate;
  int? _plannedStart;
  String? _projectId;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _estimate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (_saving) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      showToast(context, l.titleRequired);
      return;
    }
    setState(() => _saving = true);
    final scope = AppScope.of(context);
    await scope.tasks.create(
      title: title,
      projectId: _projectId,
      isImportant: _important,
      isUrgent: _urgent,
      dueAt: _dueAt,
      plannedDate: _plannedDate,
      plannedStartMin: _plannedStart,
      estMinutes: int.tryParse(_estimate.text.trim()),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    showToast(context, l.taskCreated);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.newTask),
        actions: [
          IconButton(
            tooltip: l.save,
            icon: const Icon(Icons.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: ContentWidths.form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l.titleLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            PrioritySelector(
              important: _important,
              urgent: _urgent,
              onChanged: ({required bool important, required bool urgent}) {
                setState(() {
                  _important = important;
                  _urgent = urgent;
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
                  onChanged: (v) => setState(() => _dueAt = v),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final day = await pickDay(context, current: _plannedDate);
                    if (day != null) setState(() => _plannedDate = day);
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.plannedDay,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        _plannedDate == null
                            ? '—'
                            : relativeDayLabel(_plannedDate!),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final time = await pickTimeOfDay(context, current: null);
                    if (time != null) setState(() => _plannedStart = time);
                  },
                  icon: const Icon(Icons.schedule_outlined),
                  label: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.plannedStart,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        formatMinutesOfDay(_plannedStart).isEmpty
                            ? '—'
                            : formatMinutesOfDay(_plannedStart),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _estimate,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l.estimatedMinutes,
                hintText: l.estimatedMinutesHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.timelapse_outlined),
              ),
            ),
            const SizedBox(height: 16),
            ProjectDropdown(
              value: _projectId,
              onChanged: (v) => setState(() => _projectId = v),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
