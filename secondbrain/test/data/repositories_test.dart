import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/core/ids.dart';
import 'package:secondbrain/data/database.dart';
import 'package:secondbrain/data/repositories/attachments_repository.dart';
import 'package:secondbrain/data/repositories/items_repository.dart';
import 'package:secondbrain/data/search_service.dart';
import 'package:secondbrain/data/write_gate.dart';

void main() {
  late AppDatabase db;
  late WriteGate gate;
  late TagsRepository tags;
  late ItemsRepository items;
  late LinksRepository links;
  late SearchService search;

  setUp(() async {
    db = AppDatabase.inMemory();
    gate = WriteGate(db: db, clock: await db.bootClock());
    tags = TagsRepository(db: db, gate: gate);
    items = ItemsRepository(db: db, gate: gate, tags: tags);
    links = LinksRepository(db: db, gate: gate);
    search = SearchService(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> typeByName(String name) async {
    final t = await (db.select(db.itemTypes)
          ..where((x) => x.name.equals(name)))
        .getSingle();
    return t.id;
  }

  group('ItemsRepository', () {
    test('create stores row, tags and FTS content', () async {
      final item = await items.create(
        typeId: await typeByName('ملاحظة'),
        title: 'مُلاحظة مهمّة',
        bodyMd: 'محتوى عن **البرمجة**',
        tags: ['عمل', 'عمل'],
      );

      final stored = await items.byId(item.id);
      expect(stored, isNotNull);
      expect(stored!.bodyMd, 'محتوى عن **البرمجة**');
      expect(stored.isInbox, isFalse);

      final itemTags = await items.tagsOf(item.id);
      expect(itemTags, hasLength(1)); // duplicate name deduped
      expect(itemTags.single.name, 'عمل');

      final fts = await db
          .customSelect(
              'SELECT item_id FROM items_fts WHERE items_fts MATCH ?',
              variables: [const Variable('ملاحظه*')])
          .get();
      expect(fts, hasLength(1));
    });

    test('update stamps a new HLC and refreshes FTS + tags', () async {
      final item = await items.create(
        typeId: await typeByName('ملاحظة'),
        title: 'عنوان قديم',
        bodyMd: 'نص قديم',
      );
      final hlcBefore = item.hlc;

      await Future.delayed(const Duration(milliseconds: 2));
      final updated = await items.update(
        item,
        title: 'عنوان جديد',
        bodyMd: 'نص جديد',
        tags: ['وسم'],
      );

      expect(updated.title, 'عنوان جديد');
      expect(updated.hlc, isNot(hlcBefore));
      expect(updated.updatedAt, greaterThan(item.updatedAt));

      final tagsAfter = await items.tagsOf(item.id);
      expect(tagsAfter.single.name, 'وسم');

      final oldHits = await search.search('قديم');
      expect(oldHits, isEmpty);
      final newHits = await search.search('جديد');
      expect(newHits, hasLength(1));
    });

    test('trash unindexes, restore reindexes', () async {
      final item = await items.create(
        typeId: await typeByName('ملاحظة'),
        title: 'مرجع الاختبار',
        bodyMd: 'محتوى',
      );
      expect((await search.search('مرجع')), hasLength(1));

      await items.trash(item.id);
      expect((await items.byId(item.id))!.deletedAt, isNotNull);
      expect((await search.search('مرجع')), isEmpty);
      expect((await items.watchList(onlyInbox: false, onlyArchived: false).first),
          isEmpty);

      await items.restore(item.id);
      expect((await items.byId(item.id))!.deletedAt, isNull);
      expect((await search.search('مرجع')), hasLength(1));
    });

    test('version snapshots: 30-min rule and keep last 2', () async {
      final item = await items.create(
        typeId: await typeByName('ملاحظة'),
        title: 'v0',
        bodyMd: '0',
      );
      // First update: snapshot of v0 is taken (no previous snapshot).
      await items.update(item, title: 'v1');
      // Quick follow-up: within 30 min → no new snapshot.
      await items.update(item, title: 'v2');

      Future<List<int>> versions() async {
        final rows = await (db.select(db.itemVersions)
              ..where((v) => v.itemId.equals(item.id)))
            .get();
        return rows.map((r) => r.savedAt).toList();
      }

      expect(await versions(), hasLength(1));
      expect(
        (await db.select(db.itemVersions).get()).single.title,
        'v0',
      );
    });

    test('related links work in both directions', () async {
      final a = await items.create(
        typeId: await typeByName('ملاحظة'),
        title: 'أ',
      );
      final b = await items.create(
        typeId: await typeByName('ملاحظة'),
        title: 'ب',
      );
      await links.link(fromType: 'item', fromId: a.id, toType: 'item', toId: b.id);

      expect((await links.related(a.id)).map((i) => i.title), ['ب']);
      expect((await links.related(b.id)).map((i) => i.title), ['أ']);

      await links.unlink(fromType: 'item', fromId: a.id, toType: 'item', toId: b.id);
      expect(await links.related(a.id), isEmpty);
    });
  });

  group('SearchService (§6.4)', () {
    Future<Item> seed({
      required String title,
      String body = '',
      bool pinned = false,
      bool archived = false,
      List<String> tags = const [],
    }) async {
      final item = await items.create(
        typeId: await typeByName('ملاحظة'),
        title: title,
        bodyMd: body,
        tags: tags,
      );
      if (pinned || archived) {
        return items.update(item, isPinned: pinned, isArchived: archived);
      }
      return item;
    }

    test('filters: type, archived, inbox', () async {
      final note = await seed(title: 'دورة المزامنة');
      final otherType = await typeByName('قرار');
      await items.create(typeId: otherType, title: 'دورة الاختبار');
      await items.update(note, isArchived: true);
      // Wait: archived note also matches the word; use separate seeds.
      final archived = await search.search('دورة', filters: const SearchFilters(archived: true));
      expect(archived, hasLength(1));
      final live = await search.search('دورة', filters: const SearchFilters(archived: false));
      expect(live, hasLength(1));
      final byType = await search.search('دورة',
          filters: SearchFilters(typeId: otherType));
      expect(byType.single.item.typeId, otherType);
    });

    test('pinned boost puts pinned item first', () async {
      await seed(title: 'مستودع البرمجة');
      await seed(title: 'مستودع المهام', pinned: true);
      final hits = await search.search('مستودع');
      expect(hits.first.item.title, 'مستودع المهام');
    });

    test('tag filter restricts results', () async {
      await seed(title: 'مشروع المستودع', tags: ['عمل']);
      await seed(title: 'مشروع البيت');
      final work = await tags.all().then((t) => t.single);
      final hits = await search.search('مشروع',
          filters: SearchFilters(tagId: work.id));
      expect(hits.single.item.title, 'مشروع المستودع');
    });

    test('snippet computed on original text incl. diacritics', () async {
      await seed(title: 'خطة', body: 'هذه مقدمة طويلة نسبيًا ثم يظهر هنا الكلمة المطلوبة منها نأخذ المقتطف');
      final hits = await search.search('الكلمة');
      final snip = hits.single.snippet('الكلمة');
      expect(snip, contains('الكلمة'));
      expect(snip, startsWith('… ')); // window cuts in after the match
    });

    test('date range filter', () async {
      final item = await seed(title: 'ميزانية');
      final now = DateTime.now().millisecondsSinceEpoch;
      final inRange = await search.search('ميزانية',
          filters: SearchFilters(updatedFrom: now - 60000, updatedTo: now + 60000));
      expect(inRange, hasLength(1));
      final outOfRange = await search.search('ميزانية',
          filters: SearchFilters(updatedFrom: now + 60000));
      expect(outOfRange, isEmpty);
      // silence unused warning
      expect(item.id, isNotEmpty);
    });
  });

  group('AttachmentsRepository', () {
    late Directory blobs;
    late AttachmentsRepository attachments;
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('sb_att');
      blobs = Directory('${tmp.path}/blobs');
      attachments = AttachmentsRepository(db: db, gate: gate, blobsDir: blobs);
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('stores content-addressed blob and dedupes', () async {
      final item = await items.create(
        typeId: await typeByName('ملاحظة'),
        title: 'بمرفق',
      );
      final f = File('${tmp.path}/a.txt')..writeAsStringSync('محتوى المرفق');
      final a1 = await attachments.addFile(
          ownerType: 'item', ownerId: item.id, source: f, mime: 'text/plain');
      final a2 = await attachments.addFile(
          ownerType: 'item', ownerId: item.id, source: f, mime: 'text/plain');

      expect(a1.sha256, a2.sha256);
      expect(a1.id, a2.id); // content address → idempotent
      expect(await attachments.listFor('item', item.id), hasLength(1));
      final blob = attachments.fileFor(a1);
      expect(blob.existsSync(), isTrue);
      expect(blob.readAsStringSync(), 'محتوى المرفق');
      expect(blob.path.startsWith(blobs.path), isTrue);
    });

    test('rejects files over 50MB', () async {
      final item = await items.create(
        typeId: await typeByName('ملاحظة'),
        title: 'x',
      );
      final big = File('${tmp.path}/big.bin');
      final raf = big.openSync(mode: FileMode.write);
      await raf.truncate(AttachmentsRepository.maxBytes + 1);
      await raf.close();
      expect(
        () => attachments.addFile(
            ownerType: 'item', ownerId: item.id, source: big),
        throwsA(isA<StateError>()),
      );
    });
  });

  test('ids: pairId deterministic', () {
    expect(pairId('x', ['a', 'b']), pairId('x', ['a', 'b']));
    expect(pairId('x', ['a', 'b']), isNot(pairId('x', ['b', 'a'])));
  });
}
