import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/features/courses/lesson_detail_screen.dart';

import 'harness.dart';

/// The learning flow: a course with lessons, and saving what was learned
/// from inside the lesson.
void main() {
  testWidgets('a lesson can be completed and a note saved from it',
      (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    final course = await h.courses.create(title: 'كورس الاختبار');
    final lesson = await h.courses.addLesson(
      courseId: course.id,
      title: 'الدرس الأول',
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    // Courses live behind «المزيد» on Android.
    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الكورسات').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الكل').last);
    await tester.pumpAndSettle();
    expect(find.text('كورس الاختبار'), findsOneWidget);

    await tester.tap(find.text('كورس الاختبار'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الدرس الأول'));
    await tester.pumpAndSettle();
    expect(find.byType(LessonDetailScreen), findsOneWidget);

    // Mark the lesson as done.
    await tester.tap(find.text('تحديد الدرس كمكتمل'));
    await tester.pumpAndSettle();
    final stored = await tester.runAsync(() => h.courses.lessonById(lesson.id));
    expect(stored!.status, 'done');

    // Save a note from inside the lesson.
    await tester.tap(find.text('احفظ ملاحظة من هذا الدرس'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'ما تعلمته');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final items = await tester.runAsync(
      () => h.items.watchList(onlyInbox: false, onlyArchived: false).first,
    );
    expect(items, hasLength(1));
    expect(items!.single.lessonId, lesson.id);
    expect(items.single.courseId, course.id);
    h.dispose();
  });

  testWidgets('a task can be created from a lesson', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    final course = await h.courses.create(title: 'كورس');
    final lesson = await h.courses.addLesson(courseId: course.id, title: 'درس');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الكورسات').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الكل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('كورس'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('درس'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('أنشئ مهمة من هذا الدرس'));
    await tester.pumpAndSettle();

    final tasks = await tester.runAsync(() => h.tasks.tasksOfLesson(lesson.id));
    expect(tasks, hasLength(1));
    h.dispose();
  });
}
