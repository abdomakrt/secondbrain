import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../common/widgets/content_width.dart';
import '../../data/database.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/tag_chip.dart';
import '../shell/app_shell.dart';
import 'item_edit_screen.dart';
import 'related_items_screen.dart';
import 'versions_screen.dart';
import 'widgets/arabic_markdown.dart';
import 'widgets/type_icons.dart';

/// Knowledge item details (UI_SPEC §5, UI-08).
///
/// Read view with the rendered markdown, the personal note, the original
/// source, the linked project/course/task, the tags and the timestamps.
/// Actions: edit, copy, open source, link to another item, archive, trash.
class ItemDetailView extends StatelessWidget {
  const ItemDetailView({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    return StreamBuilder<Item?>(
      stream: (scope.db.select(scope.db.items)
            ..where((i) => i.id.equals(itemId)))
          .watchSingleOrNull(),
      builder: (context, snap) {
        final item = snap.data;
        if (item == null) {
          return const LoadingView();
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Header(item: item),
            const Divider(height: 24),
            ArabicMarkdownBody(data: item.bodyMd),
            if (item.answerMd != null && item.answerMd!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionTitle(l.answerLabel),
              ArabicMarkdownBody(data: item.answerMd!),
            ],
            if (item.commentMd != null && item.commentMd!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionTitle(l.commentLabel),
              ArabicMarkdownBody(data: item.commentMd!),
            ],
            const SizedBox(height: 16),
            _TagsRow(itemId: item.id),
            const SizedBox(height: 16),
            _SourceRow(item: item),
            _LinkedRow(item: item),
            const Divider(height: 24),
            _AttachmentsSection(itemId: item.id),
            const Divider(height: 24),
            _DatesRow(item: item),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l.edit),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ItemEditScreen(itemId: item.id),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: Text(l.copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: item.bodyMd));
                    if (context.mounted) showToast(context, l.copied);
                  },
                ),
                if (item.sourceUrl != null && item.sourceUrl!.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l.openSource),
                    onPressed: () => _openSource(context, item.sourceUrl!),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.hub_outlined),
                  label: Text(l.relatedItems),
                  onPressed: () => openDetail(
                    context,
                    title: l.relatedItems,
                    builder: (_) => RelatedItemsScreen(itemId: item.id),
                  ),
                ),
                OutlinedButton.icon(
                  icon: Icon(
                    item.isArchived ? Icons.unarchive : Icons.archive_outlined,
                  ),
                  label: Text(item.isArchived ? l.unarchive : l.archive),
                  onPressed: () => scope.items.update(
                    item,
                    isArchived: !item.isArchived,
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: Text(l.versions),
                  onPressed: () => openDetail(
                    context,
                    title: l.versions,
                    builder: (_) => VersionsScreen(itemId: item.id),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _openSource(BuildContext context, String url) {
    // Links open in the system browser; the URL itself is shown LTR.
    final uri = Uri.tryParse(url);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.sourceLabel),
        content: Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText(url),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
    if (uri != null && uri.scheme.isNotEmpty) {
      // ignore: unawaited_futures
      launchUrlExternally(uri);
    }
  }
}

/// Opens a URL with the platform's default handler when available.
Future<void> launchUrlExternally(Uri uri) async {
  try {
    final process = await Process.run('xdg-open', [uri.toString()]);
    if (process.exitCode != 0) {
      await Process.run('sensible-browser', [uri.toString()]);
    }
  } on Object {
    // Opening a link is best-effort; the URL is always visible in the dialog.
  }
}

/// Full-screen route wrapper around [ItemDetailView].
class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.itemDetails),
        actions: [
          IconButton(
            tooltip: l.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ItemEditScreen(itemId: itemId),
              ),
            ),
          ),
          IconButton(
            tooltip: l.moveToTrash,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await scope.items.trash(itemId);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: ContentWidths.details,
        child: ItemDetailView(itemId: itemId),
      ),
    );
  }
}

class _Header extends StatefulWidget {
  const _Header({required this.item});

