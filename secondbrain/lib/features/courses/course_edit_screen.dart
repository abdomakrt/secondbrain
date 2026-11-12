import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/content_width.dart';

/// Create or edit a course (quick-add menu and the courses screen).
class CourseEditScreen extends StatefulWidget {
  const CourseEditScreen({super.key, this.courseId});

  final String? courseId;

  @override
  State<CourseEditScreen> createState() => _CourseEditScreenState();
}

class _CourseEditScreenState extends State<CourseEditScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();

  bool _loaded = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) _load();
  }

  Future<void> _load() async {
    if (widget.courseId == null) {
      _loaded = true;
      return;
    }
    final scope = AppScope.of(context);
    final course = await scope.courses.byId(widget.courseId!);
    if (course == null || !mounted) return;
    setState(() {
      _title.text = course.title;
      _description.text = course.description;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
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
    if (widget.courseId == null) {
      await scope.courses.create(
        title: title,
        description: _description.text.trim(),
      );
    } else {
      final course = await scope.courses.byId(widget.courseId!);
      if (course != null) {
        await scope.courses.update(
          course,
          title: title,
          description: _description.text.trim(),
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
        title: Text(widget.courseId == null ? l.newCourse : l.edit),
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
              autofocus: widget.courseId == null,
              decoration: InputDecoration(
                labelText: l.courseNameLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l.descriptionLabel,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
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
