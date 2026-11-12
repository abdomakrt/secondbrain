import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../data/database.dart';
import '../../domain/progress.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/progress_bar.dart';
import '../shell/app_shell.dart';
import 'course_detail_screen.dart';
import 'course_edit_screen.dart';

/// Courses screen (UI_SPEC §5, UI-11).
///
/// One card per course: name, source, short description, progress bar, the
/// number of finished lessons, the last lesson and the next one.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  String _filter = 'active';

  /// Opens the edit form of a course.
  Future<void> _edit(BuildContext context, Course course) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseEditScreen(courseId: course.id),
      ),
    );
  }

  /// Moves a course to the trash (soft delete — the lessons survive).
  Future<void> _delete(BuildContext context, Course course) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final confirmed = await confirmDialog(
      context,
      title: l.deleteCourse,
      message: l.deleteCourseConfirm,
      confirmLabel: l.deleteCourse,
      destructive: true,
    );
    if (!confirmed) return;
    await scope.courses.trash(course.id);
    if (!context.mounted) return;
    showToast(context, l.movedToTrash);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'active', label: Text(l.activeCourses)),
              ButtonSegment(value: 'all', label: Text(l.all)),
              ButtonSegment(value: 'completed', label: Text(l.completedCourses)),
            ],
            selected: {_filter},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Course>>(
            stream: scope.courses.watchList(
              status: _filter == 'all' ? null : _filter,
              includeArchived: _filter == 'all',
            ),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const LoadingView();
              }
              final courses = snap.data!;
              if (courses.isEmpty) {
                return EmptyState(
                  icon: Icons.school_outlined,
                  title: l.emptyCourses,
                  message: l.emptyCoursesHint,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 96),
                itemCount: courses.length,
                itemBuilder: (context, i) {
                  final course = courses[i];
                  return _CourseCard(
                    course: course,
                    onTap: () => openDetail(
                      context,
                      title: course.title,
                      builder: (_) => CourseDetailScreen(courseId: course.id),
                    ),
                    onEdit: () => _edit(context, course),
                    onDelete: () => _delete(context, course),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends StatefulWidget {
  const _CourseCard({
    required this.course,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final Course course;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  int _total = 0;
  int _done = 0;
  String? _lastLesson;
  String? _nextLesson;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant _CourseCard old) {
    super.didUpdateWidget(old);
    if (old.course.id != widget.course.id) _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final lessons = await scope.courses.lessonsOf(widget.course.id);
    if (!mounted) return;
    setState(() {
      _total = lessons.length;
      _done = lessons.where((x) => x.status == 'done').length;
      final done = lessons.where((x) => x.status == 'done').toList();
      final next = lessons.where((x) => x.status != 'done').toList();
      _lastLesson = done.isEmpty ? null : done.last.title;
      _nextLesson = next.isEmpty ? null : next.first.title;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final progress = Progress(
      done: _done,
      total: _total,
      manual: 0,
      manualMode: false,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.school_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.course.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onEdit != null || widget.onDelete != null)
                    PopupMenuButton<String>(
                      tooltip: l.options,
                      onSelected: (value) {
                        if (value == 'edit') widget.onEdit?.call();
                        if (value == 'delete') widget.onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        if (widget.onEdit != null)
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text(l.editCourse),
                          ),
                        if (widget.onDelete != null)
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(l.deleteCourse),
                          ),
                      ],
                    ),
                ],
              ),
              if ((widget.course.sourceUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.link,
                        size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.course.sourceUrl!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (widget.course.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.course.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 10),
              ProgressBar(progress: progress),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    l.lessonsProgress(_done, _total),
                    style: theme.textTheme.labelSmall,
                  ),
                  if (_lastLesson != null)
                    Text(
                      '${l.lastLesson}: $_lastLesson',
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (_nextLesson != null)
                    Text(
                      '${l.nextLesson}: $_nextLesson',
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
