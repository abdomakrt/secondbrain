import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../core/text_normalizer.dart';
import '../database.dart';
import '../write_gate.dart';

const _snapshotIntervalMs = 30 * 60 * 1000; // spec §7.5: 30 min between snapshots
const int keepVersions = 2; // spec §5.3: last two versions only

/// Items (المعرفة): CRUD, tags, links, trash and version snapshots.
/// Every mutation goes through [WriteGate]; sync bookkeeping is automatic.
class ItemsRepository {
  ItemsRepository({
    required this.db,
    required this.gate,
    required this.tags,
  });

  final AppDatabase db;
  final WriteGate gate;
  final TagsRepository tags;

  // ---- create / update ----

  Future<Item> create({
    required String typeId,
    String title = '',
    String bodyMd = '',
    String? commentMd,
    String? answerMd,
    String? projectId,
    String? courseId,
    String? lessonId,
    String? taskId,
    bool isInbox = false,
    String? sourceUrl,
    String? sourceTitle,
    String? sourceApp,
    String sourceKind = 'manual',
    int? capturedAt,
    List<String> tags = const [],
  }) =>
      gate.write((tx) async {
        final id = newId();
        final s = await tx.stamp('items', id);
        final now = s.updatedAtMs;
        final item = Item(
          id: id,
          userId: 'local',
          createdAt: now,
          updatedAt: now,
          hlc: s.hlc,
          typeId: typeId,
          title: title,
          bodyMd: bodyMd,
          commentMd: commentMd,
          answerMd: answerMd,
          projectId: projectId,
          courseId: courseId,
          lessonId: lessonId,
          taskId: taskId,
          isInbox: isInbox,
          isPinned: false,
          isArchived: false,
          sourceUrl: sourceUrl,
          sourceTitle: sourceTitle,
          sourceApp: sourceApp,
          sourceKind: sourceKind,
          capturedAt: capturedAt,
        );
        await tx.db.into(tx.db.items).insert(item);
        final tagIds = (await _resolveTagIds(tx, tags)).toSet();
        for (final tagId in tagIds) {
          await _insertPair(tx, id, tagId);
        }
        await reindex(tx, id);
        return item;
      });

  /// Edits an item. Snapshots the previous content first (spec §7.5: at most
  /// one snapshot per 30 minutes), stamps, and refreshes the FTS row.
  Future<Item> update(
    Item current, {
    String? typeId,
    String? title,
    String? bodyMd,
    String? commentMd,
    String? answerMd,
    String? projectId,
    String? courseId,
    String? lessonId,
    String? taskId,
    bool? isInbox,
    bool? isPinned,
    bool? isArchived,
    String? color,
    String? sourceUrl,
    String? sourceTitle,
    String? sourceApp,
    int? reviewedAt,
    bool clearComment = false,
    bool clearColor = false,
    bool clearProject = false,
    bool clearCourse = false,
    bool clearLesson = false,
    bool clearSourceUrl = false,
    bool clearSourceTitle = false,
    List<String>? tags,
  }) =>
      gate.write((tx) async {
        await _maybeSnapshot(tx, current);
        final s = await tx.stamp('items', current.id);
        final next = current.copyWith(
          typeId: typeId,
          title: title,
          bodyMd: bodyMd,
          commentMd: clearComment
              ? const Value(null)
              : (commentMd == null ? const Value.absent() : Value(commentMd)),
          answerMd:
              answerMd == null ? const Value.absent() : Value(answerMd),
          projectId: clearProject
              ? const Value(null)
              : (projectId == null ? const Value.absent() : Value(projectId)),
          courseId: clearCourse
              ? const Value(null)
              : (courseId == null ? const Value.absent() : Value(courseId)),
          lessonId: clearLesson
              ? const Value(null)
              : (lessonId == null ? const Value.absent() : Value(lessonId)),
          taskId: taskId == null ? const Value.absent() : Value(taskId),
          isInbox: isInbox,
          isPinned: isPinned,
          isArchived: isArchived,
          color: clearColor
              ? const Value(null)
              : (color == null ? const Value.absent() : Value(color)),
          sourceUrl: clearSourceUrl
              ? const Value(null)
              : (sourceUrl == null ? const Value.absent() : Value(sourceUrl)),
          sourceTitle: clearSourceTitle
              ? const Value(null)
              : (sourceTitle == null
                  ? const Value.absent()
                  : Value(sourceTitle)),
          sourceApp:
              sourceApp == null ? const Value.absent() : Value(sourceApp),
          reviewedAt:
              reviewedAt == null ? const Value.absent() : Value(reviewedAt),
          updatedAt: s.updatedAtMs,
          hlc: s.hlc,
        );
        if (tags != null) {
          await _replaceTags(tx, current, tags);
        }
        await (tx.db.update(tx.db.items)..where((i) => i.id.equals(current.id)))
            .write(next.toCompanion(false).copyWith(
                updatedAt: Value(s.updatedAtMs), hlc: Value(s.hlc)));
        await reindex(tx, current.id);
        return next;
      });
  // ---- trash / archive (spec §7.4) ----

