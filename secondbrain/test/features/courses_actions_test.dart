import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/features/courses/course_detail_screen.dart';

import 'harness.dart';

/// The courses screen: adding a lesson, and deleting a course.
void main() {
  /// Opens the courses section (behind «المزيد» on Android).
  Future<void> openCourses(WidgetTester tester) async {
    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الكورسات').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الكل').last);
    await tester.pumpAndSettle();
  }

  testWidgets('a lesson can be added from the course details',
      (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    final course = await h.courses.create(title: 'كورس');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await openCourses(tester);
    await tester.tap(find.text('كورس'));
    await tester.pumpAndSettle();
    expect(find.byType(CourseDetailScreen), findsOneWidget);

    await tester.tap(find.text('إضافة درس').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'درس جديد');
    await tester.tap(find.text('حفظ').last);
    await tester.pumpAndSettle();

    final lessons = await tester.runAsync(() => h.courses.lessonsOf(course.id));
    expect(lessons, hasLength(1));
    expect(lessons!.single.title, 'درس جديد');
    h.dispose();
  });

  testWidgets('a course can be deleted from its card menu', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    final course = await h.courses.create(title: 'كورس للحذف');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await openCourses(tester);
    expect(find.text('كورس للحذف'), findsOneWidget);

    // The card menu holds «حذف الكورس».
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف الكورس').last);
    await tester.pumpAndSettle();

    // A confirmation is required before anything is deleted.
    expect(find.text('سيُنقل الكورس إلى السلة. تبقى الدروس والمعرفة محفوظة.'),
        findsOneWidget);
    await tester.tap(find.text('حذف الكورس').last);
    await tester.pumpAndSettle();

    expect(await tester.runAsync(() => h.courses.byId(course.id)), isNull);
    expect(find.text('كورس للحذف'), findsNothing);
    h.dispose();
  });
}
