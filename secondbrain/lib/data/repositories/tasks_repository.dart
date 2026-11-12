import 'package:drift/drift.dart';

import '../../core/dates.dart';
import '../../core/ids.dart';
import '../database.dart';
import '../write_gate.dart';

/// Tasks and subtasks (spec §13.3, §13.4).
///
/// Day scheduling uses `planned_date` (local midnight of the day) while
/// `due_at` is an absolute deadline. "Overdue" means the deadline passed and
/// the task is not finished — the schedule is never changed automatically.
class TasksRepository {
  TasksRepository({required this.db, required this.gate});

  final AppDatabase db;
  final WriteGate gate;

  // ---- create / update ----

  Future<Task> create({
    required String title,
    String? projectId,
    String? parentTaskId,
    String? milestoneId,
    String? lessonId,
    String? notesMd,
    String status = 'todo',
    bool isImportant = false,
    bool isUrgent = false,
    int? estMinutes,
    int? dueAt,
    int? plannedDate,
    int? plannedStartMin,
  }) =>
      gate.write((tx) async {
        final id = newId();
        final s = await tx.stamp('tasks', id);
        final now = s.updatedAtMs;
        final task = Task(
          id: id,
          userId: 'local',
          createdAt: now,
          updatedAt: now,
          hlc: s.hlc,
          projectId: projectId,
          milestoneId: milestoneId,
          parentTaskId: parentTaskId,
          lessonId: lessonId,
          title: title,
          notesMd: notesMd,
          status: status,
          isImportant: isImportant,
          isUrgent: isUrgent,
          estMinutes: estMinutes,
          actualMinutes: null,
          dueAt: dueAt,
          plannedDate: plannedDate,
          plannedStartMin: plannedStartMin,
          completedAt: status == 'done' ? now : null,
          postponedCount: 0,
          sortOrder: 0,
        );
        await tx.db.into(tx.db.tasks).insert(task);
        return task;
      });

  Future<Task> update(
    Task current, {
    String? title,
    String? notesMd,
    String? projectId,
    String? parentTaskId,
    String? milestoneId,
    String? lessonId,
    String? status,
    bool? isImportant,
    bool? isUrgent,
    int? estMinutes,
    int? actualMinutes,
    int? dueAt,
    int? plannedDate,
    int? plannedStartMin,
    bool clearDueAt = false,
    bool clearPlannedDate = false,
    bool clearPlannedStart = false,
    bool clearProject = false,
    bool clearNotes = false,
  }) =>
      gate.write((tx) async {
        final s = await tx.stamp('tasks', current.id);
        final next = current.copyWith(
          title: title,
          notesMd: clearNotes
              ? const Value(null)
              : (notesMd == null ? const Value.absent() : Value(notesMd)),
          projectId: clearProject
              ? const Value(null)
              : (projectId == null ? const Value.absent() : Value(projectId)),
          parentTaskId:
              parentTaskId == null ? const Value.absent() : Value(parentTaskId),
          milestoneId:
              milestoneId == null ? const Value.absent() : Value(milestoneId),
          lessonId: lessonId == null ? const Value.absent() : Value(lessonId),
          status: status,
          isImportant: isImportant,
          isUrgent: isUrgent,
          estMinutes:
              estMinutes == null ? const Value.absent() : Value(estMinutes),
          actualMinutes:
              actualMinutes == null ? const Value.absent() : Value(actualMinutes),
          dueAt: clearDueAt
              ? const Value(null)
              : (dueAt == null ? const Value.absent() : Value(dueAt)),
          plannedDate: clearPlannedDate
              ? const Value(null)
              : (plannedDate == null ? const Value.absent() : Value(plannedDate)),
          plannedStartMin: clearPlannedStart
              ? const Value(null)
              : (plannedStartMin == null
                  ? const Value.absent()
                  : Value(plannedStartMin)),
          completedAt: status == 'done' ? Value(s.updatedAtMs) : const Value.absent(),
          updatedAt: s.updatedAtMs,
          hlc: s.hlc,
        );
        await (tx.db.update(tx.db.tasks)..where((t) => t.id.equals(current.id)))
            .write(next.toCompanion(false)
                .copyWith(updatedAt: Value(s.updatedAtMs), hlc: Value(s.hlc)));
        return next;
      });

  /// Marks a task done (or reopens it). `actualMinutes` records the time the
  /// user logged manually (spec §13.4 — no automatic time tracking in v1).
  Future<Task> setDone(Task task, bool done, {int? actualMinutes}) =>
      gate.write((tx) async {
        final s = await tx.stamp('tasks', task.id);
        await (tx.db.update(tx.db.tasks)..where((t) => t.id.equals(task.id)))
            .write(TasksCompanion(
          status: Value(done ? 'done' : 'todo'),
          completedAt: Value(done ? s.updatedAtMs : null),
          actualMinutes: actualMinutes == null
              ? const Value.absent()
              : Value(actualMinutes),
          updatedAt: Value(s.updatedAtMs),
          hlc: Value(s.hlc),
        ));
        return task.copyWith(
          status: done ? 'done' : 'todo',
          completedAt: Value(done ? s.updatedAtMs : null),
          updatedAt: s.updatedAtMs,
          hlc: s.hlc,
        );
      });

