import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../common/labels.dart';
import '../common/widgets/content_width.dart';
import '../common/widgets/common_widgets.dart';

/// Create a project (quick form used by the quick-add menu and the FAB).
class ProjectEditScreen extends StatefulWidget {
  const ProjectEditScreen({super.key, this.projectId});

  final String? projectId;

  @override
  State<ProjectEditScreen> createState() => _ProjectEditScreenState();
}

class _ProjectEditScreenState extends State<ProjectEditScreen> {
  final _name = TextEditingController();
  final _sourceUrl = TextEditingController();
  final _goal = TextEditingController();
  final _description = TextEditingController();

  String _status = 'planned';
  bool _saving = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) _load();
  }

  Future<void> _load() async {
    if (widget.projectId == null) {
      _loaded = true;
      return;
    }
    final scope = AppScope.of(context);
    final project = await scope.projects.byId(widget.projectId!);
    if (project == null || !mounted) return;
    setState(() {
      _name.text = project.name;
      _sourceUrl.text = project.sourceUrl ?? '';
      _goal.text = project.goal;
      _description.text = project.description;
      _status = project.status;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    _description.dispose();
    _sourceUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showToast(context, l.titleRequired);
      return;
    }
    setState(() => _saving = true);
    final scope = AppScope.of(context);
    if (widget.projectId == null) {
      await scope.projects.create(
        name: name,
        goal: _goal.text.trim(),
        description: _description.text.trim(),
        status: _status,
        sourceUrl: _sourceUrl.text.trim(),
      );
    } else {
      final project = await scope.projects.byId(widget.projectId!);
      if (project != null) {
        await scope.projects.update(
          project,
          name: name,
          goal: _goal.text.trim(),
          description: _description.text.trim(),
          status: _status,
          sourceUrl: _sourceUrl.text.trim(),
          clearSourceUrl: _sourceUrl.text.trim().isEmpty,
        );
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    showToast(context, l.saved);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectId == null ? l.newProject : l.edit),
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
              controller: _name,
              autofocus: widget.projectId == null,
              decoration: InputDecoration(
                labelText: l.projectNameLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goal,
              decoration: InputDecoration(
                labelText: l.projectGoalLabel,
                hintText: l.projectGoalHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l.descriptionLabel,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.status, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in const [
                  'planned',
                  'active',
                  'paused',
                  'completed',
                  'archived',
                ])
                  ChoiceChip(
                    selected: _status == s,
                    label: Text(projectStatusLabel(context, s)),
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
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
