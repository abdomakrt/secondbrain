import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../core/hlc.dart';
import '../core/ids.dart';
import 'tables.dart';
import 'write_gate.dart';

part 'database.g.dart';

/// The SQLite database. One per device; the sync server (Phase 7) and the UI
/// both read through this class, and all writes go through [WriteGate].
@DriftDatabase(tables: [
  Projects,
  Milestones,
  Tasks,
  Courses,
  CourseUnits,
  Lessons,
  ItemTypes,
  Items,
  Tags,
  ItemTags,
  Links,
  Attachments,
  Settings,
  Oplog,
  SyncState,
  Devices,
  ItemVersions,
  LocalPaths,
  ImportMap,
  ImportBatches,
  CaptureDrafts,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  factory AppDatabase.inMemory() =>
      AppDatabase(NativeDatabase.memory(logStatements: false));

  factory AppDatabase.atFile(File file) =>
      AppDatabase(NativeDatabase.createInBackground(file, logStatements: false));

  @override
  int get schemaVersion => 1;

  static const _createItemsFts =
      "CREATE VIRTUAL TABLE IF NOT EXISTS items_fts USING fts5("
      "item_id UNINDEXED, title, body, comment, tags, stems, "
      "tokenize = 'unicode61')";

  /// Partial indexes from the spec DDL (§5.4) — annotation syntax can't
  /// express WHERE filters, so these run in the migration.
  static const _extraStatements = [
    _createItemsFts,
    'CREATE INDEX IF NOT EXISTS idx_items_project '
        'ON items(project_id) WHERE deleted_at IS NULL',
    'CREATE INDEX IF NOT EXISTS idx_items_updated '
        'ON items(updated_at DESC) WHERE deleted_at IS NULL',
    'CREATE INDEX IF NOT EXISTS idx_items_inbox '
        'ON items(is_inbox) WHERE deleted_at IS NULL AND is_inbox = 1',
    'CREATE INDEX IF NOT EXISTS idx_oplog_record ON oplog(entity, record_id)',
  ];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          for (final stmt in _extraStatements) {
            await customStatement(stmt);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA journal_mode = WAL');
          await _seedBuiltinItemTypes();
        },
      );

  /// Built-in knowledge item types (spec §5.2, item_types).
  static const _builtinTypes = [
    'ملاحظة', 'معلومة', 'رابط', 'أداة', 'تجربة', 'قرار', 'فكرة',
    'أمر تقني', 'ملخص محادثة', 'ملخص', 'بحث', 'سؤال',
  ];

  Future<void> _seedBuiltinItemTypes() async {
    if ((await select(itemTypes).get()).isNotEmpty) return;
    final gate = WriteGate(db: this, clock: HlcClock(deviceId: await deviceId()));
    await gate.write((tx) async {
      for (final name in _builtinTypes) {
        final id = newId();
        final s = await tx.stamp('item_types', id);
        await tx.db.into(tx.db.itemTypes).insert(
              ItemTypesCompanion.insert(
                id: id,
                name: name,
                createdAt: s.updatedAtMs,
                updatedAt: s.updatedAtMs,
                hlc: s.hlc,
                isBuiltin: const Value(true),
              ),
            );
      }
    });
  }

  String? _deviceId;

  /// This device's id — created once and kept in `settings` (local row).
  Future<String> deviceId() async {
    final cached = _deviceId;
    if (cached != null) return cached;
    final row = await (select(settings)
          ..where((s) => s.key.equals('device_id')))
        .getSingleOrNull();
    final id = row?.value ?? newId();
    if (row == null) {
      await into(settings)
          .insertOnConflictUpdate(SettingsCompanion.insert(key: 'device_id', value: id));
    }
    return _deviceId = id;
  }

  /// A clock bound to this device, for [WriteGate].
  Future<HlcClock> bootClock() async => HlcClock(deviceId: await deviceId());
}
