import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/features/common/widgets/content_width.dart';
import 'package:secondbrain/features/knowledge/item_edit_screen.dart';

import 'harness.dart';

/// The layout must stay readable on wide windows: forms and lists keep a
/// maximum width instead of stretching across the whole screen.
void main() {
  /// Opens the item form inside the app shell (quick add → «ملاحظة جديدة»).
  Future<void> openItemForm(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ملاحظة جديدة').last);
    await tester.pumpAndSettle();
  }

  testWidgets('a form field never grows past the form width',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await openItemForm(tester);

    final field = tester.getSize(find.byType(TextField).first);
    expect(
      field.width,
      lessThanOrEqualTo(ContentWidths.form),
      reason: 'حقول النموذج يجب ألا تتجاوز العرض الأقصى',
    );
    // The field is still centred, not glued to the window edge.
    final screen = tester.getSize(find.byType(ItemEditScreen));
    final leftGap = tester.getTopLeft(find.byType(TextField).first).dx;
    expect(leftGap, greaterThan(0));
    expect(leftGap + field.width, lessThan(screen.width));
    h.dispose();
  });

  testWidgets('the knowledge list keeps a readable width on a wide window',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('المعرفة').last);
    await tester.pumpAndSettle();

    final search = tester.getSize(find.byType(TextField).first);
    expect(search.width, lessThanOrEqualTo(ContentWidths.list));
    h.dispose();
  });

  testWidgets('ContentWidth keeps the content centred', (tester) async {
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ContentWidth(
            maxWidth: 800,
            child: SizedBox(height: 10, width: 800),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byType(SizedBox).first);
    expect(box.width, 800);
    // 2400 - 800 = 1600 → 800 on each side.
    expect(box.left, 800);
    expect(box.right, 1600);
  });
}
