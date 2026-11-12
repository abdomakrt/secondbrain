import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/features/knowledge/daily_note.dart';
import 'package:secondbrain/features/tasks/task_edit_screen.dart';

import 'harness.dart';

/// The quick-add button next to the search box and the per-section add
/// buttons (UI_SPEC §3).
void main() {
  /// The desktop layout (side bar + top bar) needs a wide surface.
  void useDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('the quick-add next to the search saves the typed text as a '
      'note of the day', (tester) async {
    useDesktopSurface(tester);
    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    // The button next to the search box turns into «add as a note» as soon
    // as there is text.
    await tester.enterText(
      find.widgetWithText(TextField, 'ابحث في معرفتك…'),
      'سطر ملاحظة اليوم',
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.note_add_outlined));
    await tester.pumpAndSettle();

    final items = await tester.runAsync(
      () => h.items.watchList(onlyInbox: false, onlyArchived: false).first,
    );
    expect(items, hasLength(1));
    expect(items!.single.title, 'سطر ملاحظة اليوم');
    expect(items.single.bodyMd, 'سطر ملاحظة اليوم');
    // It is tagged as a note of the day.
    final tags = await tester.runAsync(() => h.items.tagsOf(items.single.id));
    expect(tags?.map((t) => t.name), contains(DailyNote.tag));
    // The search box is cleared afterwards.
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'ابحث في معرفتك…'))
          .controller!
          .text,
      isEmpty,
    );
    h.dispose();
  });

  testWidgets('each section has its own add button', (tester) async {
    useDesktopSurface(tester);
    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    // The tasks section opens the task editor.
    await tester.tap(find.text('المهام').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'مهمة جديدة'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditScreen), findsOneWidget);
    h.dispose();
  });

  testWidgets('the projects section opens the project editor', (tester) async {
    useDesktopSurface(tester);
    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('المشاريع').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'مشروع جديد'));
    await tester.pumpAndSettle();
    expect(find.text('اسم المشروع'), findsOneWidget);
    h.dispose();
  });
}