  /// Moves a task to another day, counting the postponement (spec §13.4).
  Future<void> moveToDate(Task task, int plannedDate) =>
      gate.write((tx) async {
        final s = await tx.stamp('tasks', task.id);
        await (tx.db.update(tx.db.tasks)..where((t) => t.id.equals(task.id)))
            .write(TasksCompanion(
          plannedDate: Value(plannedDate),
          postponedCount: Value(task.postponedCount + 1),
          updatedAt: Value(s.updatedAtMs),
          hlc: Value(s.hlc),
        ));
      });

  /// «إلى الغد»
  Future<void> postponeToTomorrow(Task task) =>
      moveToDate(task, dayOffset(1));

  /// «نقل كل غير المنجز إلى اليوم»
  Future<int> moveAllUnfinishedToToday({String? projectId}) =>
      gate.write((tx) async {
        final today = startOfToday();
        final q = tx.db.select(tx.db.tasks)
          ..where((t) => t.deletedAt.isNull() & t.status.isNotIn(['done', 'canceled']));
        if (projectId != null) q.where((t) => t.projectId.equals(projectId));
        final rows = await q.get();
        for (final t in rows) {
          if (t.plannedDate == today) continue;
          final s = await tx.stamp('tasks', t.id);
          await (tx.db.update(tx.db.tasks)..where((x) => x.id.equals(t.id)))
              .write(TasksCompanion(
            plannedDate: Value(today),
            postponedCount: Value(t.postponedCount + 1),
            updatedAt: Value(s.updatedAtMs),
            hlc: Value(s.hlc),
          ));
        }
        return rows.length;
      });

  /// Reorders the day's plan: the given ids keep their order (sort_order).
  Future<void> reorder(List<String> ids) => gate.write((tx) async {
        for (var i = 0; i < ids.length; i++) {
          final s = await tx.stamp('tasks', ids[i]);
          await (tx.db.update(tx.db.tasks)..where((t) => t.id.equals(ids[i])))
              .write(TasksCompanion(
            sortOrder: Value(i),
            updatedAt: Value(s.updatedAtMs),
            hlc: Value(s.hlc),
          ));
        }
      });

  /// Soft delete.
  Future<void> trash(String taskId) => gate.write((tx) async {
        final t = await (tx.db.select(tx.db.tasks)
              ..where((x) => x.id.equals(taskId)))
            .getSingleOrNull();
        if (t == null || t.deletedAt != null) return;
        final s = await tx.stamp('tasks', taskId);
        await (tx.db.update(tx.db.tasks)..where((x) => x.id.equals(taskId)))
            .write(TasksCompanion(
          deletedAt: Value(s.updatedAtMs),
          updatedAt: Value(s.updatedAtMs),
          hlc: Value(s.hlc),
        ));
      });

  // ---- reads ----

  Future<Task?> byId(String id) =>
      (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Every live task (no soft-deleted ones).
  Stream<List<Task>> watchAll({String? projectId, bool includeSubtasks = true}) {
    final q = db.select(db.tasks)..where((t) => t.deletedAt.isNull());
    if (projectId != null) q.where((t) => t.projectId.equals(projectId));
    if (!includeSubtasks) q.where((t) => t.parentTaskId.isNull());
    return (q..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();
  }

  /// Tasks planned for the given local day.
  Stream<List<Task>> watchPlannedOn(int dayStartMs, {String? projectId}) {
    final q = db.select(db.tasks)
      ..where((t) => t.deletedAt.isNull() & t.plannedDate.equals(dayStartMs));
    if (projectId != null) q.where((t) => t.projectId.equals(projectId));
    return (q..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();
  }

  /// Tasks with a deadline that already passed and are not finished.
  Stream<List<Task>> watchOverdue({int? nowMs, String? projectId}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final q = db.select(db.tasks)
      ..where((t) => t.deletedAt.isNull() &
          t.dueAt.isNotNull() &
          t.dueAt.isSmallerThanValue(now) &
          t.status.isNotIn(['done', 'canceled']));
    if (projectId != null) q.where((t) => t.projectId.equals(projectId));
    return (q..orderBy([(t) => OrderingTerm.asc(t.dueAt)])).watch();
  }

  /// Upcoming: planned after today.
  Stream<List<Task>> watchUpcoming({String? projectId}) {
    final today = startOfToday();
    final q = db.select(db.tasks)
      ..where((t) => t.deletedAt.isNull() &
          t.plannedDate.isNotNull() &
          t.plannedDate.isBiggerThanValue(today) &
          t.status.isNotIn(['done', 'canceled']));
    if (projectId != null) q.where((t) => t.projectId.equals(projectId));
    return (q..orderBy([(t) => OrderingTerm.asc(t.plannedDate)])).watch();
  }

  /// Tasks of one project (including subtasks).
  Future<List<Task>> tasksOfProject(String projectId) => (db.select(db.tasks)
        ..where((t) =>
            t.deletedAt.isNull() & t.projectId.equals(projectId)))
        .get();

  /// Direct subtasks of a task.
  Future<List<Task>> subtasksOf(String parentTaskId) => (db.select(db.tasks)
        ..where((t) => t.deletedAt.isNull() & t.parentTaskId.equals(parentTaskId)))
        .get();

  /// Tasks linked to a lesson (spec §14).
  Future<List<Task>> tasksOfLesson(String lessonId) => (db.select(db.tasks)
        ..where((t) => t.deletedAt.isNull() & t.lessonId.equals(lessonId)))
        .get();
}
