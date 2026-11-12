import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/features/capture/capture_window.dart';

import 'harness.dart';

/// Quick capture: the content is always shown for review before saving, and
/// without an active project it lands in the inbox.
void main() {
  testWidgets('the capture window shows the captured text for review',
      (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.wrap(const CaptureWindow(sharedText: 'نص ملتقَط')));
    await tester.pumpAndSettle();

    expect(find.text('حفظ عنصر جديد'), findsOneWidget);
    expect(find.text('نص ملتقَط'), findsOneWidget);
    // Nothing is saved before the user presses «حفظ».
    final items = await tester.runAsync(
      () => h.items.watchList(onlyInbox: true, onlyArchived: false).first,
    );
    expect(items, isEmpty);
    h.dispose();
  });

  testWidgets('saving puts the item in the inbox', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.wrap(const CaptureWindow(sharedText: 'نص ملتقَط')));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const Key('capture-save')),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.tap(find.byKey(const Key('capture-save')));
    await tester.pumpAndSettle();

    final items = await tester.runAsync(
      () => h.items.watchList(onlyInbox: true, onlyArchived: false).first,
    );
    expect(items, hasLength(1));
    expect(items!.single.bodyMd, 'نص ملتقَط');
    expect(items.single.isInbox, isTrue);
    h.dispose();
  });

  testWidgets('an empty capture is not saved', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.wrap(const CaptureWindow()));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const Key('capture-save')),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.tap(find.byKey(const Key('capture-save')));
    await tester.pumpAndSettle();

    final items = await tester.runAsync(
      () => h.items.watchList(onlyInbox: false, onlyArchived: false).first,
    );
    expect(items, isEmpty);
    h.dispose();
  });

  testWidgets('the capture window names the active project', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await h.projects.create(name: 'مشروع الالتقاط', status: 'active');
    await h.settings.set('active_capture_project_id',
        (await h.projects.all()).single.id);
    await tester.pumpWidget(h.wrap(const CaptureWindow(sharedText: 'نص')));
    await tester.pumpAndSettle();

    expect(find.text('مشروع الالتقاط'), findsOneWidget);
    h.dispose();
  });
}
