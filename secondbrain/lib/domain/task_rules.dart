/// Task rules shared by the UI and the repositories (spec §13.3, §13.4).
///
/// The four Eisenhower quadrants are the app's priority model: a task carries
/// `is_important` and `is_urgent`, and the label always appears next to the
/// colour/icon so the meaning never depends on colour alone (UI_SPEC §3.8).
library;

import '../data/database.dart';

enum TaskStatus { todo, doing, done, canceled }

enum TaskView { today, upcoming, overdue, all }

/// The four quadrants of the priority matrix.
enum PriorityQuadrant {
  importantUrgent,
  importantNotUrgent,
  notImportantUrgent,
  notImportantNotUrgent,
}

/// Quadrant of a task (by its two flags).
PriorityQuadrant quadrantOf({required bool important, required bool urgent}) {
  if (important && urgent) return PriorityQuadrant.importantUrgent;
  if (important) return PriorityQuadrant.importantNotUrgent;
  if (urgent) return PriorityQuadrant.notImportantUrgent;
  return PriorityQuadrant.notImportantNotUrgent;
}

/// Stable database value for a task status.
String statusValue(TaskStatus s) => switch (s) {
      TaskStatus.todo => 'todo',
      TaskStatus.doing => 'doing',
      TaskStatus.done => 'done',
      TaskStatus.canceled => 'canceled',
    };

/// Parses a stored status value (unknown values fall back to `todo`).
TaskStatus statusFrom(String? value) => switch (value) {
      'doing' => TaskStatus.doing,
      'done' => TaskStatus.done,
      'canceled' => TaskStatus.canceled,
      _ => TaskStatus.todo,
    };

/// A task counts as "finished" when done or canceled.
bool isFinished(Task t) =>
    t.status == 'done' || t.status == 'canceled';

/// True when the task has a deadline in the past and is not finished.
bool isOverdue(Task t, {int? nowMs}) {
  if (t.dueAt == null) return false;
  if (isFinished(t)) return false;
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  return t.dueAt! < now;
}

/// True when the task is planned for the given local day.
bool isPlannedOn(Task t, int dayStartMs) => t.plannedDate == dayStartMs;

/// Whether the task has no subtasks (a "leaf") — the unit of auto progress.
bool isLeaf(Task t, Iterable<String> parentIds) => !parentIds.contains(t.id);

/// Sorts tasks for a list: unfinished first, then by priority quadrant, then
/// by planned time, then by explicit sort order.
int compareTasks(Task a, Task b) {
  final doneA = isFinished(a);
  final doneB = isFinished(b);
  if (doneA != doneB) return doneA ? 1 : -1;

  final qa = quadrantOf(important: a.isImportant, urgent: a.isUrgent);
  final qb = quadrantOf(important: b.isImportant, urgent: b.isUrgent);
  if (qa != qb) return qa.index.compareTo(qb.index);

  final sa = a.plannedStartMin;
  final sb = b.plannedStartMin;
  if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
  if (sa != null && sb == null) return -1;
  if (sa == null && sb != null) return 1;

  if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
  return a.createdAt.compareTo(b.createdAt);
}
