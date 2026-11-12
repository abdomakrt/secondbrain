import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../courses/course_edit_screen.dart';
import '../../knowledge/daily_note.dart';
import '../../knowledge/item_edit_screen.dart';
import '../../projects/project_edit_screen.dart';
import '../../tasks/task_edit_screen.dart';

/// Quick add menu (UI_SPEC §7: `QuickAddMenu`).
///
/// One button creates a task, a project, a note, an idea, a link or a course.
void showQuickAddMenu(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  final entries = <({String label, IconData icon, Widget screen})>[
    (
      label: l.newTask,
      icon: Icons.checklist_rounded,
      screen: const TaskEditScreen(),
    ),
    (
      label: l.newProject,
      icon: Icons.folder_outlined,
      screen: const ProjectEditScreen(),
    ),
    (
      label: l.todayNote,
      icon: Icons.note_add_outlined,
      screen: ItemEditScreen(
        initialTypeName: 'ملاحظة',
        initialTags: const [DailyNote.tag],
      ),
    ),
    (
      label: l.newNote,
      icon: Icons.sticky_note_2_outlined,
      screen: const ItemEditScreen(initialTypeName: 'ملاحظة'),
    ),
    (
      label: l.newIdea,
      icon: Icons.emoji_objects_outlined,
      screen: const ItemEditScreen(initialTypeName: 'فكرة'),
    ),
    (
      label: l.newLink,
      icon: Icons.link,
      screen: const ItemEditScreen(initialTypeName: 'رابط'),
    ),
    (
      label: l.newCourse,
      icon: Icons.school_outlined,
      screen: const CourseEditScreen(),
    ),
  ];

  final width = MediaQuery.sizeOf(context).width;
  if (width < 600) {
    // Android: a bottom sheet with large touch targets.
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in entries)
              ListTile(
                leading: Icon(e.icon),
                title: Text(e.label),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => e.screen),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    return;
  }

  final overlay = Overlay.of(context);
  final box = context.findRenderObject() as RenderBox?;
  final position = box == null
      ? Offset.zero
      : box.localToGlobal(Offset.zero, ancestor: overlay.context.findRenderObject());

  showMenu<void>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + (box?.size.width ?? 0),
      position.dy,
    ),
    items: [
      for (final e in entries)
        PopupMenuItem<void>(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => e.screen),
          ),
          child: Row(
            children: [
              Icon(e.icon),
              const SizedBox(width: 10),
              Text(e.label),
            ],
          ),
        ),
    ],
  );
}
