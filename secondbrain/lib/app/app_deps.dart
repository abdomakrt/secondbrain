import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';
import '../data/repositories/attachments_repository.dart';
import '../data/repositories/courses_repository.dart';
import '../data/repositories/item_types_repository.dart';
import '../data/repositories/items_repository.dart';
import '../data/repositories/projects_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/tasks_repository.dart';
import '../data/search_service.dart';
import '../data/write_gate.dart';
import '../platform/desktop/capture_service.dart';
import '../platform/desktop/x11_capture.dart';
import '../sync/connection.dart';

/// Requested swap of the live [AppDeps] after a successful restore.
/// The root widget listens, swaps its state, and the whole app rebuilds
/// on the new database connection (kept simple on purpose — no
/// state-management package yet).
final ValueNotifier<AppDeps?> appDepsSwapRequest = ValueNotifier(null);

/// All live dependencies rooted at one database connection.
/// Backup/restore swaps this whole bundle (new connection, repos, search).
class AppDeps {
  AppDeps({
    required this.supportDir,
    required this.db,
    required this.gate,
    required this.tags,
    required this.items,
    required this.links,
    required this.attachments,
    required this.search,
    required this.projects,
    required this.tasks,
    required this.courses,
    required this.settings,
    required this.itemTypes,
    this.connection,
    this.capture,
  });

  /// The directory holding the db file, blobs, backups and safety copies.
  final Directory supportDir;
  final AppDatabase db;
  final WriteGate gate;
  final TagsRepository tags;
  final ItemsRepository items;
  final LinksRepository links;
  final AttachmentsRepository attachments;
  final SearchService search;
  final ProjectsRepository projects;
  final TasksRepository tasks;
  final CoursesRepository courses;
  final SettingsRepository settings;
  final ItemTypesRepository itemTypes;

  /// Pairing / transport layer. Local-only until the sync server exists.
  final ConnectionService? connection;

  /// Desktop quick-capture service (hot key + selection/clipboard reading).
  /// Null on platforms without a desktop capture backend.
  final DesktopCaptureService? capture;

  /// Opens (or re-opens) the app's local state at [supportDir].
  static Future<AppDeps> open(Directory supportDir) async {
    final db = AppDatabase.atFile(File('${supportDir.path}/secondbrain.sqlite'));
    final gate = WriteGate(db: db, clock: await db.bootClock());
    final tags = TagsRepository(db: db, gate: gate);
    final items = ItemsRepository(db: db, gate: gate, tags: tags);
    final links = LinksRepository(db: db, gate: gate);
    final attachments = AttachmentsRepository(
      db: db,
      gate: gate,
      blobsDir: Directory('${supportDir.path}/blobs'),
    );
    final search = SearchService(db);
    final projects = ProjectsRepository(db: db, gate: gate);
    final tasks = TasksRepository(db: db, gate: gate);
    final courses = CoursesRepository(db: db, gate: gate);
    final settings = SettingsRepository(db: db, gate: gate);
    final itemTypes = ItemTypesRepository(db: db);

    // Desktop quick capture (Linux/X11): a global hot key that reads the
    // selection / clipboard. Started with the shortcut saved in the settings.
    DesktopCaptureService? capture;
    if (Platform.isLinux) {
      capture = DesktopCaptureService(platform: X11CapturePlatform());
    }

    final deps = AppDeps(
      supportDir: supportDir,
      db: db,
      gate: gate,
      tags: tags,
      items: items,
      links: links,
      attachments: attachments,
      search: search,
      projects: projects,
      tasks: tasks,
      courses: courses,
      settings: settings,
      itemTypes: itemTypes,
      connection: LocalOnlyConnectionService(),
      capture: capture,
    );

    if (capture != null) {
      final shortcut = await settings
              .get(SettingsRepository.keyCaptureShortcut) ??
          defaultCaptureShortcut;
      await capture.start(shortcut);
    }
    return deps;
  }

  /// The shortcut proposed by the spec (§9.5).
  static const defaultCaptureShortcut = 'Ctrl + Alt + Shift + C';

  Future<void> close() => db.close();

  /// Default support dir (real device). Tests inject their own directory.
  static Future<Directory> defaultSupportDir() async =>
      getApplicationSupportDirectory();
}
