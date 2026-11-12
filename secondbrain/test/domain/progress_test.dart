import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/data/database.dart';
import 'package:secondbrain/domain/progress.dart';

Task _task({
  required String id,
  String? parentId,
  String? milestoneId,
  String status = 'todo',
}) =>
    Task(
      id: id,
      userId: 'local',
      createdAt: 0,
      updatedAt: 0,
      hlc: 'x',
      projectId: null,
      milestoneId: milestoneId,
      parentTaskId: parentId,
      lessonId: null,
      title: id,
      notesMd: null,
      status: status,
      isImportant: false,
      isUrgent: false,
      estMinutes: null,
      actualMinutes: null,
      dueAt: null,
      plannedDate: null,
      plannedStartMin: null,
      completedAt: null,
      postponedCount: 0,
      sortOrder: 0,
    );

Milestone _milestone(String id, int order, {int? doneAt}) => Milestone(
      id: id,
      userId: 'local',
      createdAt: 0,
      updatedAt: 0,
      hlc: 'x',
      projectId: 'p',
      title: id,
      sortOrder: order,
      doneAt: doneAt,
    );

void main() {
  group('progress (spec §13.2)', () {
    test('auto mode counts finished leaf tasks only', () {
      final tasks = [
        _task(id: 'a', status: 'done'),
        _task(id: 'b', status: 'todo'),
        _task(id: 'parent', status: 'todo'),
        _task(id: 'child', parentId: 'parent', status: 'done'),
      ];
      final progress = computeProgress(
        progressMode: 'auto',
        manualProgress: 0,
        tasks: tasks,
      );
      // Leaves: a, b, child (parent is replaced by its child).
      expect(progress.total, 3);
      expect(progress.done, 2);
      expect(progress.percent, 66);
    });

    test('canceled tasks are excluded', () {
      final tasks = [
        _task(id: 'a', status: 'done'),
        _task(id: 'b', status: 'canceled'),
      ];
      final progress = computeProgress(
        progressMode: 'auto',
        manualProgress: 0,
        tasks: tasks,
      );
      expect(progress.total, 1);
      expect(progress.done, 1);
      expect(progress.percent, 100);
    });

    test('no tasks means «no tasks», never 0%', () {
      final progress = computeProgress(
        progressMode: 'auto',
        manualProgress: 0,
        tasks: const [],
      );
      expect(progress.hasTasks, isFalse);
      expect(progress.percent, 0);
    });

    test('manual mode uses the given percentage', () {
      final progress = computeProgress(
        progressMode: 'manual',
        manualProgress: 42,
        tasks: [_task(id: 'a', status: 'done')],
      );
      expect(progress.percent, 42);
      expect(progress.manualMode, isTrue);
    });

    test('the current milestone is the first unfinished one', () {
      final milestones = [
        _milestone('m1', 0, doneAt: 1),
        _milestone('m2', 1),
        _milestone('m3', 2),
      ];
      final tasks = [
        _task(id: 'a', milestoneId: 'm1', status: 'done'),
        _task(id: 'b', milestoneId: 'm2', status: 'todo'),
        _task(id: 'c', milestoneId: 'm3', status: 'todo'),
      ];
      expect(currentMilestone(milestones: milestones, tasks: tasks)?.id, 'm2');
    });

    test('milestone progress counts its own tasks', () {
      final tasks = [
        _task(id: 'a', milestoneId: 'm1', status: 'done'),
        _task(id: 'b', milestoneId: 'm1', status: 'todo'),
        _task(id: 'c', milestoneId: 'm2', status: 'done'),
      ];
      final p = milestoneProgress(tasks: tasks, milestoneId: 'm1');
      expect(p.total, 2);
      expect(p.done, 1);
    });
  });
}
