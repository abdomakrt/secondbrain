import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/features/projects/project_detail_screen.dart';

import 'harness.dart';

/// The project flow: create a project, watch its progress and open it.
void main() {
  Future<void> openProjects(WidgetTester tester) async {
    await tester.tap(find.text('المشاريع').last);
    await tester.pumpAndSettle();
  }

  testWidgets('create a project from the quick-add menu', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('مشروع جديد').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'مشروع الاختبار');
    await tester.enterText(find.byType(TextField).at(1), 'هدف واضح');
    await tester.tap(find.text('نشط'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    await openProjects(tester);
    expect(find.text('مشروع الاختبار'), findsOneWidget);
    // No tasks yet → the card says «لا مهام» instead of a fake 0%.
    expect(find.text('لا مهام'), findsOneWidget);

    final projects = await tester.runAsync(() => h.projects.all());
    expect(projects, hasLength(1));
    expect(projects!.single.goal, 'هدف واضح');
    h.dispose();
  });

  testWidgets('the project card shows the real progress', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    final project = await h.projects.create(name: 'مشروع نشط', status: 'active');
    await h.tasks.create(title: 'مهمة-one', projectId: project.id);
    await h.tasks.create(
      title: 'مهمة-تمّت',
      projectId: project.id,
      status: 'done',
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await openProjects(tester);
    expect(find.text('مشروع نشط'), findsOneWidget);
    // 1 of 2 tasks done.
    expect(find.textContaining('50%'), findsOneWidget);
    h.dispose();
  });

  testWidgets('the project detail shows the goal and its tabs',
      (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await h.projects.create(
      name: 'مشروع التفاصيل',
      goal: 'الهدف principal',
      status: 'active',
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await openProjects(tester);
    await tester.tap(find.text('مشروع التفاصيل'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectDetailScreen), findsOneWidget);
    expect(find.text('الهدف principal'), findsOneWidget);
    expect(find.text('المهام'), findsWidgets);
    expect(find.text('نظرة عامة'), findsOneWidget);
    h.dispose();
  });

  testWidgets('a task can be added to a project from its detail',
      (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    final project = await h.projects.create(name: 'مشروع', status: 'active');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await openProjects(tester);
    await tester.tap(find.text('مشروع'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المهام').last);
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('إضافة مهمة للمشروع'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.tap(find.text('إضافة مهمة للمشروع'));
    await tester.pumpAndSettle();

    final tasks = await tester.runAsync(
      () => h.tasks.tasksOfProject(project.id),
    );
    expect(tasks, hasLength(1));
    h.dispose();
  });
}