  /// Soft delete: tombstone + FTS removal. Hard delete never happens.
  Future<void> trash(String itemId) => gate.write((tx) async {
        final item = await (tx.db.select(tx.db.items)
              ..where((i) => i.id.equals(itemId)))
            .getSingleOrNull();
        if (item == null || item.deletedAt != null) return;
        final s = await tx.stamp('items', itemId);
        await (tx.db.update(tx.db.items)..where((i) => i.id.equals(itemId))).write(
          ItemsCompanion(
            deletedAt: Value(s.updatedAtMs),
            updatedAt: Value(s.updatedAtMs),
            hlc: Value(s.hlc),
          ),
        );
        await tx.unindexItem(itemId);
      });

  /// Restore clears the tombstone and reindexes. A newer edit beats a delete
  /// during sync by the same rule (later phase).
  Future<void> restore(String itemId) => gate.write((tx) async {
        final item = await (tx.db.select(tx.db.items)
              ..where((i) => i.id.equals(itemId)))
            .getSingleOrNull();
        if (item == null || item.deletedAt == null) return;
        final s = await tx.stamp('items', itemId);
        await (tx.db.update(tx.db.items)..where((i) => i.id.equals(itemId))).write(
          ItemsCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(s.updatedAtMs),
            hlc: Value(s.hlc),
          ),
        );
        await reindex(tx, itemId);
      });

  // ---- reads ----

  Future<Item?> byId(String id) =>
      (db.select(db.items)..where((i) => i.id.equals(id))).getSingleOrNull();

  /// Live list for the home screen. Pinned first, then newest edit.
  Stream<List<Item>> watchList({
    required bool onlyInbox,
    required bool onlyArchived,
    String? typeId,
    String? tagId,
  }) {
    final q = db.select(db.items)..where((i) => i.deletedAt.isNull());
    if (onlyInbox) {
      q.where((i) => i.isInbox.equals(true));
    } else {
      q.where((i) => i.isInbox.equals(false));
    }
    q.where((i) => i.isArchived.equals(onlyArchived));
    if (typeId != null) q.where((i) => i.typeId.equals(typeId));
    if (tagId != null) {
      // tagId is always an app-generated UUID (from DB rows), safe to inline.
      q.where((i) => CustomExpression<bool>(
            "EXISTS (SELECT 1 FROM item_tags p "
            "WHERE p.item_id = items.id AND p.tag_id = '$tagId')",
          ));
    }
    return (q
          ..orderBy([
            (i) => OrderingTerm.desc(i.isPinned),
            (i) => OrderingTerm.desc(i.updatedAt),
          ]))
        .watch();
  }

  /// Live trash list, newest deleted first.
  Stream<List<Item>> watchTrash() => (db.select(db.items)
        ..where((i) => i.deletedAt.isNotNull())
        ..orderBy([(i) => OrderingTerm.desc(i.deletedAt)]))
      .watch();

  // ---- tags (pair table) ----

  Future<List<Tag>> tagsOf(String itemId) async {
    final rows = await (db.select(db.itemTags).join([
      innerJoin(db.tags, db.itemTags.tagId.equalsExp(db.tags.id)),
    ])..where(db.itemTags.itemId.equals(itemId)))
        .get();
    return rows.map((r) => r.readTable(db.tags)).toList();
  }

  // ---- internals ----

  Future<List<String>> _resolveTagIds(WriteTx tx, List<String> names) =>
      tags.resolveIds(tx, names);

  Future<void> _insertPair(WriteTx tx, String itemId, String tagId) async {
    final s = await tx.stamp('item_tags', pairId('item_tags', [itemId, tagId]));
    await tx.db.into(tx.db.itemTags).insert(ItemTagsCompanion.insert(
          id: pairId('item_tags', [itemId, tagId]),
          itemId: itemId,
          tagId: tagId,
          createdAt: s.updatedAtMs,
          updatedAt: s.updatedAtMs,
          hlc: s.hlc,
        ));
  }

  Future<void> _replaceTags(WriteTx tx, Item item, List<String> names) async {
    final wanted = (await _resolveTagIds(tx, names)).toSet();
    final current = await (tx.db.select(tx.db.itemTags)
          ..where((p) => p.itemId.equals(item.id)))
        .get();
    final currentIds = current.map((p) => p.tagId).toSet();
    for (final tagId in currentIds.difference(wanted)) {
      await tx.stamp('item_tags', pairId('item_tags', [item.id, tagId]));
      await (tx.db.delete(tx.db.itemTags)
            ..where((p) =>
                p.itemId.equals(item.id) & p.tagId.equals(tagId)))
          .go();
    }
    for (final tagId in wanted.where((t) => !currentIds.contains(t))) {
      await _insertPair(tx, item.id, tagId);
    }
  }

  /// Reindex an item's FTS row from current DB content (after tag changes).
  Future<void> reindex(WriteTx tx, String itemId) async {
    final item = await (tx.db.select(tx.db.items)
          ..where((i) => i.id.equals(itemId)))
        .getSingle();
    final names = await (tx.db.select(tx.db.itemTags).join([
      innerJoin(tx.db.tags, tx.db.itemTags.tagId.equalsExp(tx.db.tags.id)),
    ])..where(tx.db.itemTags.itemId.equals(itemId)))
        .get()
        .then((rows) => rows.map((r) => r.readTable(tx.db.tags).name));
    await tx.indexItem(
      itemId: itemId,
      title: item.title,
      body: item.bodyMd,
      comment: item.commentMd,
      tags: names.toList(),
    );
  }

  Future<void> _maybeSnapshot(WriteTx tx, Item item) async {
    final last = await (tx.db.select(tx.db.itemVersions)
          ..where((v) => v.itemId.equals(item.id))
          ..orderBy([(v) => OrderingTerm.desc(v.savedAt)])
          ..limit(1))
        .getSingleOrNull();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last != null && now - last.savedAt < _snapshotIntervalMs) return;
    await tx.db.into(tx.db.itemVersions).insert(ItemVersionsCompanion.insert(
          id: newId(),
          itemId: item.id,
          title: item.title,
          bodyMd: item.bodyMd,
          reason: 'local_edit',
          savedAt: now,
        ));
    final all = await (tx.db.select(tx.db.itemVersions)
          ..where((v) => v.itemId.equals(item.id))
          ..orderBy([(v) => OrderingTerm.desc(v.savedAt)]))
        .get();
    for (final old in all.skip(keepVersions)) {
      await (tx.db.delete(tx.db.itemVersions)..where((v) => v.id.equals(old.id)))
          .go();
    }
  }
}

