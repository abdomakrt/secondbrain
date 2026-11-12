import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/features/knowledge/item_detail_screen.dart';
import 'package:secondbrain/features/search/search_screen.dart';

import 'harness.dart';

/// RTL golden regression (knowledge list, search results, detail).
/// Ahem test font renders Arabic as boxes — still valid layout/RTL checks.
void main() {
  // Fixed clock so stamps in the golden files never change.
  const fixedNow = 1730000000000; // 2024-10-27 UTC
  int fixedClock() => fixedNow;

  testWidgets('golden: knowledge list (RTL)', (tester) async {
    final h = await Harness.create(nowMs: fixedClock);
    await h.completeSetup();
    await h.seedTypes();
    await h.items.create(
      typeId: h.noteTypeId,
      title: 'مستودع البيانات',
      bodyMd: 'شرح مفصّل عن الفهرسة والبحث العربي',
      tags: ['عمل', 'فهرسة'],
    );
    await h.items.create(
      typeId: h.noteTypeId,
      title: 'فكرة مشروع',
      bodyMd: 'بناء تطبيق المعرفة المحلي',
      isInbox: true,
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('المعرفة').last);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/knowledge_rtl.png'),
    );
    h.dispose();
  });

  testWidgets('golden: search results (RTL)', (tester) async {
    final h = await Harness.create(nowMs: fixedClock);
    await h.completeSetup();
    await h.seedTypes();
    await h.items.create(
      typeId: h.noteTypeId,
      title: 'مستودع البيانات',
      bodyMd:
          'شرح مفصّل عن الفهرسة في المستودع والبحث العربي مع التطبيع الصحيح',
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'المُستودَع');
    // Debounce is 300 ms; advance past it and let results land.
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 10; i++) {
      if (find.text('مستودع البيانات').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/search_rtl.png'),
    );
    h.dispose();
  });

  testWidgets('golden: item detail (RTL)', (tester) async {
    final h = await Harness.create(nowMs: fixedClock);
    await h.completeSetup();
    await h.seedTypes();
    await h.items.create(
      typeId: h.noteTypeId,
      title: 'مستودع البيانات',
      bodyMd: '# عنوان داخلي\n\nنص بخط واحد جديد ثم سطر تالٍ.\n\n- نقطة أولى\n- نقطة ثانية',
      tags: ['عمل', 'فهرسة'],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('المعرفة').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('مستودع البيانات'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailScreen), findsOneWidget);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/detail_rtl.png'),
    );
    h.dispose();
  });
}
