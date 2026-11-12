import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/data/repositories/local_paths_repository.dart';

import '../features/harness.dart';

/// Project/course deletion and the linked folders (spec §5.1, §12).
void main() {
  late Harness h;

  setUp(() async {
    h = await Harness.create();
    await h.seedTypes();
  });

  tearDown(() {
    h.dispose();
  });

  group('soft delete', () {
    test('trashing a project detaches its tasks and knowledge', () async {
      final project = await h.projects.create(name: 'مشروع');
      final task = await h.tasks.create(title: 'مهمة', projectId: project.id);
      final item = await h.items.create(
        typeId: h.noteTypeId,
        title: 'عنصر',
        projectId: project.id,
      );

      await h.projects.trash(project.id);

      // The project is gone from every read…
      expect(await h.projects.byId(project.id), isNull);
      expect(
        (await h.projects.all()).any((p) => p.id == project.id),
        isFalse,
      );
      // …but the children survive, unclassified.
      final storedTask =
          (await h.db.select(h.db.tasks).get()).firstWhere((t) => t.id == task.id);
      expect(storedTask.projectId, isNull);
      final storedItem = await h.items.byId(item.id);
      expect(storedItem, isNotNull);
      expect(storedItem!.projectId, isNull);
    });

    test('trashing a course detaches the knowledge items', () async {
      final course = await h.courses.create(title: 'كورس');
      final item = await h.items.create(
        typeId: h.noteTypeId,
        title: 'عنصر',
        courseId: course.id,
      );

      await h.courses.trash(course.id);

      expect(await h.courses.byId(course.id), isNull);
      final storedItem = await h.items.byId(item.id);
      expect(storedItem, isNotNull);
      expect(storedItem!.courseId, isNull);
    });
  });

  group('linked folders', () {
    test('a folder is linked once per owner and can be removed', () async {
      const path = '/tmp/secondbrain-course';
      final first = await h.localPaths.add(
        ownerType: LocalPathsRepository.ownerCourse,
        ownerId: 'course-1',
        path: path,
        label: 'المواد',
      );
      final again = await h.localPaths.add(
        ownerType: LocalPathsRepository.ownerCourse,
        ownerId: 'course-1',
        path: path,
      );

      expect(again.id, first.id);
      expect(
        await h.localPaths.listFor(
          LocalPathsRepository.ownerCourse,
          'course-1',
        ),
        hasLength(1),
      );

      await h.localPaths.remove(first.id);
      expect(
        await h.localPaths.listFor(
          LocalPathsRepository.ownerCourse,
          'course-1',
        ),
        isEmpty,
      );
    });

    test('folders of another owner are not listed', () async {
      await h.localPaths.add(
        ownerType: LocalPathsRepository.ownerProject,
        ownerId: 'project-1',
        path: '/tmp/a',
      );
      expect(
        await h.localPaths.listFor(
          LocalPathsRepository.ownerCourse,
          'course-1',
        ),
        isEmpty,
      );
    });
  });

  group('source link', () {
    test('a course keeps its source url', () async {
      final course = await h.courses.create(
        title: 'كورس',
        sourceUrl: 'https://example.com/course',
      );
      expect(course.sourceUrl, 'https://example.com/course');

      await h.courses.update(course, sourceUrl: 'https://example.com/2');
      expect(
        (await h.courses.byId(course.id))!.sourceUrl,
        'https://example.com/2',
      );

      await h.courses.update(course, clearSourceUrl: true);
      expect((await h.courses.byId(course.id))!.sourceUrl, isNull);
    });

    test('a project keeps its source url', () async {
      final project = await h.projects.create(
        name: 'مشروع',
        sourceUrl: 'https://example.com',
      );
      expect(project.sourceUrl, 'https://example.com');
      expect(
        (await h.projects.byId(project.id))!.sourceUrl,
        'https://example.com',
      );
    });
  });
}
