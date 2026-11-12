import 'package:drift/drift.dart';

import '../database.dart';

/// Content types (spec §5.1).
///
/// The twelve built-in types are seeded on first launch; the settings
/// screen can add custom ones. Reads are centralised here so every screen
/// uses the same query and the same ordering.
class ItemTypesRepository {
  ItemTypesRepository({required this.db});

  final AppDatabase db;

  /// Built-in types in seed order (ids are UUIDv7 → creation order).
  Stream<List<ItemType>> watchBuiltin() => _builtinQuery().watch();

  /// Built-in types in seed order.
  Future<List<ItemType>> builtin() => _builtinQuery().get();

  /// Every type: built-in first, then the custom ones by name.
  Stream<List<ItemType>> watchAll() => (db.select(db.itemTypes)
        ..orderBy([
          (t) => OrderingTerm.desc(t.isBuiltin),
          (t) => OrderingTerm.asc(t.name),
        ]))
      .watch();

  SimpleSelectStatement<$ItemTypesTable, ItemType> _builtinQuery() =>
      (db.select(db.itemTypes)
            ..where((t) => t.isBuiltin.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]));
}
