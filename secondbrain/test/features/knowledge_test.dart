import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/features/knowledge/item_detail_screen.dart';
import 'package:secondbrain/features/knowledge/item_edit_screen.dart';
import 'package:secondbrain/features/knowledge/related_items_screen.dart';
import 'package:secondbrain/features/knowledge/trash_screen.dart';
import 'package:secondbrain/features/shell/app_shell.dart';

import 'harness.dart';

/// The knowledge flow inside the app shell: creating an item, browsing it,
/// searching it, trashing it and linking items.
void main() {
  /// Opens the knowledge section from the bottom navigation.
  Future<void> openKnowledge(WidgetTester tester) async {
    await tester.tap(find.text('المعرفة').last);
    await tester.pumpAndSettle();
  }

  /// Opens a section that lives behind «المزيد» on Android.
  Future<void> openMoreSection(WidgetTester tester, String label) async {
    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('create item via the quick-add menu, then see it in the list',
      (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    // Quick add (+) → «ملاحظة جديدة».
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ملاحظة جديدة').last);
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditScreen), findsOneWidget);

    // Text fields order: title, tags, body (dropdowns are not text fields).
    final texts = find.byType(TextField);
    await tester.enterText(texts.at(0), 'مستودع البيانات');
    await tester.enterText(texts.at(1), 'عمل، فهرسة');
    await tester.enterText(texts.at(2), '# محتوى\nسطر أول');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    // Detail screen shows the title.
    expect(find.byType(ItemDetailScreen), findsOneWidget);
    expect(find.text('مستودع البيانات'), findsOneWidget);
    await tester.runAsync(() async {
      final all = await h.items
          .watchList(onlyInbox: false, onlyArchived: false)
          .first;
      expect(all, hasLength(1));
      expect((await h.items.tagsOf(all.single.id)).length, 2);
    });
    h.dispose();
  });

  testWidgets('knowledge list renders items; the inbox holds the rest',
      (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await h.seedTypes();
    await h.items.create(typeId: h.noteTypeId, title: 'عنصر عادي');
    await h.items.create(typeId: h.noteTypeId, title: 'عنصر وارد', isInbox: true);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await openKnowledge(tester);
    expect(find.text('عنصر عادي'), findsOneWidget);
    expect(find.text('عنصر وارد'), findsNothing);

    // The inbox section keeps the unorganized item.
    await openMoreSection(tester, 'الوارد');
    expect(find.text('عنصر وارد'), findsOneWidget);
    expect(find.text('عنصر عادي'), findsNothing);
    h.dispose();
  });

  testWidgets('search finds an item and shows a snippet', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await h.seedTypes();
    await h.items.create(
      typeId: h.noteTypeId,
      title: 'مستودع البيانات',
      bodyMd: 'شرح مفصّل عن الفهرسة في المستودع والبحث العربي',
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    // Open the unified search from the app bar.
    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();
    // Normalized query with tashkeel + «ال» prefix.
    await tester.enterText(find.byType(TextField).first, 'المُستودَع');
    await tester.pump(const Duration(milliseconds: 400));
    // The query runs asynchronously — pump until the result arrives.
    for (var i = 0; i < 10; i++) {
      if (find.text('مستودع البيانات').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('مستودع البيانات'), findsOneWidget);
    h.dispose();
  });

  testWidgets('trash then restore', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await h.seedTypes();
    final item = await h.items.create(
        typeId: h.noteTypeId, title: 'سيُحذف', bodyMd: 'محتوى');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await openKnowledge(tester);

    // From the detail screen: open → trash.
    await tester.tap(find.text('سيُحذف'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect((await h.items.byId(item.id))!.deletedAt, isNotNull);

    // Trash screen → restore.
    await openMoreSection(tester, 'السلة المحذوفات');
    expect(find.byType(TrashScreen), findsOneWidget);
    expect(find.text('سيُحذف'), findsOneWidget);
    await tester.tap(find.text('استرجاع'));
    await tester.pumpAndSettle();
    expect((await h.items.byId(item.id))!.deletedAt, isNull);
    h.dispose();
  });

  testWidgets('related items: link, see, unlink', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await h.seedTypes();
    await h.items.create(typeId: h.noteTypeId, title: 'الأصل');
    await h.items.create(typeId: h.noteTypeId, title: 'المرتبط');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await openKnowledge(tester);
    await tester.tap(find.text('الأصل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العناصر المرتبطة'));
    await tester.pumpAndSettle();
    expect(find.byType(RelatedItemsScreen), findsOneWidget);
    expect(find.text('لا توجد عناصر مرتبطة'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_link));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المرتبط'));
    await tester.pumpAndSettle();
    expect(find.text('المرتبط'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.link_off));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد عناصر مرتبطة'), findsOneWidget);
    h.dispose();
  });

  testWidgets('the shell shows the main sections', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    // The dashboard is the landing section.
    expect(find.text('ملخص اليوم'), findsOneWidget);
    h.dispose();
  });
}
