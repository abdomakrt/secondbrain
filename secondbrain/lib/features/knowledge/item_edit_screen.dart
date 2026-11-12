import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../data/database.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/db_stream_builder.dart';
import '../common/widgets/project_dropdown.dart';
import 'item_detail_screen.dart';
import 'widgets/arabic_markdown.dart';

/// Create a new knowledge item (no [itemId]) or edit an existing one.
class ItemEditScreen extends StatefulWidget {
  const ItemEditScreen({
    super.key,
    this.itemId,
    this.initialTypeName,
    this.initialCourseId,
    this.initialLessonId,
    this.initialProjectId,
    this.initialTags = const [],
  });

  final String? itemId;

  /// Preselects a built-in type (used by the quick-add menu).
  final String? initialTypeName;

  /// Links the new item to a course (used by the lesson screen).
  final String? initialCourseId;

  /// Links the new item to a lesson (used by the lesson screen).
  final String? initialLessonId;

  /// Links the new item to a project (used by the project screen).
  final String? initialProjectId;

  /// Tags preset for the new item (e.g. «اليوم» for a note of the day).
  final List<String> initialTags;

  @override
  State<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _comment = TextEditingController();
  final _tags = TextEditingController();
  final _sourceUrl = TextEditingController();
  final _sourceTitle = TextEditingController();

  Item? _loaded;
  String? _typeId;
  String? _projectId;
  bool _isInbox = false;
  bool _preview = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded == null) _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    if (widget.itemId == null) {
      final types = await scope.itemTypes.builtin();
      if (!mounted) return;
      _tags.text = widget.initialTags.join('، ');
      final wanted = widget.initialTypeName;
      final selected = wanted == null
          ? (types.isEmpty ? null : types.first.id)
          : types.where((t) => t.name == wanted).firstOrNull?.id ??
              (types.isEmpty ? null : types.first.id);
      setState(() => _typeId = selected);
      return;
    }
    final item = await scope.items.byId(widget.itemId!);
    if (item == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final tags = await scope.items.tagsOf(item.id);
    if (!mounted) return;
    setState(() {
      _loaded = item;
      _typeId = item.typeId;
      _projectId = item.projectId;
      _isInbox = item.isInbox;
      _title.text = item.title;
      _body.text = item.bodyMd;
      _comment.text = item.commentMd ?? '';
      _sourceUrl.text = item.sourceUrl ?? '';
      _sourceTitle.text = item.sourceTitle ?? '';
      _tags.text = tags.map((t) => t.name).join('، ');
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final names = _tags.text
        .split(RegExp(r'[,،]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (_typeId == null) return;
    setState(() => _saving = true);

    if (_loaded == null) {
      final item = await scope.items.create(
        typeId: _typeId!,
        title: _title.text,
        bodyMd: _body.text,
        commentMd:
            _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        isInbox: _isInbox,
        projectId: _projectId ?? widget.initialProjectId,
        courseId: widget.initialCourseId,
        lessonId: widget.initialLessonId,
        sourceUrl: _sourceUrl.text.trim().isEmpty ? null : _sourceUrl.text.trim(),
        sourceTitle:
            _sourceTitle.text.trim().isEmpty ? null : _sourceTitle.text.trim(),
        tags: names,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ItemDetailScreen(itemId: item.id),
        ),
      );
    } else {
      await scope.items.update(
        _loaded!,
        typeId: _typeId,
        title: _title.text,
        bodyMd: _body.text,
        commentMd:
            _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        clearComment: _comment.text.trim().isEmpty,
        isInbox: _isInbox,
        projectId: _projectId,
        clearProject: _projectId == null,
        sourceUrl: _sourceUrl.text.trim().isEmpty ? null : _sourceUrl.text.trim(),
        clearSourceUrl: _sourceUrl.text.trim().isEmpty,
        sourceTitle:
            _sourceTitle.text.trim().isEmpty ? null : _sourceTitle.text.trim(),
        clearSourceTitle: _sourceTitle.text.trim().isEmpty,
        tags: names,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, l.saved);
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_loaded == null ? l.newItem : l.edit),
        actions: [
          if (_loaded != null)
            IconButton(
              tooltip: _preview ? l.write : l.preview,
              icon: Icon(_preview ? Icons.edit : Icons.visibility_outlined),
              onPressed: () => setState(() => _preview = !_preview),
            ),
          IconButton(
            tooltip: l.save,
            icon: const Icon(Icons.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: _preview
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ArabicMarkdownBody(data: _body.text),
            )
          : DbStreamBuilder<List<ItemType>>(
              streamFactory: () => scope.itemTypes.watchBuiltin(),
              builder: (context, typesSnap) {
                final types = typesSnap.data ?? const <ItemType>[];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _typeId,
                      decoration: InputDecoration(
                        labelText: l.typeLabel,
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                      items: types
                          .map((t) => DropdownMenuItem<String>(
                                value: t.id,
                                child: Text(t.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _typeId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _title,
                      decoration: InputDecoration(
                        labelText: l.titleLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ProjectDropdown(
                      value: _projectId,
                      onChanged: (v) => setState(() => _projectId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tags,
                      decoration: InputDecoration(
                        labelText: l.tagsLabel,
                        hintText: l.tagsHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _body,
                      maxLines: 10,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        labelText: l.bodyLabel,
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _comment,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: l.commentLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sourceTitle,
                      decoration: InputDecoration(
                        labelText: l.sourceTitleLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sourceUrl,
                      keyboardType: TextInputType.url,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: l.sourceUrlLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    SwitchListTile(
                      title: Text(l.inboxSwitch),
                      value: _isInbox,
                      onChanged: (v) => setState(() => _isInbox = v),
                    ),
                  ],
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _comment.dispose();
    _tags.dispose();
    _sourceUrl.dispose();
    _sourceTitle.dispose();
    super.dispose();
  }
}
