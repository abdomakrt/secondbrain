import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../database.dart';
import '../write_gate.dart';

/// Projects and their milestones (spec §13.1).
///
/// Every mutation goes through [WriteGate]; deletion is soft (tombstone).
class ProjectsRepository {
  ProjectsRepository({required this.db, required this.gate});

  final AppDatabase db;
  final WriteGate gate;

  // ---- create / update ----

  Future<Project> create({
    required String name,
    String goal = '',
    String description = '',
    String status = 'planned',
    String progressMode = 'auto',
  }) =>
      gate.write((tx) async {
        final id = newId();
        final s = await tx.stamp('projects', id);
        final now = s.updatedAtMs;
        final project = Project(
          id: id,
          userId: 'local',
          createdAt: now,
          updatedAt: now,
          hlc: s.hlc,
          name: name,
          goal: goal,
          description: description,
          status: status,
          progressMode: progressMode,
          manualProgress: 0,
        );
        await tx.db.into(tx.db.projects).insert(project);
        return project;
      });

  Future<Project> update(
    Project current, {
    String? name,
    String? goal,
    String? description,
    String? status,
    String? progressMode,
    int? manualProgress,
    String? lastStop,
    String? nextStep,
    bool clearLastStop = false,
    bool clearNextStep = false,
  }) =>
      gate.write((tx) async {
        final s = await tx.stamp('projects', current.id);
        final next = current.copyWith(
          name: name,
          goal: goal,
          description: description,
          status: status,
          progressMode: progressMode,
          manualProgress: manualProgress,
          lastStop: clearLastStop
              ? const Value(null)
              : (lastStop == null ? const Value.absent() : Value(lastStop)),
          nextStep: clearNextStep
              ? const Value(null)
              : (nextStep == null ? const Value.absent() : Value(nextStep)),
          updatedAt: s.updatedAtMs,
          hlc: s.hlc,
        );
        await (tx.db.update(tx.db.projects)
              ..where((p) => p.id.equals(current.id)))
            .write(next.toCompanion(false)
                .copyWith(updatedAt: Value(s.updatedAtMs), hlc: Value(s.hlc)));
        return next;
      });

  /// Soft delete: the project is tombstoned and its children are detached
  /// (never cascaded — spec §5.1).
  Future<void> trash(String projectId) => gate.write((tx) async {
        final project = await (tx.db.select(tx.db.projects)
              ..where((p) => p.id.equals(projectId)))
            .getSingleOrNull();
        if (project == null || project.deletedAt != null) return;
        final s = await tx.stamp('projects', projectId);
        await (tx.db.update(tx.db.projects)
              ..where((p) => p.id.equals(projectId)))
            .write(ProjectsCompanion(
          deletedAt: Value(s.updatedAtMs),
          updatedAt: Value(s.updatedAtMs),
          hlc: Value(s.hlc),
        ));
        // Detach children: they survive, unclassified.
        await (tx.db.update(tx.db.tasks)
              ..where((t) => t.projectId.equals(projectId)))
            .write(TasksCompanion(
          projectId: const Value(null),
          updatedAt: Value(s.updatedAtMs),
          hlc: Value(s.hlc),
        ));
      });

  // ---- reads ----

  Future<Project?> byId(String id) =>
      (db.select(db.projects)..where((p) => p.id.equals(id)))
          .getSingleOrNull();

  /// Live list; [status] filters by project state, [includeArchived] keeps
  /// archived projects visible.
  Stream<List<Project>> watchList({String? status, bool includeArchived = false}) {
    final q = db.select(db.projects)..where((p) => p.deletedAt.isNull());
    if (status != null) {
      q.where((p) => p.status.equals(status));
    } else if (!includeArchived) {
      q.where((p) => p.status.equals('planned') |
          p.status.equals('active') |
          p.status.equals('paused') |
          p.status.equals('completed'));
    }
    return (q..orderBy([(p) => OrderingTerm.desc(p.updatedAt)])).watch();
  }

  /// All non-deleted projects ordered by name (pickers, filters).
  Future<List<Project>> all() => (db.select(db.projects)
        ..where((p) => p.deletedAt.isNull())
        ..orderBy([(p) => OrderingTerm.asc(p.name)]))
      .get();

  /// The newest activity inside the project: the project row itself, its
  /// tasks or its knowledge items (spec §13.1 "آخر نشاط").
  Future<int?> lastActivityAt(String projectId) async {
    final project = await byId(projectId);
    var latest = project?.updatedAt;
    final task = await (db.select(db.tasks)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (task != null && (latest == null || task.updatedAt > latest)) {
      latest = task.updatedAt;
    }
    final item = await (db.select(db.items)
          ..where((i) => i.projectId.equals(projectId))
          ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (item != null && (latest == null || item.updatedAt > latest)) {
      latest = item.updatedAt;
    }
    return latest;
  }

  // ---- milestones ----

  Future<List<Milestone>> milestonesOf(String projectId) => (db.select(db.milestones)
        ..where((m) => m.projectId.equals(projectId) & m.deletedAt.isNull())
        ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]))
      .get();

  Future<Milestone> addMilestone({
    required String projectId,
    required String title,
  }) =>
      gate.write((tx) async {
        final id = newId();
        final s = await tx.stamp('milestones', id);
        final now = s.updatedAtMs;
        final existing = await (tx.db.select(tx.db.milestones)
              ..where((m) => m.projectId.equals(projectId)))
            .get();
        final order = existing.length;
        final milestone = Milestone(
          id: id,
          userId: 'local',
          createdAt: now,
          updatedAt: now,
          hlc: s.hlc,
          projectId: projectId,
          title: title,
          sortOrder: order,
        );
        await tx.db.into(tx.db.milestones).insert(milestone);
        return milestone;
      });

  Future<void> renameMilestone(Milestone milestone, String title) =>
      gate.write((tx) async {
        final s = await tx.stamp('milestones', milestone.id);
        await (tx.db.update(tx.db.milestones)
              ..where((m) => m.id.equals(milestone.id)))
            .write(MilestonesCompanion(
          title: Value(title),
          updatedAt: Value(s.updatedAtMs),
          hlc: Value(s.hlc),
        ));
      });

  Future<void> setMilestoneDone(Milestone milestone, bool done) =>
      gate.write((tx) async {
        final s = await tx.stamp('milestones', milestone.id);
        await (tx.db.update(tx.db.milestones)
              ..where((m) => m.id.equals(milestone.id)))
            .write(MilestonesCompanion(
          doneAt: Value(done ? s.updatedAtMs : null),
          updatedAt: Value(s.updatedAtMs),
          hlc: Value(s.hlc),
        ));
      });

  Future<void> trashMilestone(String milestoneId) => gate.write((tx) async {
        final m = await (tx.db.select(tx.db.milestones)
              ..where((x) => x.id.equals(milestoneId)))
            .getSingleOrNull();
        if (m == null || m.deletedAt != null) return;
        final s = await tx.stamp('milestones', milestoneId);
        await (tx.db.update(tx.db.milestones)
              ..where((x) => x.id.equals(milestoneId)))
            .write(MilestonesCompanion(
          deletedAt: Value(s.updatedAtMs),
          updatedAt: Value(s.updatedAtMs),
          hlc: Value(s.hlc),
        ));
      });
}
