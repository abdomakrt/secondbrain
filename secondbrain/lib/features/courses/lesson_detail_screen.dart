import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../common/widgets/content_width.dart';
import '../../data/database.dart';
import '../common/labels.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/db_stream_builder.dart';
import '../knowledge/item_detail_screen.dart';
import '../knowledge/item_edit_screen.dart';
import '../shell/app_shell.dart';
import '../tasks/task_detail_screen.dart';

/// Lesson details (UI_SPEC §5, UI-12).
///
/// Saving what was learned is a first-class part of the lesson experience:
/// the note can be written without leaving the lesson screen.
class LessonDetailView extends StatefulWidget {
  const LessonDetailView({super.key, required this.lessonId});

  final String lessonId;

  @override
  State<LessonDetailView> createState() => _LessonDetailViewState();
}

class _LessonDetailViewState extends State<LessonDetailView> {
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<Lesson?>(
      stream: (scope.db.select(scope.db.lessons)
            ..where((x) => x.id.equals(widget.lessonId)))
          .watchSingleOrNull(),
      builder: (context, snap) {
        final lesson = snap.data;
        if (lesson == null) {
          return const LoadingView();
        }
        return _LessonBody(lesson: lesson);
      },
    );
  }
}

/// Full-screen route wrapper around [LessonDetailView].
class LessonDetailScreen extends StatelessWidget {
  const LessonDetailScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.lessonDetails)),
      body: ContentWidth(
        maxWidth: ContentWidths.details,
        child: LessonDetailView(lessonId: lessonId),
      ),
    );
  }
}

class _LessonBody extends StatelessWidget {
  const _LessonBody({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                lesson.title,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Icon(
              lessonStatusIcon(lesson.status),
              color: lesson.status == 'done'
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          lessonStatusLabel(context, lesson.status),
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () async {
                await scope.courses.setLessonDone(lesson, lesson.status != 'done');
                if (!context.mounted) return;
                showToast(context, l.saved);
              },
              icon: Icon(
                lesson.status == 'done'
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
              ),
              label: Text(
                lesson.status == 'done' ? l.markNotDone : l.markLessonDone,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _saveNote(context),
              icon: const Icon(Icons.note_add_outlined),
              label: Text(l.saveNoteFromLesson),
            ),
            OutlinedButton.icon(
              onPressed: () => _createTask(context),
              icon: const Icon(Icons.add_task),
              label: Text(l.createTaskFromLesson),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _LinkedItems(
          lessonId: lesson.id,
          typeName: 'ملخص',
          title: l.whatILearned,
          emptyText: l.noSummaryYet,
        ),
        const SizedBox(height: 16),
        _LinkedItems(
          lessonId: lesson.id,
          title: l.notesAndImportantInfo,
          emptyText: l.noNotesYet,
          excludeTypes: const ['ملخص', 'سؤال'],
        ),
        const SizedBox(height: 16),
        _LinkedItems(
          lessonId: lesson.id,
          typeName: 'سؤال',
          title: l.questionsToReview,
          emptyText: l.noQuestionsYet,
          showReviewState: true,
        ),
      ],
    );
  }

  Future<void> _saveNote(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ItemEditScreen(
          initialTypeName: 'ملاحظة',
          initialCourseId: lesson.courseId,
          initialLessonId: lesson.id,
        ),
      ),
    );
  }

  Future<void> _createTask(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final task = await scope.tasks.create(
      title: lesson.title,
      lessonId: lesson.id,
    );
    if (!context.mounted) return;
    showToast(context, l.taskCreated);
    await openDetail(
      context,
      title: task.title,
      builder: (_) => TaskDetailScreen(taskId: task.id),
    );
  }
}

/// Knowledge items linked to the lesson, grouped by type.
class _LinkedItems extends StatelessWidget {
  const _LinkedItems({
    required this.lessonId,
    required this.title,
    required this.emptyText,
    this.typeName,
    this.excludeTypes = const [],
    this.showReviewState = false,
  });

  final String lessonId;
  final String title;
  final String emptyText;
  final String? typeName;
  final List<String> excludeTypes;
  final bool showReviewState;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        DbStreamBuilder<List<ItemType>>(
          streamFactory: () => scope.itemTypes.watchBuiltin(),
          builder: (context, typeSnap) {
            final types = typeSnap.data ?? const <ItemType>[];
            final byName = {for (final t in types) t.name: t.id};
            final wantedId = typeName == null ? null : byName[typeName];
            return DbStreamBuilder<List<Item>>(
              streamFactory: () => (scope.db.select(scope.db.items)
                    ..where((i) =>
                        i.deletedAt.isNull() & i.lessonId.equals(lessonId)))
                  .watch(),
              builder: (context, snap) {
                var items = snap.data ?? const <Item>[];
                if (wantedId != null) {
                  items = items.where((i) => i.typeId == wantedId).toList();
                } else if (excludeTypes.isNotEmpty) {
                  final excluded = excludeTypes
                      .map((n) => byName[n])
                      .whereType<String>()
                      .toSet();
                  items = items
                      .where((i) => !excluded.contains(i.typeId))
                      .toList();
                }
                if (items.isEmpty) {
                  return Text(emptyText, style: theme.textTheme.bodySmall);
                }
                return Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.title.isEmpty ? item.bodyMd : item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: showReviewState
                            ? Text(
                                item.reviewedAt == null
                                    ? l.needsReview
                                    : l.reviewed,
                                style: theme.textTheme.labelSmall,
                              )
                            : null,
                        trailing: showReviewState
                            ? IconButton(
                                tooltip: l.markReviewed,
                                icon: Icon(
                                  item.reviewedAt == null
                                      ? Icons.radio_button_unchecked
                                      : Icons.check_circle,
                                ),
                                onPressed: () => scope.items.update(
                                  item,
                                  reviewedAt: DateTime.now()
                                      .millisecondsSinceEpoch,
                                ),
                              )
                            : null,
                        onTap: () => openDetail(
                          context,
                          title: item.title,
                          builder: (_) => ItemDetailScreen(itemId: item.id),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
