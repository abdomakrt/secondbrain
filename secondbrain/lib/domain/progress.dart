/// Progress calculation (spec §13.2).
///
/// Two modes:
/// - `auto` (default): done ÷ total over *leaf* tasks (tasks without
///   subtasks). Canceled tasks are excluded. A parent task is represented by
///   its children, so it is never counted twice.
/// - `manual`: the user sets the percentage directly.
///
/// When there is nothing to count, the result is "no tasks" — never a fake 0%
/// (UI_SPEC §5.2: "لا تعرض نسب تقدم غير محسوبة من بيانات فعلية").
library;

import '../data/database.dart';

class Progress {
  const Progress({
    required this.done,
    required this.total,
    required this.manual,
    required this.manualMode,
  });

  /// Number of finished leaf tasks (auto mode).
  final int done;

  /// Number of counted leaf tasks (auto mode).
  final int total;

  /// Manual percentage (0..100) when [manualMode] is true.
  final int manual;

  /// True when the project uses the manual percentage.
  final bool manualMode;

  /// True when there is nothing to count — the UI shows «لا مهام» instead.
  bool get hasTasks => total > 0;

  /// Percentage 0..100 rounded down.
  int get percent {
    if (manualMode) return manual.clamp(0, 100);
    if (!hasTasks) return 0;
    return ((done / total) * 100).floor();
  }

  /// «4 من 10 مهام»
  String get countLabel => '$done من $total';
}

/// Computes the progress of a project from its tasks.
///
/// [tasks] must contain the project's tasks only.
Progress computeProgress({
  required String progressMode,
  required int manualProgress,
  required List<Task> tasks,
}) {
  if (progressMode == 'manual') {
    return Progress(
      done: 0,
      total: 0,
      manual: manualProgress,
      manualMode: true,
    );
  }
  // Parent ids: any task referenced as `parent_task_id`.
  final parentIds = <String>{
    for (final t in tasks)
      if (t.parentTaskId != null) t.parentTaskId!,
  };
  final leaves = tasks
      .where((t) => !parentIds.contains(t.id))
      .where((t) => t.status != 'canceled')
      .toList();
  final done = leaves.where((t) => t.status == 'done').length;
  return Progress(
    done: done,
    total: leaves.length,
    manual: manualProgress,
    manualMode: false,
  );
}

/// Progress of one milestone, from the tasks attached to it.
Progress milestoneProgress({
  required List<Task> tasks,
  required String milestoneId,
}) {
  final scoped = tasks.where((t) => t.milestoneId == milestoneId).toList();
  final parentIds = <String>{
    for (final t in scoped)
      if (t.parentTaskId != null) t.parentTaskId!,
  };
  final leaves = scoped
      .where((t) => !parentIds.contains(t.id))
      .where((t) => t.status != 'canceled')
      .toList();
  return Progress(
    done: leaves.where((t) => t.status == 'done').length,
    total: leaves.length,
    manual: 0,
    manualMode: false,
  );
}

/// The first milestone that is not fully done, in sort order — the current
/// phase of the project (spec §13.2).
Milestone? currentMilestone({
  required List<Milestone> milestones,
  required List<Task> tasks,
}) {
  final sorted = [...milestones]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  for (final m in sorted) {
    if (m.doneAt != null) continue;
    final p = milestoneProgress(tasks: tasks, milestoneId: m.id);
    if (p.total > 0 && p.done < p.total) return m;
    if (p.total == 0 && m.doneAt == null) return m;
  }
  return null;
}
