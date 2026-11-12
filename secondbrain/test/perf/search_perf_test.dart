import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/data/database.dart';
import 'package:secondbrain/data/repositories/items_repository.dart';
import 'package:secondbrain/data/search_service.dart';
import 'package:secondbrain/data/write_gate.dart';

/// Perf check for spec §6.5: search over a large corpus must stay fast.
/// Seeds 1000 Arabic items in ONE transaction, then runs ~30 queries that are
/// spelling/affix variants (tashkeel, «ال», hamza forms) of the same words.
void main() {
  test('search p95 < 200ms over 1000 Arabic items', () async {
    final db = AppDatabase.inMemory();
    final gate = WriteGate(db: db, clock: await db.bootClock());
    final tags = TagsRepository(db: db, gate: gate);
    final items = ItemsRepository(db: db, gate: gate, tags: tags);
    final search = SearchService(db);

    Future<String> typeByName(String name) async {
      final t = await (db.select(db.itemTypes)
            ..where((x) => x.name.equals(name)))
          .getSingle();
      return t.id;
    }

    final noteType = await typeByName('ملاحظة');

    // One transaction: the bulk import path (§5.1 — all writes via the gate).
    await gate.write((tx) async {
      for (var i = 0; i < 1000; i++) {
        final subject = switch (i % 5) {
          0 => 'المستودع',
          1 => 'الأسئلة',
          2 => 'القراءة',
          3 => 'الأفكار',
          _ => 'الشبكة',
        };
        final detail = switch (i % 4) {
          0 => 'فهرسة',
          1 => 'مزامنة',
          2 => 'نسخ احتياطي',
          _ => 'استرجاع',
        };
        await items.create(
          typeId: noteType,
          title: 'عنصر $i: $subject',
          bodyMd:
              'محتوى تجريبي رقم $i يتحدث عن $subject و $detail مع تفاصيل كافية للبحث '
              'والعثور على الكلمات بسهولة نسبية في النص العربي المطبوع هنا.',
          tags: ['وسم${i % 10}'],
        );
      }
    });

    // ~30 spelling/affix variants the spec §6.3 rules cover: «ال» stripping,
    // tashkeel removal, hamza unification (أ→ا) and ة→ه.
    // ~30 spelling/affix variants covered by spec §6.3 as written: «ال»
    // stripping, tashkeel removal, hamza unification (أ→ا), ة→ه, and prefix
    // match. Note (spec: "يُوسّع لاحقًا"): stripped tokens of length ≤ 4
    // (e.g. "شبكه") are not in stems, so bare short forms won't match yet.
    const queries = [
      'المستودع', 'مستودع', 'المُستودَع', 'مُستودَع فهرسة',
      'الأسئلة', 'الاسئله', 'اسئله', 'اَلأَسْئِلَة', 'الأسئله',
      'القراءة', 'القراءه', 'القراءة مزامنة', 'قِرَاءَة',
      'الأفكار', 'الافكار', 'افكار', 'اَلأَفْكَار',
      'الشبكة', 'الشبكه', 'الشبكه استرجاع',
      'الفهرسة', 'فهرس', 'فهرسه', 'الفهرسة الشبكة',
      'المزامنة', 'مزامنه', 'الأسئلة مزامنة',
      'الاسترجاع', 'استرجاع', 'اَلاستِرْجاع',
      'النسخ', 'النسخ الاحتياطي', 'المستودع استرجاع',
    ];

    final durations = <int>[];
    for (final q in queries) {
      final sw = Stopwatch()..start();
      final hits = await search.search(q);
      sw.stop();
      durations.add(sw.elapsedMilliseconds);
      expect(hits, isNotEmpty, reason: 'الاستعلام "$q" يجب أن يُعيد نتائج');
    }

    durations.sort();
    final p50 = durations[durations.length ~/ 2];
    final p95 = durations[(durations.length * 0.95).floor()];
    final maxMs = durations.last;
    // ignore: avoid_print
    print('search perf: n=${durations.length} '
        'p50=${p50}ms p95=${p95}ms max=${maxMs}ms');

    expect(p95, lessThan(200),
        reason: 'المواصفة §6.5: p95 للبحث < 200ms');

    await db.close();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
