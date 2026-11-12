import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../common/widgets/content_width.dart';
import '../../data/database.dart';
import '../../domain/progress.dart';
import '../common/labels.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/db_stream_builder.dart';
import '../common/widgets/progress_bar.dart';
import '../knowledge/item_detail_screen.dart';
import '../knowledge/widgets/type_icons.dart';
import '../shell/app_shell.dart';
import 'lesson_detail_screen.dart';

/// Course details (UI_SPEC §5, UI-12).
///
/// The units, the lessons, the progress and the last stop point, plus the
/// knowledge items saved from the course.
class CourseDetailView extends StatefulWidget {
  const CourseDetailView({super.key, required this.courseId});

  final String courseId;

  @override
  State<CourseDetailView> createState() => _CourseDetailViewState();
}

class _CourseDetailViewState extends State<CourseDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return StreamBuilder<Course?>(
      stream: (scope.db.select(scope.db.courses)
            ..where((c) => c.id.equals(widget.courseId)))
          .watchSingleOrNull(),
      builder: (context, snap) {
        final course = snap.data;
        if (course == null) {
          return const LoadingView();
        }
        return Column(
          children: [
            _Header(course: course),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: l.lessons),
                Tab(text: l.knowledgeTitle),
                Tab(text: l.overview),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _LessonsTab(course: course),
                  _CourseKnowledgeTab(course: course),
                  _OverviewTab(course: course),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Full-screen route wrapper around [CourseDetailView].
class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.courseDetails)),
      body: ContentWidth(
        maxWidth: ContentWidths.details,
        child: CourseDetailView(courseId: courseId),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);

    return DbStreamBuilder<List<Lesson>>(
      streamFactory: () => scope.courses.watchLessons(course.id),
      builder: (context, snap) {
        final lessons = snap.data ?? const <Lesson>[];
        final done = lessons.where((x) => x.status == 'done').length;
        final progress = Progress(
          done: done,
          total: lessons.length,
          manual: 0,
          manualMode: false,
        );
        final next = lessons.where((x) => x.status != 'done').toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.title,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (course.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(course.description),
              ],
              const SizedBox(height: 10),
              ProgressBar(progress: progress),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (next.isNotEmpty)
                    FilledButton.icon(
                      onPressed: () => openDetail(
                        context,
                        title: next.first.title,
                        builder: (_) =>
                            LessonDetailScreen(lessonId: next.first.id),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l.continueLearning),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _editStop(context, course),
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(l.lastStop),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editStop(BuildContext context, Course course) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final controller = TextEditingController(text: course.lastStop ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.lastStop),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved != true) return;
    await scope.courses.update(
      course,
      lastStop: controller.text.trim(),
      clearLastStop: controller.text.trim().isEmpty,
    );
  }
}

class _LessonsTab extends StatelessWidget {
  const _LessonsTab({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return DbStreamBuilder<List<CourseUnit>>(
      streamFactory: () => (scope.db.select(scope.db.courseUnits)
            ..where((u) => u.courseId.equals(course.id))
            ..orderBy([(u) => OrderingTerm.asc(u.sortOrder)]))
          .watch(),
      builder: (context, unitSnap) {
        final units = unitSnap.data ?? const <CourseUnit>[];
        return DbStreamBuilder<List<Lesson>>(
          streamFactory: () => scope.courses.watchLessons(course.id),
          builder: (context, lessonSnap) {
            final lessons = lessonSnap.data ?? const <Lesson>[];
            if (lessons.isEmpty) {
              return EmptyState(
                icon: Icons.menu_book_outlined,
                title: l.noLessons,
                message: l.noLessonsHint,
              );
            }
            final grouped = <String?, List<Lesson>>{};
            for (final unit in units) {
              grouped[unit.id] = lessons.where((x) => x.unitId == unit.id).toList();
            }
            grouped[null] =
                lessons.where((x) => x.unitId == null || !units.any((u) => u.id == x.unitId)).toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                for (final unit in units) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      unit.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  for (final lesson in grouped[unit.id] ?? const <Lesson>[])
                    _LessonTile(lesson: lesson),
                ],
                if ((grouped[null] ?? const <Lesson>[]).isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      l.otherLessons,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  for (final lesson in grouped[null]!)
                    _LessonTile(lesson: lesson),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListTile(
      leading: Icon(
        lessonStatusIcon(lesson.status),
        color: lesson.status == 'done'
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Text(lesson.title),
      subtitle: Text(lessonStatusLabel(context, lesson.status)),
      trailing: Checkbox(
        value: lesson.status == 'done',
        onChanged: (v) =>
            scope.courses.setLessonDone(lesson, v ?? false),
      ),
      onTap: () => openDetail(
        context,
        title: lesson.title,
        builder: (_) => LessonDetailScreen(lessonId: lesson.id),
      ),
    );
  }
}

class _CourseKnowledgeTab extends StatelessWidget {
  const _CourseKnowledgeTab({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return DbStreamBuilder<List<Item>>(
      streamFactory: () => (scope.db.select(scope.db.items)
            ..where((i) => i.deletedAt.isNull() & i.courseId.equals(course.id)))
          .watch(),
      builder: (context, snap) {
        final items = snap.data ?? const <Item>[];
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.lightbulb_outline,
            title: l.noKnowledgeInCourse,
            message: l.noKnowledgeInCourseHint,
          );
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return ListTile(
              leading: Icon(iconForType('')),
              title: Text(
                item.title.isEmpty ? item.bodyMd : item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => openDetail(
                context,
                title: item.title,
                builder: (_) => ItemDetailScreen(itemId: item.id),
              ),
            );
          },
        );
      },
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.courseSource, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text((course.lastStop ?? '').isEmpty ? '—' : course.lastStop!),
        const SizedBox(height: 16),
        Text(
          l.lastStop,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}
