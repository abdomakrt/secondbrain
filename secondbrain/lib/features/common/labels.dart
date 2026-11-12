/// Arabic labels for the stored status values of projects, tasks and
/// lessons. Keeping them in one place guarantees the same wording on
/// Android and desktop (UI_SPEC §2.6).
library;

import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../data/database.dart';

/// The title shown for an item: its own title, else its body, else a
/// placeholder. Used by every card and list row that shows an item.
String itemDisplayTitle(BuildContext context, Item item) {
  final l = AppLocalizations.of(context)!;
  final title = item.title.trim();
  if (title.isNotEmpty) return title;
  final body = item.bodyMd.trim();
  return body.isEmpty ? l.untitledItem : body;
}

String projectStatusLabel(BuildContext context, String status) {
  final l = AppLocalizations.of(context)!;
  return switch (status) {
    'planned' => l.statusPlanned,
    'active' => l.statusActive,
    'paused' => l.statusPaused,
    'completed' => l.statusCompleted,
    'archived' => l.statusArchived,
    _ => status,
  };
}

IconData projectStatusIcon(String status) => switch (status) {
      'planned' => Icons.schedule_outlined,
      'active' => Icons.play_circle_outline,
      'paused' => Icons.pause_circle_outline,
      'completed' => Icons.check_circle_outline,
      'archived' => Icons.inventory_2_outlined,
      _ => Icons.circle_outlined,
    };

String taskStatusLabel(BuildContext context, String status) {
  final l = AppLocalizations.of(context)!;
  return switch (status) {
    'todo' => l.taskStatusTodo,
    'doing' => l.taskStatusDoing,
    'done' => l.taskStatusDone,
    'canceled' => l.taskStatusCanceled,
    _ => status,
  };
}

String lessonStatusLabel(BuildContext context, String status) {
  final l = AppLocalizations.of(context)!;
  return switch (status) {
    'todo' => l.lessonStatusTodo,
    'in_progress' => l.lessonStatusInProgress,
    'done' => l.lessonStatusDone,
    _ => status,
  };
}

IconData lessonStatusIcon(String status) => switch (status) {
      'todo' => Icons.radio_button_unchecked,
      'in_progress' => Icons.timelapse,
      'done' => Icons.check_circle,
      _ => Icons.circle_outlined,
    };