  final Item item;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  ItemType? _type;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant _Header old) {
    super.didUpdateWidget(old);
    if (old.item.typeId != widget.item.typeId) _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final type = await (scope.db.select(scope.db.itemTypes)
          ..where((t) => t.id.equals(widget.item.typeId)))
        .getSingleOrNull();
    if (mounted) setState(() => _type = type);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(iconForType(_type?.name ?? ''),
            color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.item.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        if (widget.item.isPinned)
          Icon(Icons.push_pin, size: 18, color: Theme.of(context).colorScheme.primary),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
}

class _TagsRow extends StatefulWidget {
  const _TagsRow({required this.itemId});

  final String itemId;

  @override
  State<_TagsRow> createState() => _TagsRowState();
}

class _TagsRowState extends State<_TagsRow> {
  List<Tag> _tags = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant _TagsRow old) {
    super.didUpdateWidget(old);
    if (old.itemId != widget.itemId) _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final tags = await scope.items.tagsOf(widget.itemId);
    if (mounted) setState(() => _tags = tags);
  }

  @override
  Widget build(BuildContext context) {
    if (_tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: _tags.map((t) => TagChip(label: t.name)).toList(),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (item.sourceUrl == null &&
        item.sourceTitle == null &&
        item.sourceApp == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l.sourceLabel),
          if (item.sourceTitle != null) Text(item.sourceTitle!),
          if (item.sourceApp != null)
            Text(
              item.sourceApp!,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          if (item.sourceUrl != null)
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                item.sourceUrl!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// The project/course/task the item is linked to.
class _LinkedRow extends StatelessWidget {
  const _LinkedRow({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final parts = <Widget>[];

    if (item.projectId != null) {
      parts.add(_LinkedChip(
        icon: Icons.folder_outlined,
        label: l.linkedProject,
        future: scope.projects.byId(item.projectId!),
        nameOf: (p) => p.name,
      ));
    }
    if (item.courseId != null) {
      parts.add(_LinkedChip(
        icon: Icons.school_outlined,
        label: l.linkedCourse,
        future: scope.courses.byId(item.courseId!),
        nameOf: (c) => c.title,
      ));
    }
    if (item.taskId != null) {
      parts.add(_LinkedChip(
        icon: Icons.checklist_outlined,
        label: l.linkedTask,
        future: scope.tasks.byId(item.taskId!),
        nameOf: (t) => t.title,
      ));
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l.linkedTo),
          Wrap(spacing: 8, runSpacing: 8, children: parts),
        ],
      ),
    );
  }
}

class _LinkedChip<T> extends StatelessWidget {
  const _LinkedChip({
    required this.icon,
    required this.label,
    required this.future,
    required this.nameOf,
  });

  final IconData icon;
  final String label;
  final Future<T?> future;
  final String Function(T) nameOf;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T?>(
      future: future,
      builder: (context, snap) {
        final value = snap.data;
        final text = value == null ? label : nameOf(value);
        return Chip(
          avatar: Icon(icon, size: 14),
          label: Text(text),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }
}

class _DatesRow extends StatelessWidget {
  const _DatesRow({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            '${l.createdAt}: ${formatStamp(item.createdAt)}',
            style: theme.textTheme.labelSmall,
          ),
        ),
        Expanded(
          child: Text(
            '${l.lastUpdated}: ${formatStamp(item.updatedAt)}',
            style: theme.textTheme.labelSmall,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _AttachmentsSection extends StatefulWidget {
  const _AttachmentsSection({required this.itemId});

  final String itemId;

  @override
  State<_AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends State<_AttachmentsSection> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _SectionTitle(l.attachments)),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l.addAttachment),
              onPressed: () => _addAttachment(context),
            ),
          ],
        ),
        StreamBuilder<List<Attachment>>(
          stream: scope.attachments.watchFor('item', widget.itemId),
          builder: (context, snap) {
            final rows = snap.data ?? const <Attachment>[];
            if (rows.isEmpty) return const SizedBox.shrink();
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rows
                  .map((a) => _AttachmentTile(attachment: a))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _addAttachment(BuildContext context) async {
    final scope = AppScope.of(context);
    final file = await openFile();
    if (file == null) return;
    try {
      await scope.attachments.addFile(
        ownerType: 'item',
        ownerId: widget.itemId,
        source: File(file.path),
      );
    } on StateError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final file = scope.attachments.fileFor(attachment);
    return Column(
      children: [
        if (attachment.kind == 'image' && file.existsSync())
          GestureDetector(
            onTap: () => _showFull(context, file),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                cacheWidth: 256,
              ),
            ),
          )
        else
          const SizedBox(
            width: 120,
            height: 120,
            child: Icon(Icons.attach_file, size: 40),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                attachment.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => scope.attachments.delete(attachment),
            ),
          ],
        ),
      ],
    );
  }

  void _showFull(BuildContext context, File file) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.file(file, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
