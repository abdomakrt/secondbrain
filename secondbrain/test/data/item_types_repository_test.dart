import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/data/database.dart';
import 'package:secondbrain/data/repositories/item_types_repository.dart';

void main() {
  late AppDatabase db;
  late ItemTypesRepository types;

  setUp(() async {
    db = AppDatabase.inMemory();
    types = ItemTypesRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertCustomType() => db.into(db.itemTypes).insert(
        ItemTypesCompanion.insert(
          id: 'custom-type',
          name: 'نوع مخصّص',
          isBuiltin: const Value(false),
          createdAt: 1,
          updatedAt: 1,
          hlc: '1-0000-local',
        ),
      );

  group('ItemTypesRepository', () {
    test('the twelve built-in types are seeded in a stable order', () async {
      final list = await types.builtin();
      expect(list, hasLength(12));
      expect(list.every((t) => t.isBuiltin), isTrue);

      final again = await types.builtin();
      expect(again.map((t) => t.id).toList(), list.map((t) => t.id).toList());
    });

    test('watchBuiltin emits the built-in types only', () async {
      await insertCustomType();

      final emitted = await types.watchBuiltin().first;
      expect(emitted, hasLength(12));
      expect(emitted.any((t) => t.id == 'custom-type'), isFalse);
    });

    test('watchAll lists the built-in types before the custom ones', () async {
      await insertCustomType();

      final all = await types.watchAll().first;
      expect(all, hasLength(13));
      expect(all.last.isBuiltin, isFalse);
    });
  });
}
