import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../database.dart';
import '../write_gate.dart';

/// Courses, units and lessons (spec §14).
///
/// A course holds units, a unit holds lessons. The course progress is
/// finished lessons ÷ total lessons.
class CoursesRepository {
  CoursesRepository({required this.db, required this.gate});

  final AppDatabase db;
  final WriteGate gate;

  // ---- courses ----

  Future<Course> create({
    required String title,
    String description = '',
    String status = 'planned',
    String? projectId,
  }) =>
      gate.write((tx) async {
        final id = newId();
        final s = await tx.stamp('courses', id);
        final now = s.updatedAtMs;
        final course = Course(
          id: id,
          userId: 'local',
          createdAt: now,
          updatedAt: now,
          hlc: s.hlc,
          title: title,
          description: description,
          status: status,
          projectId: projectId,
        );
        await tx.db.into(tx.db.courses).insert(course);
        return course;
      });

  Future<Course> update(
    Course current, {
    String? title,
    String? description,
    String? status,
    String? projectId,
    String? currentLessonId,
    String? lastStop,
    bool clearLastStop = false,
    bool clearProject = false,
  }) =>
      gate.write((tx) async {
        final s = await tx.stamp('courses', current.id);
        final next = current.copyWith(
          title: title,
          description: description,
          status: status,
          projectId: clearProject
              ? const Value(null)
              : (projectId == null ? const Value.absent() : Value(projectId)),
          currentLessonId: currentLessonId == null
              ? const Value.absent()
              : Value(currentLessonId),
          lastStop: clearLastStop
              ? const Value(null)
              : (lastStop == null ? const Value.absent() : Value(lastStop)),
          updatedAt: s.updatedAtMs,
          hlc: s.hlc,
        );
        await (tx.db.update(tx.db.courses)..where((c) => c.id.equals(current.id)))
            .write(next.toCompanion(false)
                .copyWith(updatedAt: Value(s.updatedAtMs), hlc: Value(s.hlc)));
        return next;
      });

  Future<void> trash(String courseId) => gate.write((tx) async {
        final c = await (tx.db.select(tx.db.courses)
              ..where((x) => x.id.equals(courseId)))
            .getSingleOrNull();
        if (c == null || c.deletedAt != null) return;
        final s = await tx.stamp('courses', courseId);
        await (tx.db.update(tx.db.courses)..where((x) => x.id.equals(courseId)))
            .write(CoursesCompanion(
          deletedAt: Value(s.updatedAtMs),
          updatedAt: Value(s.updatedAtMs),
          hlc: Value(s.hlc),
        ));
      });

  Future<Course?> byId(String id) =>
      (db.select(db.courses)..where((c) => c.id.equals(id))).getSingleOrNull();

  Stream<List<Course>> watchList({String? status, bool includeArchived = false}) {
    final q = db.select(db.courses)..where((c) => c.deletedAt.isNull());
    if (status != null) {
      q.where((c) => c.status.equals(status));
    } else if (!includeArchived) {
      q.where((c) => c.status.isNotIn(['archived']));
    }
    return (q..orderBy([(c) => OrderingTerm.desc(c.updatedAt)])).watch();
  }

  Future<List<Course>> all() => (db.select(db.courses)
        ..where((c) => c.deletedAt.isNull())
        ..orderBy([(c) => OrderingTerm.asc(c.title)]))
      .get();

  // ---- units ----

  Future<CourseUnit> addUnit({
    required String courseId,
    required String title,
  }) =>
      gate.write((tx) async {
        final id = newId();
        final s = await tx.stamp('course_units', id);
        final now = s.updatedAtMs;
        final existing = await (tx.db.select(tx.db.courseUnits)
              ..where((u) => u.courseId.equals(courseId)))
            .get();
        final unit = CourseUnit(
          id: id,
          userId: 'local',
          createdAt: now,
          updatedAt: now,
          hlc: s.hlc,
          courseId: courseId,
          title: title,
          sortOrder: existing.length,
        );
        await tx.db.into(tx.db.courseUnits).insert(unit);
        return unit;
      });

