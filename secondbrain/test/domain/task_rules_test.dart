import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/data/database.dart';
import 'package:secondbrain/domain/task_rules.dart';

Task _task({
  String status = 'todo',
  bool important = false,
  bool urgent = false,
  int? dueAt,
  int? plannedDate,
  int? plannedStartMin,
  int sortOrder = 0,
  int createdAt = 0,
}) =>
    Task(
      id: 'id-$createdAt-$sortOrder',
      userId: 'local',
      createdAt: createdAt,
      updatedAt: createdAt,
      hlc: 'x',
      projectId: null,
      milestoneId: null,
      parentTaskId: null,
      lessonId: null,
      title: 'task',
      notesMd: null,
      status: status,
      isImportant: important,
      isUrgent: urgent,
      estMinutes: null,
      actualMinutes: null,
      dueAt: dueAt,
      plannedDate: plannedDate,
      plannedStartMin: plannedStartMin,
      completedAt: null,
      postponedCount: 0,
      sortOrder: sortOrder,
    );

void main() {
  group('task rules (spec §13.3, §13.4)', () {
    test('the four priority quadrants', () {
      expect(
        quadrantOf(important: true, urgent: true),
        PriorityQuadrant.importantUrgent,
      );
      expect(
        quadrantOf(important: true, urgent: false),
        PriorityQuadrant.importantNotUrgent,
      );
      expect(
        quadrantOf(important: false, urgent: true),
        PriorityQuadrant.notImportantUrgent,
      );
      expect(
        quadrantOf(important: false, urgent: false),
        PriorityQuadrant.notImportantNotUrgent,
      );
    });

    test('status parsing falls back to todo', () {
      expect(statusFrom('doing'), TaskStatus.doing);
      expect(statusFrom('done'), TaskStatus.done);
      expect(statusFrom('canceled'), TaskStatus.canceled);
      expect(statusFrom('nonsense'), TaskStatus.todo);
      expect(statusFrom(null), TaskStatus.todo);
    });

    test('overdue means a passed deadline on an unfinished task', () {
      final now = 1000;
      expect(isOverdue(_task(dueAt: 500), nowMs: now), isTrue);
      expect(isOverdue(_task(dueAt: 1500), nowMs: now), isFalse);
      expect(isOverdue(_task(dueAt: 500, status: 'done'), nowMs: now), isFalse);
      expect(isOverdue(_task(dueAt: 500, status: 'canceled'), nowMs: now),
          isFalse);
      expect(isOverdue(_task(), nowMs: now), isFalse);
    });

    test('unfinished tasks come first, then by priority', () {
      final tasks = [
        _task(status: 'done', important: true, urgent: true, createdAt: 1),
        _task(important: false, urgent: false, createdAt: 2),
        _task(important: true, urgent: true, createdAt: 3),
      ]..sort(compareTasks);
      expect(tasks.first.status, 'todo');
      expect(tasks.first.isImportant, isTrue);
      expect(tasks.last.status, 'done');
    });

    test('scheduled tasks are ordered by their planned start', () {
      final tasks = [
        _task(plannedStartMin: 600, createdAt: 1),
        _task(plannedStartMin: 300, createdAt: 2),
      ]..sort(compareTasks);
      expect(tasks.first.plannedStartMin, 300);
    });
  });
}
