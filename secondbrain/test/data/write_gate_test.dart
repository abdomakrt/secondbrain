import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/core/ids.dart';
import 'package:secondbrain/core/hlc.dart';
import 'package:secondbrain/core/text_normalizer.dart';
import 'package:secondbrain/data/database.dart';
import 'package:secondbrain/data/write_gate.dart';

void main() {
  group('schema & migration', () {
    test('creates all tables, FTS index and settings row on first open', () async {
      final db = AppDatabase.inMemory();
      final names = await db
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type IN ('table','index') "
              "AND name NOT LIKE 'sqlite_%'")
          .get();
      final have = names.map((r) => r.data['name'] as String).toSet();
      for (final t in [
        'projects', 'milestones', 'tasks', 'courses', 'course_units', 'lessons',
        'item_types', 'items', 'tags', 'item_tags', 'links', 'attachments',
        'settings', 'oplog', 'sync_state', 'devices', 'item_versions',
        'local_paths', 'import_map', 'import_batches', 'capture_drafts',
        'items_fts',
      ]) {
        expect(have.contains(t), isTrue, reason: 'missing table $t');
      }
      for (final i in [
        'idx_items_project', 'idx_items_updated', 'idx_items_inbox',
        'idx_oplog_record', 'idx_item_tags_pair', 'idx_links_pair',
      ]) {
        expect(have.contains(i), isTrue, reason: 'missing index $i');
      }
      await db.close();
    });

    test('WAL journal mode on a file-backed database', () async {
      final dir = await Directory.systemTemp.createTemp('sb_test');
      final db = AppDatabase.atFile(File('${dir.path}/test.db'));
      await db.deviceId(); // force open
      final mode = await db
          .customSelect('PRAGMA journal_mode')
          .getSingle();
      expect(mode.data['journal_mode'], 'wal');
      await db.close();
      await dir.delete(recursive: true);
    });

    test('reopen (upgrade path) does not fail and user_version is set', () async {
      final dir = await Directory.systemTemp.createTemp('sb_test');
      final file = File('${dir.path}/test.db');
      var db = AppDatabase.atFile(file);
      await db.deviceId();
      await db.close();
      db = AppDatabase.atFile(file);
      final v = await db.customSelect('PRAGMA user_version').getSingle();
      expect(v.data['user_version'], 1);
      await db.close();
      await dir.delete(recursive: true);
    });

    test('device_id is stable across reopens', () async {
      final dir = await Directory.systemTemp.createTemp('sb_test');
      final file = File('${dir.path}/test.db');
      final db1 = AppDatabase.atFile(file);
      final id1 = await db1.deviceId();
      await db1.close();
      final db2 = AppDatabase.atFile(file);
      expect(await db2.deviceId(), id1);
      await db2.close();
      await dir.delete(recursive: true);
    });

    test('builtin item types are seeded once (12) and survive reopens', () async {
      final dir = await Directory.systemTemp.createTemp('sb_test');
      final file = File('${dir.path}/test.db');
      final db1 = AppDatabase.atFile(file);
      expect((await db1.select(db1.itemTypes).get()).length, 12);
      expect(
        (await (db1.select(db1.itemTypes)..where((t) => t.isBuiltin.equals(true))).get())
            .length,
        12,
      );
      await db1.close();
      final db2 = AppDatabase.atFile(file);
      expect((await db2.select(db2.itemTypes).get()).length, 12);
      await db2.close();
      await dir.delete(recursive: true);
    });
  });

  group('WriteGate', () {
    late AppDatabase db;
    late WriteGate gate;

    setUp(() async {
      db = AppDatabase.inMemory();
      gate = WriteGate(db: db, clock: await db.bootClock());
    });

    tearDown(() async {
      await db.close();
    });

    test('stamps hlc/updated_at and writes an oplog entry', () async {
      final id = newId();
      final stamp = await gate.write((tx) async {
        final s = await tx.stamp('projects', id);
        await tx.db.into(tx.db.projects).insert(
              ProjectsCompanion.insert(
                id: id,
                name: 'مشروع الاختبار',
                createdAt: s.updatedAtMs,
                updatedAt: s.updatedAtMs,
                hlc: s.hlc,
              ),
            );
        return s;
      });

      final row = await (db.select(db.projects)
            ..where((p) => p.id.equals(id)))
          .getSingle();
      expect(row.hlc, stamp.hlc);
      expect(row.updatedAt, stamp.updatedAtMs);
      expect(row.userId, 'local');
      expect(HlcClock.parse(stamp.hlc).deviceId, await db.deviceId());

      final op = await (db.select(db.oplog)
            ..where((o) => o.recordId.equals(id)))
          .getSingle();
      expect(op.entity, 'projects');
      expect(op.recordId, id);
      expect(op.hlc, stamp.hlc);
      expect(op.originDevice, await db.deviceId());
    });

    test('each write advances the clock lexically', () async {
      final stamps = <String>[];
      for (var i = 0; i < 3; i++) {
        await gate.write((tx) => tx.stamp('projects', 'p$i'));
        stamps.add(gate.clock.last);
      }
      for (var i = 1; i < stamps.length; i++) {
        expect(stamps[i].compareTo(stamps[i - 1]), greaterThan(0));
      }
      final entries = await (db.select(db.oplog)
            ..where((o) => o.entity.equals('projects')))
          .get();
      expect(entries.length, 3);
    });

    test('indexItem + normalized Arabic search incl. «ال» stripping', () async {
      final id = newId();
      await gate.write((tx) async {
        final s = await tx.stamp('items', id);
        await tx.db.into(tx.db.items).insert(
              ItemsCompanion.insert(
                id: id,
                typeId: 'note',
                title: const Value('مكتبة النادي'),
                bodyMd: const Value('مُلاحظة عن المُكتبة'),
                createdAt: s.updatedAtMs,
                updatedAt: s.updatedAtMs,
                hlc: s.hlc,
              ),
            );
        await tx.indexItem(
          itemId: id,
          title: 'مكتبة النادي',
          body: 'مُلاحظة عن المُكتبة',
          comment: 'القراءة',
          tags: ['دِراسة'],
        );
      });

      Future<List<String>> search(String q) async {
        final match = ftsMatchExpression(q);
        final rows = await db
            .customSelect(
              'SELECT item_id FROM items_fts WHERE items_fts MATCH ? ORDER BY rank',
              variables: [Variable(match)],
            )
            .get();
        return rows.map((r) => r.data['item_id'] as String).toList();
      }

      // Query without tashkeel/«ال» finds text containing both forms.
      expect(await search('مكتبة'), [id]);
      expect(await search('النادي'), [id]);
      expect(await search('ملاحظة'), [id]);
      expect(await search('دراسة'), [id]); // tag دِراسة matched via stems?
      expect(await search('قراءة'), [id]);

      // No hit for an unrelated word.
      expect(await search('سفر'), isEmpty);
    });

    test('unindexItem removes the row from FTS', () async {
      final id = newId();
      await gate.write((tx) async {
        await tx.stamp('items', id);
        await tx.indexItem(itemId: id, title: 'عنوان', body: 'نص');
      });
      await gate.write((tx) => tx.unindexItem(id));
      final rows = await db
          .customSelect('SELECT item_id FROM items_fts')
          .get();
      expect(rows, isEmpty);
    });
  });
}
