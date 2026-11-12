import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;

import '../data/database.dart';
import '../data/repositories/items_repository.dart';

/// Spec §11.4: human-readable export — Markdown files with YAML front matter
/// (Obsidian-compatible attachments folder) plus a full `export.json`.
class ExportService {
  ExportService({required this.db, required this.tags, required this.blobsDir});

  final AppDatabase db;
  final TagsRepository tags;
  final Directory blobsDir;

  Future<Directory> export(Directory destDir) async {
    if (!destDir.existsSync()) destDir.createSync(recursive: true);

    final allTags = await tags.all();
    final typeById = {
      for (final t in await db.select(db.itemTypes).get()) t.id: t.name
    };

    final items = await (db.select(db.items)
          ..where((i) => i.deletedAt.isNull())
          ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]))
        .get();

    final jsonItems = <Map<String, dynamic>>[];
    for (final item in items) {
      final created = DateTime.fromMillisecondsSinceEpoch(
          item.createdAt, isUtc: true);
      final year = created.year.toString();
      final dir = Directory('${destDir.path}/items/$year');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final itemTags = await _tagsOf(item.id, allTags);
      final attachments = await (db.select(db.attachments)
            ..where((a) =>
                a.ownerType.equals('item') & a.ownerId.equals(item.id)))
          .get();

      final yaml = _frontMatter(item, itemTags, attachments, typeById);
      final md = '$yaml\n${item.bodyMd}\n';
      final file = File(
          '${dir.path}/${_safeName(item.title.isEmpty ? 'بدون-عنوان' : item.title)}-${item.id.substring(0, 8)}.md');
      await file.writeAsString(md, flush: true);

      // Copy attachments (Obsidian-style shared folder).
      for (final a in attachments) {
        final blob = File(
            '${blobsDir.path}/${a.sha256.substring(0, 2)}/${a.sha256}');
        if (!blob.existsSync()) continue;
        final outDir = Directory('${destDir.path}/attachments');
        if (!outDir.existsSync()) outDir.createSync(recursive: true);
        final ext = a.filename.contains('.')
            ? a.filename.substring(a.filename.lastIndexOf('.'))
            : '';
        await blob.copy('${outDir.path}/${a.sha256.substring(0, 8)}$ext');
      }

      jsonItems.add({
        'id': item.id,
        'type': typeById[item.typeId],
        'title': item.title,
        'body_md': item.bodyMd,
        'comment_md': item.commentMd,
        'tags': itemTags,
        'is_inbox': item.isInbox,
        'is_pinned': item.isPinned,
        'is_archived': item.isArchived,
        'created_at': item.createdAt,
        'updated_at': item.updatedAt,
        'source_url': item.sourceUrl,
        'source_title': item.sourceTitle,
        'attachments': attachments
            .map((a) => {'sha256': a.sha256, 'filename': a.filename})
            .toList(),
        'file': file.path,
      });
    }

    final exportJson = {
      'format': 'secondbrain-export',
      'version': 1,
      'items': jsonItems,
      'tags': allTags
          .map((t) => {'id': t.id, 'name': t.name})
          .toList(),
      'item_tags': (await db.select(db.itemTags).get())
          .map((p) => {'item_id': p.itemId, 'tag_id': p.tagId})
          .toList(),
      'links': (await db.select(db.links).get())
          .map((l) => {
                'from_type': l.fromType,
                'from_id': l.fromId,
                'to_type': l.toType,
                'to_id': l.toId,
                'kind': l.kind,
              })
          .toList(),
    };
    await File('${destDir.path}/export.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(exportJson),
      flush: true,
    );
    return destDir;
  }

  String _frontMatter(
    Item item,
    List<String> tagNames,
    List<Attachment> attachments,
    Map<String, String> typeById,
  ) {
    String iso(int ms) =>
        DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
    final buf = StringBuffer('---\n');
    buf.writeln('id: ${item.id}');
    buf.writeln('type: ${typeById[item.typeId] ?? ''}');
    if (tagNames.isNotEmpty) buf.writeln('tags: [${tagNames.join(', ')}]');
    if (item.projectId != null) buf.writeln('project: ${item.projectId}');
    if (item.courseId != null) buf.writeln('course: ${item.courseId}');
    buf.writeln('created: ${iso(item.createdAt)}');
    buf.writeln('updated: ${iso(item.updatedAt)}');
    if (item.sourceUrl != null) buf.writeln('source: ${item.sourceUrl}');
    if (item.sourceTitle != null) buf.writeln('source_title: ${item.sourceTitle}');
    if (attachments.isNotEmpty) {
      buf.writeln('attachments:');
      for (final a in attachments) {
        buf.writeln('  - ${a.filename}');
      }
    }
    buf.writeln('---');
    return buf.toString();
  }

  Future<List<String>> _tagsOf(String itemId, List<Tag> all) async {
    final pairs = await (db.select(db.itemTags)
          ..where((p) => p.itemId.equals(itemId)))
        .get();
    final byId = {for (final t in all) t.id: t.name};
    return pairs.map((p) => byId[p.tagId] ?? '').where((n) => n.isNotEmpty).toList();
  }

  String _safeName(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.length > 40 ? cleaned.substring(0, 40).trim() : cleaned;
  }
}
