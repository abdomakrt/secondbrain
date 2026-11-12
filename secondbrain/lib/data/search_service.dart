import 'package:drift/drift.dart';

import '../core/text_normalizer.dart';
import 'database.dart';

/// Unified search over `items_fts` (spec §6.4): bm25 ranking with column
/// weights (title 10, tags 5, comment 2, body 1 — stems are an extra channel),
/// a pinned boost, and optional filters. Snippets are computed in Dart on the
/// *original* text.
class SearchService {
  SearchService(this.db);

  final AppDatabase db;

  Future<List<SearchHit>> search(
    String query, {
    SearchFilters filters = const SearchFilters(),
    int limit = 50,
  }) async {
    final match = ftsMatchExpression(query);
    if (match.isEmpty) return const [];

    final vars = <Variable>[Variable(match)];
    var sql = 'SELECT i.*, f.rank AS rank FROM items_fts f '
        'JOIN items i ON i.id = f.item_id '
        'WHERE f.items_fts MATCH ? AND i.deleted_at IS NULL '
        'AND i.is_archived = ?';
    vars.add(Variable(filters.archived ? 1 : 0));
    if (filters.typeId != null) {
      sql += ' AND i.type_id = ?';
      vars.add(Variable(filters.typeId));
    }
    if (filters.projectId != null) {
      sql += ' AND i.project_id = ?';
      vars.add(Variable(filters.projectId));
    }
    if (filters.courseId != null) {
      sql += ' AND i.course_id = ?';
      vars.add(Variable(filters.courseId));
    }
    if (filters.onlyInbox) sql += ' AND i.is_inbox = 1';
    if (filters.updatedFrom != null) {
      sql += ' AND i.updated_at >= ?';
      vars.add(Variable(filters.updatedFrom));
    }
    if (filters.updatedTo != null) {
      sql += ' AND i.updated_at <= ?';
      vars.add(Variable(filters.updatedTo));
    }
    if (filters.tagId != null) {
      sql += ' AND EXISTS (SELECT 1 FROM item_tags p '
          'WHERE p.item_id = i.id AND p.tag_id = ?)';
      vars.add(Variable(filters.tagId));
    }
    // bm25 is smaller-is-better; negative rank values order best first.
    sql += ' ORDER BY rank LIMIT ?';
    vars.add(Variable(limit));

    final rows = await db.customSelect(sql, variables: vars).get();
    final hits = <SearchHit>[];
    for (final r in rows) {
      hits.add(SearchHit(
        item: await db.items.mapFromRow(r),
        rank: r.data['rank'] as num,
      ));
    }

    // Simple pinned boost: pinned items first, otherwise bm25 order stands.
    hits.sort((a, b) {
      if (a.item.isPinned != b.item.isPinned) {
        return a.item.isPinned ? -1 : 1;
      }
      return a.rank.compareTo(b.rank);
    });
    return hits;
  }
}

class SearchFilters {
  const SearchFilters({
    this.typeId,
    this.projectId,
    this.courseId,
    this.tagId,
    this.updatedFrom,
    this.updatedTo,
    this.onlyInbox = false,
    this.archived = false,
  });

  final String? typeId;
  final String? projectId;
  final String? courseId;
  final String? tagId;
  final int? updatedFrom;
  final int? updatedTo;
  final bool onlyInbox;
  final bool archived;
}

class SearchHit {
  SearchHit({required this.item, required this.rank});

  final Item item;
  final num rank;

  /// Snippet from the original (un-normalized) text: the first window of
  /// words containing a query token, diacritics-insensitive (spec §6.4).
  String snippet(String query, {int windowWords = 12}) =>
      snippetFor(query, item.bodyMd, windowWords: windowWords);
}

/// Builds a snippet of [original] around the first word that starts with any
/// normalized query token (same prefix rule as the FTS match).
String snippetFor(
  String query,
  String original, {
  int windowWords = 12,
}) {
  final text = original.trim();
  if (text.isEmpty) return '';
  final qTokens = tokens(normalizeForSearch(query));
  if (qTokens.isEmpty) return _truncate(text, windowWords);

  final words = text.split(RegExp(r'\s+'));
  for (var i = 0; i < words.length; i++) {
    final w = stripAl(normalizeForSearch(words[i]));
    final hit = qTokens.any((t) => stripAl(t).isNotEmpty && w.startsWith(stripAl(t)));
    if (hit) {
      final start = (i - windowWords / 4).floor().clamp(0, words.length);
      final end = (i + windowWords * 3 / 4).ceil().clamp(0, words.length);
      final buf = StringBuffer();
      if (start > 0) buf.write('… ');
      buf.write(words.sublist(start, end).join(' '));
      if (end < words.length) buf.write(' …');
      return buf.toString();
    }
  }
  return _truncate(text, windowWords);
}

String _truncate(String text, int maxWords) {
  final words = text.split(RegExp(r'\s+'));
  if (words.length <= maxWords) return text;
  return '${words.take(maxWords).join(' ')} …';
}