  Future<List<CourseUnit>> unitsOf(String courseId) => (db.select(db.courseUnits)
        ..where((u) => u.courseId.equals(courseId) & u.deletedAt.isNull())
        ..orderBy([(u) => OrderingTerm.asc(u.sortOrder)]))
      .get();

  Future<void> trashUnit(String unitId) => gate.write((tx) async {
        final u = await (tx.db.select(tx.db.courseUnits)
              ..where((x) => x.id.equals(unitId)))
            .getSingleOrNull();
        if (u == null || u.deletedAt != null) return;
        final s = await tx.stamp('course_units', unitId);
        await (tx.db.update(tx.db.courseUnits)..where((x) => x.id.equals(unitId)))
            .write(CourseUnitsCompanion(
          deletedAt: Value(s.updatedAtMs),
          updatedAt: Value(s.updatedAtMs),
          hlc: Value(s.hlc),
        ));
      });

  // ---- lessons ----

  Future<Lesson> addLesson({
    required String courseId,
    String? unitId,
    required String title,
  }) =>
      gate.write((tx) async {
        final id = newId();
        final s = await tx.stamp('lessons', id);
        final now = s.updatedAtMs;
        final existing = await (tx.db.select(tx.db.lessons)
              ..where((x) => x.courseId.equals(courseId)))
            .get();
        final lesson = Lesson(
          id: id,
          userId: 'local',
          createdAt: now,
          updatedAt: now,
          hlc: s.hlc,
          courseId: courseId,
          unitId: unitId,
          title: title,
          status: 'todo',
          completedAt: null,
          sortOrder: existing.length,
        );
        await tx.db.into(tx.db.lessons).insert(lesson);
        return lesson;
      });

  Future<Lesson> updateLesson(
    Lesson lesson, {
    String? title,
    String? status,
    String? unitId,
  }) =>
      gate.write((tx) async {
        final s = await tx.stamp('lessons', lesson.id);
        final next = lesson.copyWith(
          title: title,
          status: status,
          unitId: unitId == null ? const Value.absent() : Value(unitId),
          completedAt: status == 'done' ? Value(s.updatedAtMs) : const Value.absent(),
          updatedAt: s.updatedAtMs,
          hlc: s.hlc,
        );
        await (tx.db.update(tx.db.lessons)..where((x) => x.id.equals(lesson.id)))
            .write(next.toCompanion(false)
                .copyWith(updatedAt: Value(s.updatedAtMs), hlc: Value(s.hlc)));
        return next;
      });

  Future<void> setLessonDone(Lesson lesson, bool done) => gate.write((tx) async {
        final s = await tx.stamp('lessons', lesson.id);
        await (tx.db.update(tx.db.lessons)..where((x) => x.id.equals(lesson.id)))
            .write(LessonsCompanion(
          status: Value(done ? 'done' : 'todo'),
          completedAt: Value(done ? s.updatedAtMs : null),
          updatedAt: Value(s.updatedAtMs),
          hlc: Value(s.hlc),
        ));
      });

  Future<void> trashLesson(String lessonId) => gate.write((tx) async {
        final l = await (tx.db.select(tx.db.lessons)
              ..where((x) => x.id.equals(lessonId)))
            .getSingleOrNull();
        if (l == null || l.deletedAt != null) return;
        final s = await tx.stamp('lessons', lessonId);
        await (tx.db.update(tx.db.lessons)..where((x) => x.id.equals(lessonId)))
            .write(LessonsCompanion(
          deletedAt: Value(s.updatedAtMs),
          updatedAt: Value(s.updatedAtMs),
          hlc: Value(s.hlc),
        ));
      });

  Future<Lesson?> lessonById(String id) =>
      (db.select(db.lessons)..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<List<Lesson>> lessonsOf(String courseId) => (db.select(db.lessons)
        ..where((l) => l.courseId.equals(courseId) & l.deletedAt.isNull())
        ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
      .get();

  Stream<List<Lesson>> watchLessons(String courseId) => (db.select(db.lessons)
        ..where((l) => l.courseId.equals(courseId) & l.deletedAt.isNull())
        ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
      .watch();

  /// Lessons of every course — used by the dashboard for "الدرس التالي".
  Future<List<Lesson>> allLessons() => (db.select(db.lessons)
        ..where((l) => l.deletedAt.isNull())
        ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
      .get();
}