/// Tags: unique by normalized name (spec §5.2).
class TagsRepository {
  TagsRepository({required this.db, required this.gate});

  final AppDatabase db;
  final WriteGate gate;

  Future<List<Tag>> all() => (db.select(db.tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  /// Live list of all tags, by name.
  Stream<List<Tag>> watchAll() => (db.select(db.tags)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();

  /// Creates a tag if the normalized form is new; used inside item writes.
  Future<List<String>> resolveIds(WriteTx tx, List<String> names) async {
    final ids = <String>[];
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final norm = normalizeForSearch(name);
      final existing = await (tx.db.select(tx.db.tags)
            ..where((t) => t.nameNormalized.equals(norm)))
          .getSingleOrNull();
      if (existing != null) {
        ids.add(existing.id);
        continue;
      }
      final id = newId();
      final s = await tx.stamp('tags', id);
      await tx.db.into(tx.db.tags).insert(TagsCompanion.insert(
            id: id,
            name: name,
            nameNormalized: norm,
            createdAt: s.updatedAtMs,
            updatedAt: s.updatedAtMs,
            hlc: s.hlc,
          ));
      ids.add(id);
    }
    return ids;
  }

  /// Rename everywhere; normalization keeps tags mergeable.
  Future<void> rename(String tagId, String newName) =>
      gate.write((tx) async {
        final s = await tx.stamp('tags', tagId);
        await (tx.db.update(tx.db.tags)..where((t) => t.id.equals(tagId))).write(
          TagsCompanion(
            name: Value(newName.trim()),
            nameNormalized: Value(normalizeForSearch(newName)),
            updatedAt: Value(s.updatedAtMs),
            hlc: Value(s.hlc),
          ),
        );
      });
}

/// Item↔item links with deterministic pair ids (spec §5.2).
class LinksRepository {
  LinksRepository({required this.db, required this.gate});

  final AppDatabase db;
  final WriteGate gate;

  static String _pairId(String fromType, String fromId, String toType, String toId, String kind) =>
      pairId('links', [fromType, fromId, toType, toId, kind]);

  Future<void> link({
    required String fromType,
    required String fromId,
    required String toType,
    required String toId,
    String kind = 'related',
  }) =>
      gate.write((tx) async {
        final id = _pairId(fromType, fromId, toType, toId, kind);
        final s = await tx.stamp('links', id);
        await tx.db.into(tx.db.links).insert(LinksCompanion.insert(
              id: id,
              fromType: fromType,
              fromId: fromId,
              toType: toType,
              toId: toId,
              kind: kind,
              createdAt: s.updatedAtMs,
              updatedAt: s.updatedAtMs,
              hlc: s.hlc,
            ));
      });

  Future<void> unlink({
    required String fromType,
    required String fromId,
    required String toType,
    required String toId,
    String kind = 'related',
  }) =>
      gate.write((tx) async {
        await tx.stamp('links', _pairId(fromType, fromId, toType, toId, kind));
        await (tx.db.delete(tx.db.links)
              ..where((l) =>
                  l.fromType.equals(fromType) &
                  l.fromId.equals(fromId) &
                  l.toType.equals(toType) &
                  l.toId.equals(toId) &
                  l.kind.equals(kind)))
            .go();
      });

  /// All items linked to [itemId], in either direction.
  Future<List<Item>> related(String itemId) async {
    final outgoing = await (db.select(db.links).join([
      innerJoin(db.items, db.links.toId.equalsExp(db.items.id)),
    ])..where(db.links.fromId.equals(itemId) & db.links.fromType.equals('item')))
        .get();
    final incoming = await (db.select(db.links).join([
      innerJoin(db.items, db.links.fromId.equalsExp(db.items.id)),
    ])..where(db.links.toId.equals(itemId) & db.links.toType.equals('item')))
        .get();
    return [
      ...outgoing.map((r) => r.readTable(db.items)),
      ...incoming.map((r) => r.readTable(db.items)),
    ].where((i) => i.deletedAt == null).toList();
  }
}
