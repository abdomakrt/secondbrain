import 'package:drift/drift.dart';

import '../core/hlc.dart';
import '../core/text_normalizer.dart';
import 'database.dart';

/// The single layer through which every database mutation must flow (spec §5.1).
///
/// Inside one transaction it: ticks the HLC, stamps `updated_at`, records the
/// change in `oplog`, and can refresh the FTS index for `items`.
class WriteGate {
  WriteGate({required this.db, required this.clock});

  final AppDatabase db;
  final HlcClock clock;

  Future<T> write<T>(Future<T> Function(WriteTx tx) body) =>
      db.transaction(() => body(WriteTx._(db, clock)));
}

/// Handle to the running transaction with sync bookkeeping helpers.
/// All statements issued on [db] inside [WriteGate.write] run on the
/// transaction's connection (drift swaps it in for the duration).
class WriteTx {
  WriteTx._(this.db, this._clock);

  final AppDatabase db;
  final HlcClock _clock;

  /// Tick the clock and log the change in `oplog`.
  /// Returns the values to stamp on the row: `hlc` and `updated_at`.
  Future<({String hlc, int updatedAtMs})> stamp(
    String entity,
    String recordId,
  ) async {
    final hlc = _clock.tick();
    await db.into(db.oplog).insert(
          OplogCompanion(
            entity: Value(entity),
            recordId: Value(recordId),
            hlc: Value(hlc),
            originDevice: Value(_clock.deviceId),
            createdAt: Value(_clock.lastMs),
          ),
        );
    return (hlc: hlc, updatedAtMs: _clock.lastMs);
  }

  /// Reindex one item in `items_fts` (normalized text + stems, spec §6).
  Future<void> indexItem({
    required String itemId,
    required String title,
    required String body,
    String? comment,
    List<String> tags = const [],
  }) async {
    final nTitle = normalizeForSearch(title);
    final nBody = normalizeForSearch(body);
    final nComment = comment == null ? '' : normalizeForSearch(comment);
    final nTags = tags.map(normalizeForSearch).join(' ');
    await db.customStatement(
      'DELETE FROM items_fts WHERE item_id = ?',
      [itemId],
    );
    await db.customStatement(
      'INSERT INTO items_fts (item_id, title, body, comment, tags, stems) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        itemId,
        nTitle,
        nBody,
        nComment,
        nTags,
        buildStems([nTitle, nBody, nComment, nTags]),
      ],
    );
  }

  Future<void> unindexItem(String itemId) => db.customStatement(
        'DELETE FROM items_fts WHERE item_id = ?',
        [itemId],
      );
}
