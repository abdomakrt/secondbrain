import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/core/dates.dart';

import 'harness.dart';

/// The dashboard answers «what deserves my attention now?».
void main() {
  testWidgets('the dashboard summarises today', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await h.tasks.create(
      title: 'مهمة منجزة',
      plannedDate: startOfToday(),
      status: 'done',
    );
    await h.tasks.create(
      title: 'مهمة معلقة',
      plannedDate: startOfToday(),
    );
    await h.tasks.create(
      title: 'مهمة متأخرة',
      dueAt: DateTime.now().millisecondsSinceEpoch - 3600000,
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('ملخص اليوم'), findsOneWidget);
    expect(find.text('أهم مهام اليوم'), findsOneWidget);
    expect(find.text('مهمة معلقة'), findsOneWidget);
    // The finished task is still listed, but struck through.
    expect(find.text('مهمة منجزة'), findsOneWidget);
    // The overdue task has its own short alert block.
    await tester.dragUntilVisible(
      find.text('مهمة متأخرة'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    expect(find.text('مهمة متأخرة'), findsOneWidget);
    h.dispose();
  });

  testWidgets('the dashboard links to the other sections', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    // «عرض الكل» next to the active projects opens the projects section.
    await tester.tap(find.byKey(const Key('dashboard-projects-all')));
    await tester.pumpAndSettle();
    expect(find.text('مخطط لها'), findsOneWidget);
    h.dispose();
  });

  testWidgets('the dashboard shows the active project with its progress',
      (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    final project = await h.projects.create(name: 'مشروع لوحة', status: 'active');
    await h.tasks.create(
      title: 'خطوة',
      projectId: project.id,
      status: 'done',
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('مشروع لوحة'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    expect(find.text('مشروع لوحة'), findsOneWidget);
    expect(find.textContaining('100%'), findsOneWidget);
    h.dispose();
  });
}
