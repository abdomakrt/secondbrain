import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/app/app.dart';
import 'package:secondbrain/app/app_deps.dart';
import 'package:secondbrain/app/app_scope.dart';
import 'package:secondbrain/data/database.dart';
import 'package:secondbrain/l10n/app_localizations.dart';
import 'package:secondbrain/data/repositories/attachments_repository.dart';
import 'package:secondbrain/data/repositories/courses_repository.dart';
import 'package:secondbrain/data/repositories/item_types_repository.dart';
import 'package:secondbrain/data/repositories/local_paths_repository.dart';
import 'package:secondbrain/data/repositories/items_repository.dart';
import 'package:secondbrain/data/repositories/projects_repository.dart';
import 'package:secondbrain/data/repositories/settings_repository.dart';
import 'package:secondbrain/data/repositories/tasks_repository.dart';
import 'package:secondbrain/data/search_service.dart';
import 'package:secondbrain/data/write_gate.dart';
import 'package:secondbrain/core/hlc.dart';

/// Shared harness: in-memory database + repositories + RTL Arabic app.
class Harness {
  Harness._(this.db, this.gate, this.tags, this.items, this.links,
      this.attachments, this.search, this.projects, this.tasks, this.courses,
      this.settings, this.itemTypes, this.localPaths, this.tmpDir);

  static Future<Harness> create({int Function()? nowMs}) async {
    final tmp = Directory.systemTemp.createTempSync('sb_ui');
    final db = AppDatabase.inMemory();
    final gate = WriteGate(
      db: db,
      clock: nowMs == null
          ? await db.bootClock()
          : HlcClock(deviceId: await db.deviceId(), nowMs: nowMs),
    );
    final tags = TagsRepository(db: db, gate: gate);
    final items = ItemsRepository(db: db, gate: gate, tags: tags);
    final links = LinksRepository(db: db, gate: gate);
    final attachments = AttachmentsRepository(
      db: db,
      gate: gate,
      blobsDir: Directory('${tmp.path}/blobs'),
    );
    final search = SearchService(db);
    final projects = ProjectsRepository(db: db, gate: gate);
    final tasks = TasksRepository(db: db, gate: gate);
    final courses = CoursesRepository(db: db, gate: gate);
    final settings = SettingsRepository(db: db, gate: gate);
    final itemTypes = ItemTypesRepository(db: db);
    final localPaths = LocalPathsRepository(db: db, gate: gate);
    return Harness._(db, gate, tags, items, links, attachments, search,
        projects, tasks, courses, settings, itemTypes, localPaths, tmp);
  }

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
  final LocalPathsRepository localPaths;
  final Directory tmpDir;

  late String noteTypeId;

  Future<void> seedTypes() async {
    final t = await (db.select(db.itemTypes)
          ..where((x) => x.name.equals('ملاحظة')))
        .getSingle();
    noteTypeId = t.id;
  }

  /// Builds the app exactly like the real one (same AppDeps bundle).
  AppDeps deps() => AppDeps(
        supportDir: tmpDir,
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
        localPaths: localPaths,
      );

  Widget app() => SecondBrainApp(deps: deps());

  /// Wraps a single screen in the app environment (scope + RTL + l10n).
  Widget wrap(Widget child) => MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, built) => AppScope(
          deps: deps(),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: built!,
          ),
        ),
        home: child,
      );

  /// Marks the first-run setup as done so the app opens on the shell.
  Future<void> completeSetup() async {
    await settings.setBool(SettingsRepository.keySetupDone, true);
  }

  void dispose() {
    db.close();
    tmpDir.deleteSync(recursive: true);
  }
}
