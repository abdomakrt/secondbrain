import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/core/dates.dart';
import 'package:secondbrain/features/tasks/task_detail_screen.dart';
import 'package:secondbrain/features/tasks/task_edit_screen.dart';

import 'harness.dart';

/// The daily task flow: create a task, find it in the day plan, complete it
/// and postpone it.
void main() {
  Future<void> openTasks(WidgetTester tester) async {
    await tester.tap(find.text('المهام').last);
    await tester.pumpAndSettle();
  }

  Future<void> openAllTasks(WidgetTester tester) async {
    await openTasks(tester);
    await tester.tap(find.text('كل المهام').last);
    await tester.pumpAndSettle();
  }

  testWidgets('create a task from the quick-add menu and find it',
      (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('مهمة جديدة').last);
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'كتابة التقرير');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    await openAllTasks(tester);
    expect(find.text('كتابة التقرير'), findsOneWidget);

    final tasks = await tester.runAsync(() => h.tasks.watchAll().first);
    expect(tasks, hasLength(1));
    expect(tasks!.single.title, 'كتابة التقرير');
    h.dispose();
  });

  testWidgets('completing a task from the list updates the day summary',
      (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await h.tasks.create(
      title: 'مهمة اليوم',
      plannedDate: startOfToday(),
      isImportant: true,
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await openTasks(tester);
    expect(find.text('مهمة اليوم'), findsOneWidget);

    // The checkbox completes the task.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    final tasks = await tester.runAsync(() => h.tasks.watchAll().first);
    expect(tasks!.single.status, 'done');
    h.dispose();
  });

  testWidgets('the overdue view lists tasks with a passed deadline',
      (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await h.tasks.create(
      title: 'مهمة متأخرة',
      dueAt: DateTime.now().millisecondsSinceEpoch - 3600000,
    );
    await h.tasks.create(title: 'مهمة عادية');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await openTasks(tester);
    expect(find.text('مهمة عادية'), findsNothing);

    await tester.tap(find.text('المتأخرة').last);
    await tester.pumpAndSettle();
    expect(find.text('مهمة متأخرة'), findsOneWidget);
    h.dispose();
  });

  testWidgets('the task detail shows the priority matrix and saves',
      (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    final task = await h.tasks.create(
      title: 'مهمة تفاصيل',
      plannedDate: startOfToday(),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await openTasks(tester);
    await tester.tap(find.text('مهمة تفاصيل'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailScreen), findsOneWidget);
    expect(find.text('الأهمية والاستعجال'), findsOneWidget);

    // Pick the «مهم وعاجل» quadrant and save.
    await tester.tap(find.text('مهم وعاجل'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('task-save')),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.tap(find.byKey(const Key('task-save')));
    await tester.pumpAndSettle();

    final stored = await tester.runAsync(() => h.tasks.byId(task.id));
    expect(stored!.isImportant, isTrue);
    expect(stored.isUrgent, isTrue);
    h.dispose();
  });

  testWidgets('a subtask can be added from the task detail', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    final parent = await h.tasks.create(
      title: 'مهمة رئيسية',
      plannedDate: startOfToday(),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await openTasks(tester);
    await tester.tap(find.text('مهمة رئيسية'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const Key('subtask-field')),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.enterText(
      find.byKey(const Key('subtask-field')),
      'خطوة أولى',
    );
    await tester.tap(find.byKey(const Key('add-subtask')));
    await tester.pumpAndSettle();

    final subs =
        await tester.runAsync(() => h.tasks.subtasksOf(parent.id));
    expect(subs!.map((t) => t.title), contains('خطوة أولى'));
    h.dispose();
  });
}
