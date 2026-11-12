import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/data/database.dart';
import 'package:secondbrain/data/repositories/items_repository.dart';
import 'package:secondbrain/data/search_service.dart';
import 'package:secondbrain/data/write_gate.dart';

/// Spike S4 (Phase 0): FTS5 + 20k Arabic items, p95 < 200ms (spec §6.5).
/// Mirrors the 1000-item perf test but at the spec's target corpus size.
/// ⚠️ Desktop-only measurement for now; the on-device (Android) run is
/// repeated when the Android toolchain is available.
void main() {
  test('S4: search p95 < 200ms over 20000 Arabic items', () async {
    final db = AppDatabase.inMemory();
    final gate = WriteGate(db: db, clock: await db.bootClock());
    final tags = TagsRepository(db: db, gate: gate);
    final items = ItemsRepository(db: db, gate: gate, tags: tags);
    final search = SearchService(db);

    final t = await (db.select(db.itemTypes)
          ..where((x) => x.name.equals('ملاحظة')))
        .getSingle();
    final noteType = t.id;

    final seedSw = Stopwatch()..start();
    await gate.write((tx) async {
      for (var i = 0; i < 20000; i++) {
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
    // ignore: avoid_print
    print('S4 seed: 20000 items in ${seedSw.elapsedMilliseconds}ms');

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
    print('S4 search perf over 20k: n=${durations.length} '
        'p50=${p50}ms p95=${p95}ms max=${maxMs}ms');

    expect(p95, lessThan(200),
        reason: 'S4 / المواصفة §6.5: p95 للبحث < 200ms على 20k عنصر');

    await db.close();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
