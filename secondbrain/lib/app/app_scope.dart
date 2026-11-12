import 'package:flutter/widgets.dart';

import '../data/database.dart';
import '../data/repositories/attachments_repository.dart';
import '../data/repositories/courses_repository.dart';
import '../data/repositories/item_types_repository.dart';
import '../data/repositories/items_repository.dart';
import '../data/repositories/local_paths_repository.dart';
import '../data/repositories/projects_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/tasks_repository.dart';
import '../data/search_service.dart';
import '../data/write_gate.dart';
import '../platform/desktop/capture_service.dart';
import '../platform/system_opener.dart';
import '../sync/connection.dart';
import 'app_deps.dart';

/// App-wide dependencies handed down through the widget tree.
/// (Kept intentionally simple — no state-management package yet.)
/// Backup/restore swaps the whole [AppDeps] bundle; [updateShouldNotify]
/// fires when the database instance changes so dependents reload
/// automatically after a restore.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.deps, required super.child});

  final AppDeps deps;

  AppDatabase get db => deps.db;
  WriteGate get gate => deps.gate;
  ItemsRepository get items => deps.items;
  TagsRepository get tags => deps.tags;
  LinksRepository get links => deps.links;
  AttachmentsRepository get attachments => deps.attachments;
  SearchService get search => deps.search;
  ProjectsRepository get projects => deps.projects;
  TasksRepository get tasks => deps.tasks;
  CoursesRepository get courses => deps.courses;
  SettingsRepository get settings => deps.settings;
  ItemTypesRepository get itemTypes => deps.itemTypes;
  LocalPathsRepository get localPaths => deps.localPaths;

  /// Opens folders and links with the system handler (desktop only).
  SystemOpener get opener => deps.opener ?? const UnsupportedSystemOpener();

  /// Pairing / transport layer (local-only until the sync server exists).
  ConnectionService get connection =>
      deps.connection ?? LocalOnlyConnectionService();

  /// Desktop quick-capture service (null when the platform has no backend).
  DesktopCaptureService? get capture => deps.capture;

  static AppScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found above ${context.widget}');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.deps.db != deps.db;
}
